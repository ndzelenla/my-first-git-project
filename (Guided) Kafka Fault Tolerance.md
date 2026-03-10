(Guided) Kafka Fault Tolerance
Author: Sammy Ndzelen
Date: 10.03.2026

Part 1: Cluster Setup
Task A: Deploy a 3-Broker Cluster

yaml
version: '3'
services:
  zookeeper:
    image: confluentinc/cp-zookeeper:latest
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
      ZOOKEEPER_TICK_TIME: 2000
    ports:
      - "2181:2181"

  kafka-1:
    image: confluentinc/cp-kafka:latest
    depends_on:
      - zookeeper
    ports:
      - "9092:9092"
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9092
      KAFKA_DEFAULT_REPLICATION_FACTOR: 3
      KAFKA_MIN_INSYNC_REPLICAS: 2
      KAFKA_NUM_PARTITIONS: 6
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 3

  kafka-2:
    image: confluentinc/cp-kafka:latest
    depends_on:
      - zookeeper
    ports:
      - "9093:9093"
    environment:
      KAFKA_BROKER_ID: 2
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9093
      KAFKA_DEFAULT_REPLICATION_FACTOR: 3
      KAFKA_MIN_INSYNC_REPLICAS: 2
      KAFKA_NUM_PARTITIONS: 6
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 3

  kafka-3:
    image: confluentinc/cp-kafka:latest
    depends_on:
      - zookeeper
    ports:
      - "9094:9094"
    environment:
      KAFKA_BROKER_ID: 3
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9094
      KAFKA_DEFAULT_REPLICATION_FACTOR: 3
      KAFKA_MIN_INSYNC_REPLICAS: 2
      KAFKA_NUM_PARTITIONS: 6
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 3
Explanation:

3 brokers with IDs 1, 2, 3 for redundancy

KAFKA_DEFAULT_REPLICATION_FACTOR: 3 - Every topic will have 3 replicas by default

KAFKA_MIN_INSYNC_REPLICAS: 2 - Producer acks=all requires at least 2 replicas in sync

KAFKA_NUM_PARTITIONS: 6 - Default partitions per topic for parallelism

Different ports (9092, 9093, 9094) to run on same machine

Task B: Create a Fault-Tolerant Topic
Explanation:

bash
# Creates a topic with explicit fault-tolerance settings
kafka-topics.sh --create \
  --bootstrap-server localhost:9092 \  # Connect to first broker
  --topic ft-streampulse-events \       # Topic name
  --partitions 6 \                       # 6 partitions for parallelism
  --replication-factor 3 \               # 3 copies of each partition
  --config min.insync.replicas=2         # Require 2 in-sync replicas for writes
Topic Layout Documentation (fill in after running):

Partition | Leader | Replicas | ISR
0         | 1      | 1,2,3    | 1,2,3
1         | 2      | 2,3,1    | 2,3,1
2         | 3      | 3,1,2    | 3,1,2
3         | 1      | 1,2,3    | 1,2,3
4         | 2      | 2,3,1    | 2,3,1
5         | 3      | 3,1,2    | 3,1,2


Part 2: Instrumented Producer & Consumer
Task: Instrumented Producer Explanation
Key Fault-Tolerance Features:

Multiple bootstrap servers: localhost:9092,9093,9094 - if one broker dies, producer automatically switches

acks=all: Wait for all in-sync replicas to acknowledge

enable.idempotence=true: Prevents duplicate messages during retries

retries=10: Automatically retry failed sends

Callback mechanism: Tracks delivery success/failure per message

Sequence numbers: Each event gets a unique sequence to detect gaps/duplicates

The producer:

Sends events at specified rate (10/sec)

Tracks produced vs delivered vs failed

Records failed sequence numbers for verification

Uses partition key seq % 6 for even distribution

Task: Instrumented Consumer Explanation
Key Verification Features:

Tracks unique sequences: Set of received sequence numbers

Detects duplicates: Counts if sequence already seen

Gap detection: Compares received set with expected range

Manual commit: Commits every 100 messages for control

Multiple bootstrap servers: Continues if one broker Fails




The consumer:

Reads all messages from beginning

Builds set of unique sequence numbers

Reports duplicates, gaps, and errors

Final report shows if any data was lost



Part 3: Failure Simulation Scenarios

Scenario 1: Single Follower Crash
bash
docker stop kafka-3  # Stop a non-leader broker
What happens:

Producer continues working (min.insync.replicas=2 still satisfied with remaining 2 brokers)

ISR shrinks to 2 brokers

When kafka-3 restarts, it catches up from the leader



Scenario 2: Leader Crash
bash
# First find which broker is leader for partition 0
docker exec kafka-1 kafka-topics --describe \
  --bootstrap-server localhost:9092 \
  --topic ft-streampulse-events | head -3

# Then stop that broker
docker stop kafka-<leader-id>
What happens:

Controller detects leader failure

One of the ISR followers becomes new leader

Brief pause (few seconds) during election

Producer may get retriable errors during election

Consumer rebalances to new leader



Scenario 3: Two Brokers Down (min.insync violation)
bash
docker stop kafka-2 kafka-3  # Only broker 1 remains
What happens:

Only 1 broker alive, but min.insync.replicas=2

Producer gets NotEnoughReplicasException - cannot write

Consumer can still read from broker 1

When kafka-2 restarts, ISR becomes 2, writes resume



Scenario 4: Consumer Hard Kill
bash
ps aux | grep ft_consumer
kill -9 <PID>
What happens:

Consumer dies without committing offsets

Group coordinator detects missing heartbeats after session.timeout.ms (10s)

Rebalance triggers, partitions reassigned

New consumer starts from last committed offset

May reprocess messages (duplicates) depending on processing vs commit timing



Scenario 5: Rolling Broker Restart
bash
docker restart kafka-1 && sleep 30
docker restart kafka-2 && sleep 30
docker restart kafka-3 && sleep 30
Expected results:

Zero downtime if done correctly

Each restart triggers leader re-election for partitions on that broker

Producers may see temporary retriable errors

No data loss if at least one broker always remains



## Scenario: Single Broker Down
Detection

Alert: Broker health check fails

Symptom: Broker metrics show 0 active connections, Kafka logs show broker leaving cluster

Impact

Writes: Continue normally (min.insync.replicas=2 satisfied)

Reads: Continue from remaining brokers

Data loss risk: None (data replicated to remaining brokers)

Response

Investigate broker logs for cause of failure

If hardware issue, spin up replacement broker

Restart broker or bring new one online

Verify broker rejoins cluster and catches up

Verification

Check ISR: All partitions should have 2 replicas in sync

Check consumer lag: No increasing lag on remaining brokers

Run gap analysis: Consumer report shows 0 missing events

Scenario: Leader Election Triggered
Detection

Brief spike in producer request latency

Controller logs show "LEADER_NOT_AVAILABLE" or election messages

Impact

Writes briefly paused (milliseconds to seconds)

Reads may temporarily fail and retry

Response

Automatic - no action needed

Monitor that election completes and new leader is elected

Verify all partitions have leaders

Scenario: min.insync.replicas Violation
Detection

Producer logs show NotEnoughReplicasException

Monitoring shows ISR count dropping below 2

Impact

All writes fail until sufficient replicas return

Reads continue from remaining brokers

Potential data loss if only one broker remains and fails

Response

Immediately check why brokers are down

Restart failed brokers

Once a second broker rejoins ISR, writes resume

Consider if emergency lowering of min.insync is needed (risky)

Scenario: Consumer Group Rebalancing
Detection

Consumer logs show "Revoking previously assigned partitions"

"Assigning new partitions" messages appear

Consumer lag may temporarily spike

Impact

Brief pause in message processing (seconds)

Possible duplicate processing if not idempotent

Response

Automatic - part of normal consumer group management

Ensure consumers have stable configuration

Monitor rebalance frequency - frequent rebalances indicate issues

Part 5: Verification Report
The verification_report.py script:

Combines producer and consumer metrics

Calculates delivery rates and gaps

Provides a verdict on data loss and duplicates

Color-coded PASS/FAIL status

Key metrics:

Producer delivery rate: Percentage of messages successfully delivered

Consumer gaps: Missing sequence numbers = data loss

Duplicates: Count of reprocessed messages

Overall verdict: PASS if zero gaps found



Bonus Challenge Insights
Automated failure injection script: Use random and subprocess to randomly stop/start brokers during test runs

Exactly-once semantics with transactions:

python
producer.init_transactions()
producer.begin_transaction()
# Send messages
producer.commit_transaction()


Monitoring dashboard: Use Prometheus + Grafana with Kafka JMX metrics to show:

ISR status per partition

Consumer lag

Broker health

Request rates

min.insync.replicas=1 comparison:

Higher availability (can write to single broker)

Higher data loss risk (if that broker fails before replication)

Not recommended for critical data