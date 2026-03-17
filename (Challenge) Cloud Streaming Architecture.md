(Challenge) Cloud Streaming Architecture
Author: Sammy Ndzelen
Date: 17.03.2026


## Iteration 1: Service Selection (25 minutes)
# Step 1: Evaluate Services per Layer

+-----------------+----------------------------------+--------------------------------+---------------+
| Option          | Pros                             | Cons                           | Score (1-5)   |
+-----------------+----------------------------------+--------------------------------+---------------+
| AWS MSK         | Fully managed Kafka, durable,    | No serverless option, some     | 5             |
|                 | integrates with AWS, high        | operational overhead           |               |
|                 | throughput                       |                                |               |
+-----------------+----------------------------------+--------------------------------+---------------+
| AWS Kinesis     | Serverless, auto-scaling         | 1MB/s shard limit, re-sharding | 3             |
|                 |                                  | complexity                     |               |
+-----------------+----------------------------------+--------------------------------+---------------+
| Confluent Cloud | Multi-cloud, advanced features   | Higher cost, data transfer     | 4             |
|                 |                                  | fees                           |               |
+-----------------+----------------------------------+--------------------------------+---------------+

Selected: AWS MSK

Justification: MSK provides native Kafka API compatibility (reusing existing knowledge), handles 110K/sec peak throughput easily with 6 brokers,
 integrates seamlessly with other AWS services, and is cost-effective at ~$0.48/hr per broker. 
Kinesis would require complex partitioning logic and re-sharding as traffic grows.


## Stream Processing Layer:

+-------------------------------+----------------------------------+--------------------------------+---------------+
| Option                        | Pros                             | Cons                           | Score (1-5)   |
+-------------------------------+----------------------------------+--------------------------------+---------------+
| Spark Structured Streaming    | Rich API, DataFrame abstraction, | Higher latency (micro-batch),  | 5             |
| (EMR)                         | exactly-once, large community    | more complex operations        |               |
+-------------------------------+----------------------------------+--------------------------------+---------------+
| Apache Flink (Kinesis Data    | True streaming, lower latency    | Limited to Kinesis sources,    | 3             |
| Analytics)                    |                                  | less flexible                  |               |
+-------------------------------+----------------------------------+--------------------------------+---------------+
| ksqlDB (Confluent)            | Stream-table semantics, SQL-like | Ties to Confluent ecosystem    | 4             |
+-------------------------------+----------------------------------+--------------------------------+---------------+


Selected: Spark Structured Streaming on EMR

Justification: Spark's micro-batch model provides 1-5 second latency (meeting SLA), has excellent Kafka integration, 
supports complex stateful operations like windowing and sessionization (needed for viral alerts), 
and the team has existing Spark expertise. EMR provides managed scaling and cost optimization with spot instances.



#  File Ingestion Layer:
+---------------------+----------------------------------+--------------------------------+---------------+
| Option              | Pros                             | Cons                           | Score (1-5)   |
+---------------------+----------------------------------+--------------------------------+---------------+
| Apache NiFi (EC2)   | Visual UI, data provenance,      | Operational overhead,          | 5             |
|                     | retry logic, exactly-once        | requires tuning                |               |
+---------------------+----------------------------------+--------------------------------+---------------+
| AWS Lambda + S3     | Serverless, simple               | Timeout limits (15 min), no    | 3             |
| events              |                                  | retry logic for large files    |               |
+---------------------+----------------------------------+--------------------------------+---------------+
| Kafka Connect       | Integrates with Kafka, managed   | Limited to Kafka ecosystem     | 4             |
| (MSK Connect)       |                                  |                                |               |
+---------------------+----------------------------------+--------------------------------+---------------+


Selected: Apache NiFi on EC2

Justification: NiFi handles the partner SFTP integration with built-in retry, backpressure, and data provenance - critical for compliance. 
The visual UI allows quick debugging when partners change file formats. SFTP sources are unpredictable, and NiFi's robust error handling prevents data loss.



# Data Lake Layer:
+---------------------+----------------------------------+--------------------------------+---------------+
| Option              | Pros                             | Cons                           | Score (1-5)   |
+---------------------+----------------------------------+--------------------------------+---------------+
| S3 + Delta Lake     | ACID transactions, time travel,  | Requires Databricks or OSS     | 5             |
|                     | schema evolution                 | Spark                          |               |
+---------------------+----------------------------------+--------------------------------+---------------+
| S3 + Apache Iceberg | Open standard, good Spark        | Newer, less mature ecosystem   | 4             |
|                     | integration                      |                                |               |
+---------------------+----------------------------------+--------------------------------+---------------+
| S3 + raw Parquet    | Simple, low cost                 | No ACID, no schema enforcement | 2             |
+---------------------+----------------------------------+--------------------------------+---------------+


Selected: S3 + Delta Lake

Justification: Delta Lake provides ACID transactions for the GDPR right-to-delete requirement (critical for compliance), 
time travel for debugging, and schema evolution as the data model changes. The performance optimization with Z-ordering benefits the batch reporting layer.




# Batch Transformation Layer:
+---------------------+----------------------------------+--------------------------------+---------------+
| Option              | Pros                             | Cons                           | Score (1-5)   |
+---------------------+----------------------------------+--------------------------------+---------------+
| dbt on Snowflake    | SQL-based, lineage, testing,     | Snowflake compute costs        | 5             |
|                     | documentation                    |                                |               |
+---------------------+----------------------------------+--------------------------------+---------------+
| dbt on Databricks   | Spark engine, handles large      | More complex setup             | 4             |
|                     | volumes                          |                                |               |
+---------------------+----------------------------------+--------------------------------+---------------+
| Spark batch on EMR  | Flexible, low cost               | More coding required, no       | 3             |
|                     |                                  | built-in lineage               |               |
+---------------------+----------------------------------+--------------------------------+---------------+


Selected: dbt on Snowflake

Justification: dbt provides built-in testing, documentation, and lineage - crucial for a 3-person data team supporting 8 developers. 
Business analysts can read dbt models. Snowflake's separation of storage and compute allows scaling down between the 4-hour batch runs, optimizing costs.


## Step 2: Architecture Diagram
┌──────────────────────────────── STREAMPULSE STREAMING ARCHITECTURE ─────────────────────────────────┐
│                                                                                                      │
│  DATA SOURCES                        INGESTION                    PROCESSING                SINKS   │
│                                                                                                      │
│  ┌──────────────┐                                                                                    │
│  │  Web App     │────┐                                                                               │
│  │  30K/sec     │    │    ┌─────────────────┐      ┌──────────────┐      ┌────────────────────┐    │
│  └──────────────┘    └───▶│                 │      │              │      │   S3 Data Lake      │    │
│                           │    MSK Cluster  │─────▶│   EMR Spark   │─────▶│   (Delta Lake)     │    │
│  ┌──────────────┐    ┌───▶│   6 x m5.2xlarge│      │   Streaming   │      │   eu-west-1/us-east │    │
│  │ Mobile App   │────┘    │                 │      │   Jobs        │      └────────────────────┘    │
│  │ 20K/sec      │         └─────────────────┘      └──────┬───────┘                 │                │
│  └──────────────┘                 │                       │                         │                │
│                                   │                       │                         ▼                │
│  ┌──────────────┐    ┌────────────┼───────────────────────┼────────────────────────────────────┐    │
│  │ Partner SFTP │───▶│  Topics    │                       │         Snowflake                    │    │
│  │ (hourly CSV) │    │ streaming.raw.web                  │         dbt Models                   │    │
│  └──────────────┘    │ streaming.raw.mobile               │         │                            │    │
│                      │ streaming.raw.partner              │         ▼                            │    │
│  ┌──────────────┐    │ streaming.raw.cdc                  │  ┌────────────────────┐              │    │
│  │ Database CDC │───▶│ streaming.enriched                 │  │  BI Tools          │              │    │
│  │ 5K/sec       │    │ streaming.aggregated               │  │  (Looker/Tableau)  │              │    │
│  └──────────────┘    │ streaming.alerts                    │  └────────────────────┘              │    │
│                      └──────────────────────────────────────┘                                      │
│                                           │                                                         │
│                                           │                    ┌─────────────────────┐             │
│                                           └───────────────────▶│  Real-time Dashboard │             │
│                                                                │   (<5 sec latency)   │             │
│                                                                └─────────────────────┘             │
│                                                                                                      │
│  ┌──────────────────────────────────────────────────────────────────────────────────────────────┐   │
│  │  GOVERNANCE & MONITORING                                                                     │   │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐            │   │
│  │  │ CloudWatch │  │  IAM       │  │  MSK        │  │  Glue      │  │  NiFi      │            │   │
│  │  │ Metrics    │  │  Policies  │  │  Monitoring │  │  Schema    │  │  Provenance│            │   │
│  │  └────────────┘  └────────────┘  └────────────┘  │  Registry  │  └────────────┘            │   │
│  │                                                   └────────────┘                              │   │
│  └──────────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                                      │
│  NETWORK: VPC with 3 AZs, Private subnets for MSK, EMR, NiFi │ Public subnets for load balancers  │
│                                                                                                      │
└──────────────────────────────────────────────────────────────────────────────────────────────────────┘


## Iteration 2: Topic and Schema Design
# Step 3: Kafka Topics Definition
+------------------------------------+------------+-----------+-----------+-------------+---------+----------------------+----------------------+
| Topic                              | Partitions | Key       | Retention | Replication | Format  | Producers            | Consumers            |
+------------------------------------+------------+-----------+-----------+-------------+---------+----------------------+----------------------+
| streaming.raw.web-interactions     | 12         | user_id   | 7 days    | 3           | Avro    | Web App              | Spark Streaming      |
+------------------------------------+------------+-----------+-----------+-------------+---------+----------------------+----------------------+
| streaming.raw.mobile-interactions  | 8          | user_id   | 7 days    | 3           | Avro    | Mobile App           | Spark Streaming      |
+------------------------------------+------------+-----------+-----------+-------------+---------+----------------------+----------------------+
| streaming.raw.partner-events       | 4          | partner_id| 14 days   | 3           | Avro    | NiFi                 | Spark Streaming      |
+------------------------------------+------------+-----------+-----------+-------------+---------+----------------------+----------------------+
| streaming.raw.database-cdc         | 10         | table_name| 14 days   | 3           | Avro    | Debezium             | Spark Streaming      |
+------------------------------------+------------+-----------+-----------+-------------+---------+----------------------+----------------------+
| streaming.enriched.user-events     | 24         | user_id   | 14 days   | 3           | Avro    | Spark Streaming      | dbt, Dashboard       |
+------------------------------------+------------+-----------+-----------+-------------+---------+----------------------+----------------------+
| streaming.aggregated.content-metrics| 6         | content_id| 30 days   | 3           | Avro    | Spark Streaming      | dbt, BI              |
+------------------------------------+------------+-----------+-----------+-------------+---------+----------------------+----------------------+
| streaming.alerts.viral-content     | 3          | content_id| 3 days    | 3           | Avro    | Spark Streaming      | Alert Service        |
+------------------------------------+------------+-----------+-----------+-------------+---------+----------------------+----------------------+
| streaming.dead-letter              | 6          | error_code| 30 days   | 3           | Avro    | All producers        | Debugging            |
+------------------------------------+------------+-----------+-----------+-------------+---------+----------------------+----------------------+


## Step 4: Define Event Schemas
Raw User Interaction Event:
{
  "event_id": "string (UUID)",
  "user_id": "string",
  "action": "string (play|skip|like|share|purchase|refund)",
  "content_id": "string",
  "device": "string (web|mobile|tv)",
  "country": "string (ISO 3166-1 alpha-2)",
  "timestamp": "string (ISO 8601)",
  "session_id": "string (UUID)",
  "app_version": "string",
  "os_version": "string",
  "network_type": "string (wifi|5g|lte|3g)",
  "duration_seconds": "integer (optional)",
  "amount": "float (optional)",
  "referrer": "string (optional)"
}

Enriched User Event:
{
  // Start with raw fields, then add:
  "region": "string (derived from country: eu|us|apac|other)",
  "user_segment": "string (derived from user profile: free|premium|trial|cancelled)",
  "content_genre": "string (derived from content metadata: action|comedy|drama|sports|news)",
  "content_duration_minutes": "integer",
  "subscription_tier": "string (basic|standard|premium)",
  "tenure_days": "integer (days since signup)",
  "device_category": "string (mobile|desktop|tv)",
  "hour_of_day": "integer (0-23)",
  "day_of_week": "string (mon|tue|wed|thu|fri|sat|sun)",
  "is_peak_time": "boolean",
  "geo_risk_score": "float (GDPR compliance flag)",
  "engagement_score": "float (derived from actions)"
}

Viral Alert Event:
{
  "alert_id": "string (UUID)",
  "content_id": "string",
  "content_title": "string",
  "metric": "string (play_count|like_count|share_count|engagement_rate)",
  "value": "number",
  "threshold": "number",
  "percentile": "number (e.g., 95th percentile)",
  "window_start": "string (ISO 8601)",
  "window_end": "string (ISO 8601)",
  "triggered_at": "string (ISO 8601)",
  "baseline_avg": "number",
  "baseline_stddev": "number",
  "z_score": "number",
  "region": "string",
  "severity": "string (info|warning|critical)"
}




### Step 5: Schema Registry Configuration
+---------------------+----------------------------------+--------------------------------------------------+
| Setting             | Value                            | Reason                                           |
+---------------------+----------------------------------+--------------------------------------------------+
| Schema format       | Avro                             | Strong typing, schema evolution, efficient       |
|                     |                                  | serialization, wide ecosystem support            |
+---------------------+----------------------------------+--------------------------------------------------+
| Compatibility mode  | Backward                         | Consumers can read data written with older       |
|                     |                                  | schemas; allows adding optional fields           |
+---------------------+----------------------------------+--------------------------------------------------+
| Schema validation   | Enabled                          | Reject invalid data at producer side, prevent    |
|                     |                                  | corruption                                       |
+---------------------+----------------------------------+--------------------------------------------------+
| Naming strategy     | TopicNameStrategy                | Clear mapping between topics and schemas,        |
|                     |                                  | easier governance                                |
+---------------------+----------------------------------+--------------------------------------------------+


## Iteration 3: Security, Compliance, and Failure Planning (15 minutes)
# Step 6: Security Design
+----------------------+------------------+------------------------------------------------------+
| Component            | Auth Method      | Details                                              |
+----------------------+------------------+------------------------------------------------------+
| Producers (web/mobile)| IAM Roles + TLS  | Assume IAM role via instance profile, connect to     |
|                      |                  | MSK with IAM auth on port 9098                       |
+----------------------+------------------+------------------------------------------------------+
| NiFi (file ingestion)| IAM User + TLS   | Dedicated IAM user with access keys, stored in       |
|                      |                  | Secrets Manager                                      |
+----------------------+------------------+------------------------------------------------------+
| Spark Streaming      | IAM Roles for    | EMR service role, instance profile with MSK IAM auth |
| (processing)         | EMR              |                                                      |
+----------------------+------------------+------------------------------------------------------+
| S3 Sink (archival)   | S3 bucket        | IAM roles with least privilege access to specific    |
|                      | policies         | buckets                                              |
+----------------------+------------------+------------------------------------------------------+
| dbt (transformation) | Snowflake key-   | RSA key-pair authentication, rotated quarterly       |
|                      | pair             |                                                      |
+----------------------+------------------+------------------------------------------------------+
| BI tools (reporting) | Snowflake OAuth  | SSO integration with corporate IdP                   |
+----------------------+------------------+------------------------------------------------------+

## Step 6: Authorization Matrix (Least Privilege)
+---------------------+--------------------------------------+----------------------------------+------------------------+
| Principal           | Allowed Topics                       | Operations                       | Denied                 |
+---------------------+--------------------------------------+----------------------------------+------------------------+
| svc-web-producer    | streaming.raw.web-interactions       | ProduceData, DescribeTopic       | All other topics,      |
|                     |                                      |                                  | consumer groups        |
+---------------------+--------------------------------------+----------------------------------+------------------------+
| svc-mobile-producer | streaming.raw.mobile-interactions    | ProduceData, DescribeTopic       | All other topics,      |
|                     |                                      |                                  | consumer groups        |
+---------------------+--------------------------------------+----------------------------------+------------------------+
| svc-spark-processor | streaming.*, __consumer_offsets      | ReadData, ProduceData,           | Delete topics,         |
|                     |                                      | DescribeGroup, AlterGroup        | Alter configs          |
+---------------------+--------------------------------------+----------------------------------+------------------------+
| svc-nifi-ingester   | streaming.raw.partner-events         | ProduceData, DescribeTopic       | All other topics       |
+---------------------+--------------------------------------+----------------------------------+------------------------+
| svc-s3-archiver     | None (writes directly to S3)         | N/A                              | All Kafka operations   |
+---------------------+--------------------------------------+----------------------------------+------------------------+
| svc-dbt-snowflake   | None (reads from Snowflake)          | N/A                              | All Kafka operations   |
+---------------------+--------------------------------------+----------------------------------+------------------------+

## Step 7: GDPR Compliance Flow
User event arrives in Kafka (streaming.raw.*)
    │
    ▼
[Spark Streaming - Step 1: Enrichment]
    │
    ├── EU user (country in EU member states)
    │   ├── Kafka topic: streaming.enriched.user-events-eu
    │   ├── S3 bucket: streampulse-data-lake-eu-west-1 (region: eu-west-1)
    │   ├── Snowflake: EU_ACCOUNT.GDPR_SCHEMA (EU region)
    │   └── Data retention: 14 days (raw), 90 days (enriched)
    │
    └── Non-EU user
        ├── Kafka topic: streaming.enriched.user-events-global
        ├── S3 bucket: streampulse-data-lake-us-east-1 (region: us-east-1)
        ├── Snowflake: GLOBAL_ACCOUNT.PRODUCTION_SCHEMA
        └── Data retention: 7 days (raw), 30 days (enriched)


## Step 7: Right to Delete Implementation
+------+-------------------------------+-------------------------+-----------+
| Step | Action                        | Service                 | SLA       |
+------+-------------------------------+-------------------------+-----------+
| 1    | Receive deletion request      | Web App / Support Portal| < 1 hour  |
+------+-------------------------------+-------------------------+-----------+
| 2    | Identify all user data        | Spark Job + Snowflake   | < 4 hours |
|      |                               | Query                   |           |
+------+-------------------------------+-------------------------+-----------+
| 3    | Delete from data lake         | Delta Lake VACUUM       | < 8 hours |
|      |                               | command (S3)            |           |
+------+-------------------------------+-------------------------+-----------+
| 4    | Delete from warehouse         | Snowflake DELETE + PURGE| < 2 hours |
+------+-------------------------------+-------------------------+-----------+
| 5    | Confirm deletion              | Audit Log + Compliance  | < 24 hours|
|      |                               | Report                  |           |
+------+-------------------------------+-------------------------+-----------+

## Step 8: Failure Mode Analysis
+------------------+----------------------+-------------------------------------+----------------------------------+-----------+------------+
| Component        | Failure              | Detection                           | Recovery                         | RTO       | Data Loss? |
+------------------+----------------------+-------------------------------------+----------------------------------+-----------+------------+
| MSK broker       | Crash                | CloudWatch (ActiveControllerCount   | Auto-replace by MSK              | 15 min    | No (RF=3)  |
|                  |                      | !=1)                                |                                  |           |            |
+------------------+----------------------+-------------------------------------+----------------------------------+-----------+------------+
| Spark SS job     | OOM                  | CloudWatch ContainerInsights        | Restart with larger driver       | 5 min     | No         |
|                  |                      |                                     |                                  |           | (checkpoints)|
+------------------+----------------------+-------------------------------------+----------------------------------+-----------+------------+
| NiFi flow        | SFTP down            | NiFi Provenance Reporting           | Queue data, retry with backoff   | 30 min    | No (queue) |
+------------------+----------------------+-------------------------------------+----------------------------------+-----------+------------+
| S3 sink          | Throttling           | 503 SlowDown errors                 | Exponential backoff + retry      | 10 min    | No (retries)|
+------------------+----------------------+-------------------------------------+----------------------------------+-----------+------------+
| dbt job          | SQL error            | dbt test failures                   | Rollback to last successful run  | 2 hours   | No         |
+------------------+----------------------+-------------------------------------+----------------------------------+-----------+------------+
| Schema Registry  | Unavailable          | MSK Connect health check            | Fallback to local cache          | 5 min     | No (cached)|
+------------------+----------------------+-------------------------------------+----------------------------------+-----------+------------+
| Network          | VPC partition        | AZ health checks                    | MSK multi-AZ failover            | 2 min     | No         |
+------------------+----------------------+-------------------------------------+----------------------------------+-----------+------------+



## Iteration 4: Cost Estimate (10 minutes)
# Step 9: Detailed Cost Breakdown
+---------------------+--------------------------------------+----------------+--------+----------------+
| Service             | Configuration                        | Unit Price     | Qty    | Monthly Cost   |
+---------------------+--------------------------------------+----------------+--------+----------------+
| MSK                 | kafka.m5.2xlarge, 6 brokers          | $0.48/hr       | 6 × 730| $2,102         |
|                     |                                      |                | hrs    |                |
+---------------------+--------------------------------------+----------------+--------+----------------+
| MSK Storage         | gp3, 15 TB/broker                    | $0.10/GB-month | 90 TB  | $9,216         |
+---------------------+--------------------------------------+----------------+--------+----------------+
| EMR (Spark)         | m5.xlarge, 4 nodes (30% spot)        | $0.134/hr avg  | 4 × 730| $391           |
|                     |                                      |                | hrs    |                |
+---------------------+--------------------------------------+----------------+--------+----------------+
| NiFi (EC2)          | m5.large, 2 nodes (on-demand)        | $0.096/hr      | 2 × 730| $140           |
|                     |                                      |                | hrs    |                |
+---------------------+--------------------------------------+----------------+--------+----------------+
| S3                  | Standard, ~130 TB                    | $0.023/GB      | 130 TB | $2,990         |
+---------------------+--------------------------------------+----------------+--------+----------------+
| Snowflake           | Small warehouse (4hr/day)            | $2.50/credit   | 120    | $300           |
|                     |                                      |                | credits|                |
+---------------------+--------------------------------------+----------------+--------+----------------+
| CloudWatch          | Custom metrics + logs                | $0.30/metric   | 50     | $15            |
|                     |                                      |                | metrics|                |
+---------------------+--------------------------------------+----------------+--------+----------------+
| Data Transfer       | Cross-AZ, 20 TB                      | $0.02/GB       | 20 TB  | $400           |
+---------------------+--------------------------------------+----------------+--------+----------------+
| Schema Registry     | Included with MSK                    | $0             | 0      | $0             |
+---------------------+--------------------------------------+----------------+--------+----------------+
| **Total**           |                                      |                |        | **$15,554**    |
+---------------------+--------------------------------------+----------------+--------+----------------+


## Step 10: Cost Optimization Opportunities
+-----------------------------------+--------------------------+--------------------------------------------------+
| Optimization                      | Potential Savings        | Trade-off                                        |
+-----------------------------------+--------------------------+--------------------------------------------------+
| MSK Serverless instead of         | ~$4,000/month            | No guarantee of same throughput, cold starts     |
| provisioned                       |                          | possible                                         |
+-----------------------------------+--------------------------+--------------------------------------------------+
| Spot instances for Spark          | ~$200/month               | Task preemption risk, need checkpointing         |
+-----------------------------------+--------------------------+--------------------------------------------------+
| S3 Intelligent-Tiering            | ~$300/month               | Small overhead for monitoring access patterns    |
+-----------------------------------+--------------------------+--------------------------------------------------+
| Reduce retention from 7 to 3 days | ~$3,900/month             | Less historical data for analysis, compliance    |
|                                   |                          | risk                                             |
+-----------------------------------+--------------------------+--------------------------------------------------+
| Smaller Snowflake warehouse       | ~$150/month               | Slower batch processing (may miss 4-hour SLA)    |
+-----------------------------------+--------------------------+--------------------------------------------------+


## Executive Summary
StreamPulse's streaming architecture uses AWS MSK for ingestion, Spark Structured Streaming on EMR for
processing, and Delta Lake on S3 for archival to handle 110,000 events/second with <5 second end-to-end
latency. The architecture supports multi-region GDPR compliance through EU data routing, viral content
alerts within 30 seconds using sliding windows, and ACID-compliant right-to-delete via Delta Lake at an
estimated monthly cost of $15,000. Key design decisions include:

1. MSK over Kinesis - Native Kafka API compatibility with existing team knowledge, simpler partitioning,
   and consistent performance at peak loads.

2. Delta Lake for data lake - ACID transactions enabling GDPR compliance (right-to-delete), time travel
   for debugging, and 30% faster batch queries through Z-ordering.

3. dbt on Snowflake for batch - Built-in testing, documentation, and lineage enable a 3-person data team
   to support 8 application developers with self-service analytics.

The architecture meets all SLAs: 5-second dashboards, 15-minute archival, 30-second viral alerts, and
4-hour batch updates, while maintaining strict GDPR data segregation.