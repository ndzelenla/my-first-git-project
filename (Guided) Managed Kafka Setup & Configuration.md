Managed Kafka Setup & Configuration
Author: Sammy Ndzelen
Date: 17.03.2026

## Iteration 1: Cluster Sizing (20 minutes)
# Step 1: Calculate Broker Requirements

Ingress: 50 MB/s
Replication write: 50 MB/s × 3 (RF) = 150 MB/s total write
Consumer read: 50 MB/s × 15 consumer groups × ??? (fan-out factor)
  Note: Each consumer group reads independently

Per-broker throughput (kafka.m5.2xlarge):
├── Network: up to 10 Gbps (~1,250 MB/s)
├── Disk: gp3, 125 MB/s baseline + provisioned
├── Recommended max: ~60 MB/s write per broker
└── With headroom: use 40 MB/s per broker

Brokers for write: 150 MB/s / 40 MB/s = 3.75 → 4 brokers
Headroom (50%): 4 × 1.5 = 6 brokers
Multi-AZ: 6 brokers / 3 AZs = 2 per AZ ✓


+----------------------------------+-------------------------------------------------+---------------+
| Metric                           | Calculation                                     | Result        |
+----------------------------------+-------------------------------------------------+---------------+
| Total write throughput           | Ingress (50 MB/s) × RF (3) = 150 MB/s           | 150 MB/s      |
+----------------------------------+-------------------------------------------------+---------------+
| Brokers needed (raw)             | 150 MB/s ÷ 40 MB/s per broker = 3.75            | 4 brokers     |
+----------------------------------+-------------------------------------------------+---------------+
| With 50% headroom                | 4 × 1.5 = 6 brokers                             | 6 brokers     |
+----------------------------------+-------------------------------------------------+---------------+
| Per-AZ distribution              | 6 brokers ÷ 3 AZs = 2 per AZ                    | 2 per AZ      |
+----------------------------------+-------------------------------------------------+---------------+
| Final broker count               | 6 brokers across 3 AZs                          | 6 brokers     |
+----------------------------------+-------------------------------------------------+---------------+


## Storage calculation:
Daily ingested: 50 MB/s × 86,400 s = 4,320 GB/day
With replication: 4,320 × 3 = 12,960 GB/day
7-day retention: 12,960 × 7 = 90,720 GB = ~90 TB
Per broker: 90 TB / 6 = 15 TB each

EBS volume per broker: 16 TB gp3
  ├── Throughput: 250 MB/s (provisioned)
  ├── IOPS: 4,000 (provisioned)
  └── Cost: $0.08/GB/month = $1,280/broker


+----------------------------------+-------------------------------------------------+---------------+
| Metric                           | Calculation                                     | Result        |
+----------------------------------+-------------------------------------------------+---------------+
| Daily data (raw)                 | 50 MB/s × 86,400 seconds = 4,320,000 MB = 4,320 GB | 4,320 GB    |
+----------------------------------+-------------------------------------------------+---------------+
| Daily data (replicated)          | 4,320 GB × 3 (RF) = 12,960 GB                     | 12,960 GB     |
+----------------------------------+-------------------------------------------------+---------------+
| 7-day total                      | 12,960 GB × 7 = 90,720 GB = ~90.7 TB              | 90.7 TB       |
+----------------------------------+-------------------------------------------------+---------------+
| Per broker storage               | 90.7 TB ÷ 6 brokers = 15.12 TB per broker         | 15 TB         |
+----------------------------------+-------------------------------------------------+---------------+
| EBS per broker                   | 16 TB gp3 (provisioned 250 MB/s, 4000 IOPS)       | 16 TB         |
+----------------------------------+-------------------------------------------------+---------------+


## Step 2: Instance Type Selection
+---------------------+-------------------------------------------------------------------+
| Selection           | Value                                                             |
+---------------------+-------------------------------------------------------------------+
| Your choice         | kafka.m5.2xlarge                                                  |
+---------------------+-------------------------------------------------------------------+
| Justification       | - Required throughput: 40 MB/s write per broker (with headroom)  |
|                     | - Network: Up to 10 Gbps, sufficient for 40 MB/s                 |
|                     | - Memory: 32 GB for OS page cache, improves performance          |
|                     | - vCPUs: 8 cores handle replication and client requests          |
|                     | - Cost-effective: $0.48/hr vs $0.96 for 4xlarge                  |
|                     | - Matches EBS throughput (250 MB/s provisioned)                  |
+---------------------+-------------------------------------------------------------------+


## Iteration 2: Infrastructure as Code (20 minutes)
# Step 3: Write Terraform Configuration
# File: main.tf
# Complete Terraform configuration for MSK cluster

provider "aws" {
  region = "us-east-1"
}

# VPC and Subnets (reference existing or create)
data "aws_vpc" "main" {
  id = "vpc-xxxxxxxxxxxx"  # Your VPC ID
}

data "aws_subnets" "kafka" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }
  filter {
    name   = "tag:Type"
    values = ["private"]
  }
}

# Security Group for MSK
resource "aws_security_group" "msk" {
  name_prefix = "streampulse-msk-"
  vpc_id      = data.aws_vpc.main.id

  # Kafka brokers ports:
  # - 9092: plaintext
  # - 9094: TLS
  # - 9098: IAM
  ingress {
    description = "Kafka TLS"
    from_port   = 9094
    to_port     = 9094
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
  }

  ingress {
    description = "Kafka IAM"
    from_port   = 9098
    to_port     = 9098
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# MSK Cluster
resource "aws_msk_cluster" "streampulse" {
  cluster_name           = "streampulse-production"
  kafka_version          = "3.5.1"
  number_of_broker_nodes = 6  # Calculated count from Step 1

  broker_node_group_info {
    instance_type  = "kafka.m5.2xlarge"  # Chosen instance
    client_subnets = data.aws_subnets.kafka.ids
    storage_info {
      ebs_storage_info {
        volume_size = 16000  # GB per broker (16 TB)
        provisioned_throughput {
          enabled           = true
          volume_throughput = 250  # MB/s
        }
      }
    }
    security_groups = [aws_security_group.msk.id]
  }

  encryption_info {
    encryption_in_transit {
      client_broker = "TLS"
      in_cluster    = true
    }
    encryption_at_rest_kms_key_arn = aws_kms_key.msk.arn
  }

  # Using IAM authentication for simplicity and AWS integration
  client_authentication {
    sasl {
      iam   = true   # Enable IAM authentication
      scram = false  # Disable SCRAM authentication
    }
    tls {
      certificate_authority_arns = []
    }
  }

  configuration_info {
    arn      = aws_msk_configuration.streampulse.arn
    revision = aws_msk_configuration.streampulse.latest_revision
  }

  open_monitoring {
    prometheus {
      jmx_exporter {
        enabled_in_broker = true
      }
      node_exporter {
        enabled_in_broker = true
      }
    }
  }

  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = true
        log_group = aws_cloudwatch_log_group.msk.name
      }
    }
  }

  tags = {
    Environment = "production"
    Team        = "data-platform"
    Service     = "streampulse"
  }
}

# MSK Configuration
resource "aws_msk_configuration" "streampulse" {
  name              = "streampulse-config"
  kafka_versions    = ["3.5.1"]
  server_properties = <<PROPERTIES
auto.create.topics.enable=false
default.replication.factor=3
min.insync.replicas=2
num.partitions=6
log.retention.hours=168
log.retention.bytes=-1
message.max.bytes=1048576
compression.type=lz4
PROPERTIES
}

# KMS Key for encryption at rest
resource "aws_kms_key" "msk" {
  description = "KMS key for StreamPulse MSK encryption"
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "msk" {
  name              = "/aws/msk/streampulse-production"
  retention_in_days = 30
}

# Outputs
output "bootstrap_brokers_tls" {
  value = aws_msk_cluster.streampulse.bootstrap_brokers_tls
}

output "zookeeper_connect_string" {
  value = aws_msk_cluster.streampulse.zookeeper_connect_string
}


## Step 4: IAM Policies
# Write IAM policies for each service account:

# Producer policy (web app):
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "kafka-cluster:Connect",
        "kafka-cluster:ProduceData",
        "kafka-cluster:DescribeTopic"
      ],
      "Resource": [
        "arn:aws:kafka:us-east-1:123456789012:cluster/streampulse-production/*",
        "arn:aws:kafka:us-east-1:123456789012:topic/streampulse-production/*/streaming.raw.*"
      ]
    }
  ]
}


## Consumer policy (Spark Streaming):
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "kafka-cluster:Connect",
        "kafka-cluster:ReadData",
        "kafka-cluster:DescribeTopic",
        "kafka-cluster:AlterGroup",
        "kafka-cluster:DescribeGroup"
      ],
      "Resource": [
        "arn:aws:kafka:us-east-1:123456789012:cluster/streampulse-production/*",
        "arn:aws:kafka:us-east-1:123456789012:topic/streampulse-production/*/streaming.raw.*",
        "arn:aws:kafka:us-east-1:123456789012:topic/streampulse-production/*/streaming.enriched.*",
        "arn:aws:kafka:us-east-1:123456789012:group/streampulse-production/*/spark-streaming-*"
      ]
    }
  ]
}


## Step 5: Monitoring Dashboard Design

+---------------------+-------------------------+-----------------+---------------------+-------------------+
| Panel               | CloudWatch Metric       | Visualization   | Alert Threshold     | Action            |
+---------------------+-------------------------+-----------------+---------------------+-------------------+
| Cluster Health      | ActiveControllerCount   | Single stat     | != 1 → Critical     | Page on-call      |
| Offline Partitions  | OfflinePartitionsCount  | Single stat     | > 0 → Critical      | Page on-call      |
| Broker CPU          | CpuUser                 | Line chart      | > 70% → Warning     | Email + Slack     |
|                     |                         | (per broker)    | > 90% → Critical    | Page              |
| Broker Disk         | KafkaDataLogsDiskUsed   | Gauge           | > 80% → Warning     | Email + Slack     |
|                     |                         | (per broker)    | > 95% → Critical    | Page              |
| Ingress Rate        | BytesInPerSec           | Line chart      | < 20 MB/s → Warning | Email             |
|                     | (Sum)                   |                 | (sudden drop)       |                   |
| Consumer Lag        | SumOffsetLag            | Line chart      | > 100K → Warning    | Email + Slack     |
|                     | (per group)             |                 | > 500K → Critical   | Page              |
| Under-Replicated    | UnderReplicatedPartitions| Single stat     | > 0 (5 min) → Warning| Email            |
| Network In/Out      | NetworkRxDropped         | Line chart      | > 0 → Critical      | Page              |
+---------------------+-------------------------+-----------------+---------------------+-------------------+


## Step 6: Topic Governance Policy
# Write a topic governance document:
# StreamPulse Topic Governance Policy

## Topic Creation
- All topics MUST be created via Terraform pull requests
- No manual topic creation allowed in production
- All PRs require review from the data platform team
- Topic configuration must be approved before deployment

## Naming Convention
- Format: streaming.<layer>.<domain>-<entity>
- Layers: raw, enriched, aggregated, alerts, dead-letter
- Examples:
  - streaming.raw.web-interactions
  - streaming.enriched.user-events
  - streaming.alerts.viral-content
  - streaming.dead-letter.failed-events

## Partition Policy
- Minimum: 6 partitions
- Formula: max(target_throughput / 10MB_per_partition, consumer_count)
- Partitions can only be ADDED, never removed
- Re-evaluate partition count quarterly based on growth

## Retention Policy
| Layer       | Default Retention | Max Retention | Justification                  |
|-------------|------------------|---------------|--------------------------------|
| raw         | 7 days           | 30 days       | Source data, can be replayed   |
| enriched    | 14 days          | 90 days       | Processed data, debugging      |
| aggregated  | 30 days          | 365 days      | Business metrics, compliance   |
| alerts      | 3 days           | 7 days        | Operational, time-sensitive    |
| dead-letter | 30 days          | 90 days       | Error recovery, auditing       |

## Schema Policy
- All topics MUST have a registered Avro/Protobuf schema
- Schema Registry: AWS Glue Schema Registry
- Compatibility mode: BACKWARD
- Schema changes require PR review from data platform
- Breaking changes require new topic version

## Ownership
- Every topic must have a team owner in the topic metadata
- Owner is responsible for:
  - Retention period justification
  - Partition count adequacy
  - Access control reviews (quarterly)
  - Monitoring consumer lag
  - Capacity planning

## Cleanup Policy
- Orphaned topics (no consumers for 30 days) flagged for review
- Topics without owners deleted after 60 days
- Dead-letter topics reviewed weekly for replay


## Step 7: Disaster Recovery Plan
+---------------------+-----------------------------------------------------------+
| Item                | Configuration                                             |
+---------------------+-----------------------------------------------------------+
| Primary region      | us-east-1 (N. Virginia)                                   |
| DR region           | eu-west-1 (Ireland)                                       |
| Replication method  | MSK Replicator (active-passive)                           |
| Replicated topics   | streaming.raw.*, streaming.enriched.*, streaming.alerts.* |
| RPO target          | < 5 minutes                                               |
| RTO target          | < 30 minutes                                              |
| Failover trigger    | Manual after 10+ minutes of confirmed outage              |
| Failback procedure  | Reverse replication, then DNS switch back                 |
+---------------------+-----------------------------------------------------------+

## Failover Runbook

**Step 1: Detect primary failure**
  - Alert source: CloudWatch Alarm on ActiveControllerCount != 1
  - Verification: Check AWS Health Dashboard, SSH to brokers if possible

**Step 2: Decision to failover**
  - Who decides: Data Platform Lead + On-call Engineer
  - Criteria: 10+ minutes of downtime, unable to restore quickly

**Step 3: Switch DNS / connection strings**
  - Method: Update Route53 weighted records or ConfigMap in Kubernetes
  - Services affected: All Kafka producers and consumers

**Step 4: Verify DR cluster**
  - Check: Bootstrap brokers are reachable
  - Validate: Latest data present (lag < RPO)

**Step 5: Notify consumers**
  - Method: Slack #kafka-alerts, email distribution list
  - Consumer action: Restart with new bootstrap servers

**Step 6: Monitor DR performance**
  - Metrics: BytesInPerSec, ConsumerLag, UnderReplicatedPartitions
  - Duration: Until primary restored and failback complete


## What would change if throughput doubled in 6 months?
If throughput doubled to 100 MB/s ingress:

1. Broker count recalculation:
   - Total write: 100 MB/s × 3 = 300 MB/s
   - Brokers needed: 300 MB/s ÷ 40 MB/s = 7.5 → 8 brokers
   - With headroom: 8 × 1.5 = 12 brokers
   - Per AZ: 12 ÷ 3 = 4 brokers per AZ

2. Instance type might need upgrade:
   - 40 MB/s per broker becomes 300/12 = 25 MB/s per broker (okay)
   - But peak loads may require m5.4xlarge

3. Partition count increase:
   - More partitions to handle throughput
   - May need to pre-create more partitions

4. Cost impact:
   - 12 vs 6 brokers = 2× infrastructure cost
   - EBS storage: 180 TB total vs 90 TB


## How would you test the DR failover without impacting production?
DR testing strategy without production impact:

1. Parallel test environment:
   - Create isolated test topics with sample data
   - Run continuous test producers/consumers
   - Perform failover on test flow only

2. Chaos engineering approach:
   - Use AWS Fault Injection Simulator
   - Simulate AZ failure in non-production hours
   - Validate RTO/RPO metrics

3. Game day exercises:
   - Scheduled quarterly drills
   - Involve all on-call engineers
   - Document actual vs expected times

4. Canary testing:
   - Route 1% of traffic to DR during low periods
   - Verify functionality before full failover

5. Validation steps:
   - Check data integrity (checksums)
   - Measure actual RPO (data loss)
   - Time full failover sequence


## What is the single most important monitoring metric and why?
The single most important monitoring metric is:

**UnderReplicatedPartitions**

Why it's critical:
- Indicates brokers are falling behind in replication
- Early warning of impending data loss
- Often precedes broker failure
- Affects durability (RF not being maintained)
- Can cascade into complete cluster failure

Impact chain:
1. UnderReplicatedPartitions > 0
2. Broker performance degrades
3. More partitions fall behind
4. ISR shrinks
5. Min.insync.replicas not met
6. Producers fail
7. Data loss risk increases

Alert immediately when URP > 0 for more than 5 minutes.
