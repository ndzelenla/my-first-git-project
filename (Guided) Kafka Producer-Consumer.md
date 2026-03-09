(Guided) Kafka Producer-Consumer
Author: Sammy Ndzelen
Date: 09.03.2026

StreamPulse Kafka Implementation
Complete Guide with Code Solutions
Setup: Local Kafka Cluster
bash
# docker-compose.kafka.yml
version: '3.8'

services:
  zookeeper:
    image: confluentinc/cp-zookeeper:7.5.0
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
      ZOOKEEPER_TICK_TIME: 2000
    ports:
      - "2181:2181"
    healthcheck:
      test: echo stat | nc localhost 2181
      interval: 10s
      timeout: 5s
      retries: 5

  kafka:
    image: confluentinc/cp-kafka:7.5.0
    depends_on:
      zookeeper:
        condition: service_healthy
    ports:
      - "9092:9092"
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9092
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
      KAFKA_NUM_PARTITIONS: 6
      KAFKA_AUTO_CREATE_TOPICS_ENABLE: "true"
      KAFKA_DELETE_TOPIC_ENABLE: "true"
      KAFKA_LOG_RETENTION_HOURS: 168
      KAFKA_COMPRESSION_TYPE: "snappy"
    healthcheck:
      test: kafka-topics --bootstrap-server localhost:9092 --list
      interval: 10s
      timeout: 5s
      retries: 5
bash
# Start Kafka
docker compose -f docker-compose.kafka.yml up -d

# Verify Kafka is running
docker exec -it streampulse-kafka-1 kafka-topics --list --bootstrap-server localhost:9092


Part 1: Topic Setup
python
# create_topics.py
from confluent_kafka.admin import AdminClient, NewTopic
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

admin = AdminClient({'bootstrap.servers': 'localhost:9092'})

# Define topics with configurations
topics = [
    NewTopic(
        'streaming.user.interactions', 
        num_partitions=6,
        replication_factor=1,
        config={
            'retention.ms': str(30 * 24 * 60 * 60 * 1000),  # 30 days
            'cleanup.policy': 'delete',
            'compression.type': 'snappy'
        }
    ),
    NewTopic(
        'streaming.user.page-views', 
        num_partitions=3,
        replication_factor=1,
        config={
            'retention.ms': str(7 * 24 * 60 * 60 * 1000),  # 7 days
            'cleanup.policy': 'delete'
        }
    ),
    NewTopic(
        'payments.transaction.events', 
        num_partitions=3,
        replication_factor=1,
        config={
            'retention.ms': str(90 * 24 * 60 * 60 * 1000),  # 90 days
            'cleanup.policy': 'compact,delete',  # Keep latest by key
            'min.cleanable.dirty.ratio': 0.5
        }
    ),
    NewTopic(
        'streaming.user.dead-letter', 
        num_partitions=1,
        replication_factor=1,
        config={
            'retention.ms': str(30 * 24 * 60 * 60 * 1000),  # 30 days
            'cleanup.policy': 'delete'
        }
    ),
]

# Create topics
futures = admin.create_topics(topics)

for topic, future in futures.items():
    try:
        future.result()  # Wait for operation to complete
        logger.info(f'✅ Created topic: {topic}')
    except Exception as e:
        logger.error(f'❌ Failed to create topic {topic}: {e}')

# Verify topics were created
metadata = admin.list_topics(timeout=10)
logger.info("\n📋 Existing topics:")
for topic in metadata.topics.keys():
    if not topic.startswith('__'):  # Skip internal topics
        partitions = len(metadata.topics[topic].partitions)
        logger.info(f"  - {topic} ({partitions} partitions)")


Part 2: Event Producer (Complete)
python
# streampulse_producer.py
"""
StreamPulse Event Producer
Simulates realistic user interaction events.
"""
from confluent_kafka import Producer
import json
import time
import random
import uuid
from datetime import datetime, timedelta
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ============================================
# CONFIGURATION
# ============================================
KAFKA_CONFIG = {
    'bootstrap.servers': 'localhost:9092',
    'client.id': 'streampulse-simulator',
    'acks': 'all',                    # Wait for all replicas
    'retries': 5,                      # Retry on transient errors
    'retry.backoff.ms': 100,           # Backoff between retries
    'linger.ms': 20,                    # Wait for batching
    'batch.size': 32768,                # 32KB batch size
    'compression.type': 'snappy',       # Compress messages
    'enable.idempotence': True,         # Exactly-once semantics
    'max.in.flight.requests.per.connection': 5,
}

# ============================================
# EVENT GENERATORS
# ============================================
USERS = [f'user-{str(i).zfill(4)}' for i in range(1, 1001)]  # 1000 users
SHOWS = ['show-alpha', 'show-beta', 'show-gamma', 'show-delta', 'show-epsilon']
EPISODES = {show: [f'{show}-ep-{i}' for i in range(1, 13)] for show in SHOWS}
DEVICES = ['web', 'mobile-ios', 'mobile-android', 'smart-tv', 'tablet', 'game-console']
COUNTRIES = ['US', 'GB', 'DE', 'FR', 'JP', 'BR', 'IN', 'CA', 'AU', 'MX']
PLANS = ['free', 'basic', 'standard', 'premium']

def generate_interaction_event():
    """Generate a user interaction event."""
    user = random.choice(USERS)
    show = random.choice(SHOWS)
    episode = random.choice(EPISODES[show])
    
    # Weighted action distribution
    actions = ['play'] * 40 + ['pause'] * 15 + ['complete'] * 20 + \
              ['skip'] * 10 + ['like'] * 8 + ['share'] * 4 + ['add_to_list'] * 3
    
    return {
        'event_id': str(uuid.uuid4()),
        'event_type': 'interaction',
        'user_id': user,
        'action': random.choice(actions),
        'content_id': episode,
        'show_id': show,
        'device': random.choice(DEVICES),
        'country': random.choice(COUNTRIES),
        'timestamp': datetime.utcnow().isoformat() + 'Z',
        'duration_seconds': random.randint(0, 3600) if random.random() > 0.3 else 0,
        'session_id': f'session-{user}-{random.randint(1, 10)}',
        'playback_position': random.randint(0, 1800),
        'connection_speed': random.choice(['wifi', '5g', '4g', '3g']),
    }

def generate_page_view_event():
    """Generate a page view event."""
    user = random.choice(USERS)
    
    # Page types with probabilities
    page_types = ['home'] * 30 + ['show_details'] * 25 + ['search'] * 15 + \
                 ['profile'] * 10 + ['settings'] * 5 + ['billing'] * 5 + \
                 ['help'] * 5 + ['category'] * 5
    
    # Referrer sources
    referrers = ['direct'] * 40 + ['google'] * 20 + ['social'] * 15 + \
                ['email'] * 10 + ['internal'] * 15
    
    return {
        'event_id': str(uuid.uuid4()),
        'event_type': 'page_view',
        'user_id': user if random.random() > 0.2 else 'anonymous',  # 20% anonymous
        'page_type': random.choice(page_types),
        'page_url': f'/watch/{random.choice(SHOWS) if random.random() > 0.5 else ""}',
        'referrer': random.choice(referrers),
        'device': random.choice(DEVICES),
        'country': random.choice(COUNTRIES),
        'timestamp': datetime.utcnow().isoformat() + 'Z',
        'session_id': f'session-{user}-{random.randint(1, 10)}',
        'load_time_ms': random.randint(200, 3000),
        'browser': random.choice(['chrome', 'firefox', 'safari', 'edge', 'mobile-app']),
    }

def generate_transaction_event():
    """Generate a payment transaction event."""
    user = random.choice(USERS)
    
    # Transaction types
    tx_types = ['subscription_renewal'] * 50 + ['subscription_upgrade'] * 20 + \
               ['subscription_downgrade'] * 10 + ['one_time_purchase'] * 15 + \
               ['refund'] * 3 + ['gift_card'] * 2
    
    tx_type = random.choice(tx_types)
    
    # Determine amount based on type
    if 'subscription' in tx_type:
        amount = round(random.choice([9.99, 14.99, 19.99, 29.99, 49.99]), 2)
    elif 'refund' in tx_type:
        amount = round(random.uniform(-50, -5), 2)  # Negative amounts
    else:
        amount = round(random.uniform(4.99, 99.99), 2)
    
    # Payment methods
    payment_methods = ['credit_card'] * 60 + ['paypal'] * 20 + ['apple_pay'] * 10 + \
                      ['google_pay'] * 5 + ['gift_card'] * 3 + ['crypto'] * 2
    
    return {
        'event_id': str(uuid.uuid4()),
        'event_type': 'transaction',
        'order_id': f'ORD-{random.randint(100000, 999999)}',
        'user_id': user,
        'transaction_type': tx_type,
        'amount': amount,
        'currency': 'USD',
        'payment_method': random.choice(payment_methods),
        'plan': random.choice(PLANS),
        'status': random.choices(['success', 'success', 'success', 'pending', 'failed'], 
                                 weights=[70, 20, 5, 3, 2])[0],  # 95% success rate
        'timestamp': datetime.utcnow().isoformat() + 'Z',
        'device': random.choice(DEVICES),
        'country': random.choice(COUNTRIES),
        'promo_code': f'PROMO{random.randint(100, 999)}' if random.random() > 0.8 else None,
    }

# ============================================
# PRODUCER WITH METRICS
# ============================================
class StreamPulseProducer:
    def __init__(self):
        self.producer = Producer(KAFKA_CONFIG)
        self.metrics = {
            'sent': 0,
            'failed': 0,
            'by_topic': {},
            'by_partition': {},
            'bytes_sent': 0,
            'start_time': time.time(),
        }
        self.last_report = time.time()
    
    def _on_delivery(self, err, msg):
        """Delivery callback with metrics tracking."""
        if err:
            self.metrics['failed'] += 1
            logger.error(f'❌ DELIVERY FAILED: {err}')
        else:
            self.metrics['sent'] += 1
            topic = msg.topic()
            partition = msg.partition()
            self.metrics['by_topic'][topic] = \
                self.metrics['by_topic'].get(topic, 0) + 1
            self.metrics['by_partition'][f'{topic}-{partition}'] = \
                self.metrics['by_partition'].get(f'{topic}-{partition}', 0) + 1
            self.metrics['bytes_sent'] += len(msg.value())
        
        # Report every 10 seconds
        if time.time() - self.last_report >= 10:
            self.print_metrics()
            self.last_report = time.time()
    
    def publish(self, topic, key, event):
        """Publish an event to a topic."""
        try:
            event_json = json.dumps(event)
            self.producer.produce(
                topic=topic,
                key=key.encode('utf-8') if key else None,
                value=event_json.encode('utf-8'),
                callback=self._on_delivery,
                headers=[('event_type', event.get('event_type', 'unknown')),
                        ('timestamp', str(int(time.time()*1000)))]
            )
        except BufferError:
            logger.warning("Buffer full, flushing...")
            self.producer.flush()
            self.producer.produce(
                topic=topic,
                key=key.encode('utf-8') if key else None,
                value=json.dumps(event),
                callback=self._on_delivery,
            )
        self.producer.poll(0)
    
    def flush(self):
        self.producer.flush()
    
    def print_metrics(self):
        elapsed = time.time() - self.metrics['start_time']
        rate = self.metrics['sent'] / elapsed if elapsed > 0 else 0
        
        print(f'\n📊 --- Producer Metrics ({elapsed:.1f}s) ---')
        print(f"  Sent: {self.metrics['sent']:,} ({rate:.1f} events/sec)")
        print(f"  Failed: {self.metrics['failed']:,}")
        print(f"  Bytes: {self.metrics['bytes_sent']/1024/1024:.1f} MB")
        print(f"\n  By topic:")
        for topic, count in sorted(self.metrics['by_topic'].items()):
            print(f"    {topic}: {count:,}")
        print(f"\n  Top partitions:")
        for part, count in sorted(self.metrics['by_partition'].items(), 
                                 key=lambda x: x[1], reverse=True)[:5]:
            print(f"    {part}: {count:,}")

# ============================================
# MAIN: Simulate Event Stream
# ============================================
def main():
    producer = StreamPulseProducer()
    
    # Configuration
    EVENTS_PER_SECOND = 200  # Increased for better testing
    DURATION_SECONDS = 120   # Run for 2 minutes
    
    print(f'🚀 Starting StreamPulse Producer')
    print(f'  Events/sec: {EVENTS_PER_SECOND}')
    print(f'  Duration: {DURATION_SECONDS}s')
    print(f'  Users: {len(USERS)}')
    print(f'  Shows: {len(SHOWS)}\n')
    
    start = time.time()
    total_produced = 0
    error_rate = 0
    
    # Inject some malformed events occasionally
    inject_errors = True
    
    while time.time() - start < DURATION_SECONDS:
        batch_start = time.time()
        
        for _ in range(EVENTS_PER_SECOND):
            try:
                # 70% interactions, 20% page views, 10% transactions
                rand = random.random()
                
                # Inject malformed event occasionally (0.5%)
                if inject_errors and random.random() < 0.005:
                    # Send to wrong topic or malformed JSON
                    if random.random() < 0.5:
                        # Wrong topic
                        event = generate_interaction_event()
                        producer.publish(
                            'streaming.user.page-views',  # Wrong topic!
                            event['user_id'],
                            event
                        )
                    else:
                        # Malformed JSON - simulate by sending as string
                        producer.producer.produce(
                            topic='streaming.user.interactions',
                            key='error-test',
                            value=b'this is not json',
                            callback=producer._on_delivery,
                        )
                    total_produced += 1
                    continue
                
                if rand < 0.70:
                    event = generate_interaction_event()
                    producer.publish(
                        'streaming.user.interactions',
                        event['user_id'],
                        event
                    )
                elif rand < 0.90:
                    event = generate_page_view_event()
                    producer.publish(
                        'streaming.user.page-views',
                        event.get('user_id', ''),
                        event
                    )
                else:
                    event = generate_transaction_event()
                    producer.publish(
                        'payments.transaction.events',
                        event.get('order_id'),
                        event
                    )
                
                total_produced += 1
                
            except Exception as e:
                logger.error(f"Error producing event: {e}")
                error_rate += 1
        
        # Rate limiting
        elapsed = time.time() - batch_start
        if elapsed < 1.0:
            time.sleep(1.0 - elapsed)
        
        # Progress report
        if int(time.time() - start) % 10 == 0:
            print(f'  ⏱️  [{int(time.time()-start)}s] Produced: {total_produced:,}')
    
    producer.flush()
    producer.print_metrics()
    
    elapsed = time.time() - start
    print(f'\n✅ Production complete!')
    print(f'  Total events: {total_produced:,}')
    print(f'  Time: {elapsed:.1f}s')
    print(f'  Avg rate: {total_produced/elapsed:.1f} events/sec')
    print(f'  Errors: {error_rate}')

if __name__ == '__main__':
    main()



Part 3: Event Consumer (Complete)
python
# streampulse_consumer.py
"""
StreamPulse Analytics Consumer
Reads user interaction events and produces real-time aggregations.
"""
from confluent_kafka import Consumer, Producer, TopicPartition
import json
import time
from collections import defaultdict
from datetime import datetime
import logging
import signal
import sys

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

KAFKA_CONFIG = {
    'bootstrap.servers': 'localhost:9092',
    'group.id': 'streampulse-analytics-v1',
    'auto.offset.reset': 'earliest',
    'enable.auto.commit': False,
    'max.poll.interval.ms': 300000,
    'session.timeout.ms': 10000,
    'heartbeat.interval.ms': 3000,
    'max.partition.fetch.bytes': 1048576,  # 1MB
}

DEAD_LETTER_CONFIG = {
    'bootstrap.servers': 'localhost:9092',
    'client.id': 'dead-letter-producer',
}

class AnalyticsConsumer:
    def __init__(self, consumer_id="main"):
        self.consumer_id = consumer_id
        self.consumer = Consumer(KAFKA_CONFIG)
        self.dead_letter_producer = Producer(DEAD_LETTER_CONFIG)
        
        # Subscribe to topics
        self.consumer.subscribe(['streaming.user.interactions', 
                                 'streaming.user.page-views',
                                 'payments.transaction.events'])
        
        # Real-time aggregations
        self.window_start = time.time()
        self.window_duration = 10  # 10-second windows
        self.current_window = {
            'event_count': 0,
            'unique_users': set(),
            'by_action': defaultdict(int),
            'by_show': defaultdict(int),
            'by_device': defaultdict(int),
            'by_country': defaultdict(int),
            'by_page_type': defaultdict(int),  # For page views
            'by_transaction_type': defaultdict(int),  # For transactions
            'by_event_type': defaultdict(int),
        }
        
        # Performance metrics
        self.total_processed = 0
        self.total_errors = 0
        self.processing_times = []
        self.start_time = time.time()
        self.last_commit = time.time()
        
        # Setup signal handler for graceful shutdown
        signal.signal(signal.SIGINT, self.signal_handler)
    
    def signal_handler(self, sig, frame):
        print(f'\n\n🛑 Received interrupt, shutting down consumer {self.consumer_id}...')
        self.shutdown()
    
    def handle_dead_letter(self, msg, error):
        """Send unprocessable events to dead letter topic."""
        try:
            dead_letter_msg = {
                'original_topic': msg.topic(),
                'original_partition': msg.partition(),
                'original_offset': msg.offset(),
                'original_key': msg.key().decode('utf-8') if msg.key() else None,
                'original_value': msg.value().decode('utf-8', errors='ignore'),
                'error': str(error),
                'timestamp': datetime.utcnow().isoformat() + 'Z',
                'consumer_id': self.consumer_id,
                'headers': [{'key': k, 'value': v.decode('utf-8')} 
                           for k, v in (msg.headers() or [])]
            }
            
            self.dead_letter_producer.produce(
                topic='streaming.user.dead-letter',
                key=f"{msg.topic()}-{msg.partition()}-{msg.offset()}",
                value=json.dumps(dead_letter_msg),
                callback=self._on_dead_letter_delivery
            )
            self.dead_letter_producer.poll(0)
            
            logger.warning(f"💀 Sent to dead letter: offset={msg.offset()}, error={error}")
            
        except Exception as e:
            logger.error(f"Failed to send to dead letter: {e}")
    
    def _on_dead_letter_delivery(self, err, msg):
        if err:
            logger.error(f"Dead letter delivery failed: {err}")
    
    def process_event(self, event):
        """Process a single event and update aggregations."""
        event_type = event.get('event_type', 'unknown')
        
        # Update window aggregations
        self.current_window['event_count'] += 1
        self.current_window['by_event_type'][event_type] += 1
        
        # Track unique users (handle anonymous)
        user_id = event.get('user_id')
        if user_id and user_id != 'anonymous':
            self.current_window['unique_users'].add(user_id)
        
        # Event-type specific aggregations
        if event_type == 'interaction':
            self.current_window['by_action'][event.get('action', 'unknown')] += 1
            self.current_window['by_show'][event.get('show_id', 'unknown')] += 1
        elif event_type == 'page_view':
            self.current_window['by_page_type'][event.get('page_type', 'unknown')] += 1
        elif event_type == 'transaction':
            self.current_window['by_transaction_type'][event.get('transaction_type', 'unknown')] += 1
        
        # Global aggregations
        self.current_window['by_device'][event.get('device', 'unknown')] += 1
        self.current_window['by_country'][event.get('country', 'unknown')] += 1
    
    def emit_window(self):
        """Print the current window aggregations and reset."""
        w = self.current_window
        elapsed = time.time() - self.window_start
        total_elapsed = time.time() - self.start_time
        rate = self.total_processed / total_elapsed if total_elapsed > 0 else 0
        
        print(f'\n╔══════════════════════════════════════════════════════════╗')
        print(f'║  📊 CONSUMER [{self.consumer_id}] - {datetime.now().strftime("%H:%M:%S")}')
        print(f'║  Window: {elapsed:.0f}s | Events: {w["event_count"]:,} | '
              f'Users: {len(w["unique_users"]):,}')
        print(f'║  Total: {self.total_processed:,} | Rate: {rate:.1f}/s | '
              f'Errors: {self.total_errors}')
        print(f'╠══════════════════════════════════════════════════════════╣')
        
        # Event types
        if w['by_event_type']:
            event_types = sorted(w['by_event_type'].items(), 
                               key=lambda x: x[1], reverse=True)
            print(f'║  📌 Event types: {", ".join(f"{t}:{c}" for t,c in event_types)}')
        
        # Top actions
        if w['by_action']:
            top_actions = sorted(w['by_action'].items(),
                               key=lambda x: x[1], reverse=True)[:5]
            print(f'║  🎬 Actions: {", ".join(f"{a}:{c}" for a,c in top_actions)}')
        
        # Top shows
        if w['by_show']:
            top_shows = sorted(w['by_show'].items(),
                              key=lambda x: x[1], reverse=True)[:3]
            print(f'║  📺 Shows: {", ".join(f"{s}:{c}" for s,c in top_shows)}')
        
        # Top page types
        if w['by_page_type']:
            top_pages = sorted(w['by_page_type'].items(),
                              key=lambda x: x[1], reverse=True)[:3]
            print(f'║  📄 Pages: {", ".join(f"{p}:{c}" for p,c in top_pages)}')
        
        # Top countries
        if w['by_country']:
            top_countries = sorted(w['by_country'].items(),
                                  key=lambda x: x[1], reverse=True)[:5]
            countries_str = ", ".join(f"{c}:{v}" for c,v in top_countries)
            print(f'║  🌍 Top countries: {countries_str}')
        
        # Top devices
        if w['by_device']:
            top_devices = sorted(w['by_device'].items(),
                                key=lambda x: x[1], reverse=True)[:3]
            print(f'║  📱 Devices: {", ".join(f"{d}:{c}" for d,c in top_devices)}')
        
        # Processing time stats
        if self.processing_times:
            avg_time = sum(self.processing_times[-100:]) / len(self.processing_times[-100:])
            print(f'║  ⚡ Processing time: {avg_time*1000:.2f}ms avg')
        
        print(f'╚══════════════════════════════════════════════════════════╝')
        
        # Reset window
        self.window_start = time.time()
        self.current_window = {
            'event_count': 0,
            'unique_users': set(),
            'by_action': defaultdict(int),
            'by_show': defaultdict(int),
            'by_device': defaultdict(int),
            'by_country': defaultdict(int),
            'by_page_type': defaultdict(int),
            'by_transaction_type': defaultdict(int),
            'by_event_type': defaultdict(int),
        }
        
        # Clear processing times periodically
        if len(self.processing_times) > 1000:
            self.processing_times = self.processing_times[-500:]
    
    def check_lag(self):
        """Check consumer lag for debugging."""
        try:
            # Get end offsets for all partitions
            watermarks = {}
            for topic in ['streaming.user.interactions', 
                         'streaming.user.page-views',
                         'payments.transaction.events']:
                metadata = self.consumer.list_topics(topic)
                for partition in metadata.topics[topic].partitions:
                    tp = TopicPartition(topic, partition)
                    # Get committed offset
                    committed = self.consumer.committed([tp])[0]
                    # Get high watermark
                    watermark = self.consumer.get_watermark_offsets(tp)
                    if committed.offset > 0:
                        lag = watermark[1] - committed.offset
                        watermarks[f"{topic}-{partition}"] = lag
            
            return watermarks
        except Exception as e:
            logger.error(f"Error checking lag: {e}")
            return {}
    
    def run(self):
        """Main consumer loop."""
        print(f'🚀 StreamPulse Analytics Consumer [{self.consumer_id}] starting...')
        print(f'  Group ID: {KAFKA_CONFIG["group.id"]}')
        print(f'  Window size: {self.window_duration} seconds\n')
        
        batch_count = 0
        last_lag_check = time.time()
        
        try:
            while True:
                msg = self.consumer.poll(timeout=1.0)
                
                if msg is None:
                    # Check if window should emit
                    if time.time() - self.window_start >= self.window_duration:
                        if self.current_window['event_count'] > 0:
                            self.emit_window()
                    
                    # Check lag every 30 seconds
                    if time.time() - last_lag_check >= 30:
                        lag = self.check_lag()
                        if lag:
                            total_lag = sum(lag.values())
                            if total_lag > 1000:
                                logger.warning(f"⚠️  High lag detected: {total_lag} messages")
                        last_lag_check = time.time()
                    
                    continue
                
                if msg.error():
                    logger.error(f'Consumer error: {msg.error()}')
                    continue
                
                # Measure processing time
                process_start = time.time()
                
                try:
                    # Try to parse as JSON
                    try:
                        event = json.loads(msg.value().decode('utf-8'))
                    except json.JSONDecodeError as e:
                        # Handle malformed JSON
                        self.total_errors += 1
                        self.handle_dead_letter(msg, f"JSON decode error: {e}")
                        continue
                    
                    # Validate required fields
                    if 'event_type' not in event:
                        self.total_errors += 1
                        self.handle_dead_letter(msg, "Missing event_type field")
                        continue
                    
                    # Process valid event
                    self.process_event(event)
                    self.total_processed += 1
                    batch_count += 1
                    
                    # Track processing time
                    process_time = time.time() - process_start
                    self.processing_times.append(process_time)
                    
                except Exception as e:
                    self.total_errors += 1
                    self.handle_dead_letter(msg, f"Processing error: {str(e)}")
                
                # Commit every 500 events or 10 seconds
                if batch_count >= 500 or (time.time() - self.last_commit) >= 10:
                    self.consumer.commit(asynchronous=False)
                    batch_count = 0
                    self.last_commit = time.time()
                
                # Emit window on schedule
                if time.time() - self.window_start >= self.window_duration:
                    self.emit_window()
                
        except KeyboardInterrupt:
            self.shutdown()
    
    def shutdown(self):
        """Graceful shutdown."""
        # Emit final window
        if self.current_window['event_count'] > 0:
            self.emit_window()
        
        # Final stats
        elapsed = time.time() - self.start_time
        rate = self.total_processed / elapsed if elapsed > 0 else 0
        
        print(f'\n📊 Final Statistics [{self.consumer_id}]:')
        print(f'  Total processed: {self.total_processed:,}')
        print(f'  Total errors: {self.total_errors:,}')
        print(f'  Runtime: {elapsed:.1f}s')
        print(f'  Avg rate: {rate:.1f} events/sec')
        
        # Flush dead letter producer
        self.dead_letter_producer.flush()
        
        # Commit and close
        try:
            self.consumer.commit(asynchronous=False)
        except:
            pass
        self.consumer.close()
        sys.exit(0)

if __name__ == '__main__':
    # Allow passing consumer ID as argument
    import sys
    consumer_id = sys.argv[1] if len(sys.argv) > 1 else "main"
    
    consumer = AnalyticsConsumer(consumer_id)
    consumer.run()




Part 4: End-to-End Test
bash
# Terminal 1: Start the producer
python streampulse_producer.py

# Terminal 2: Start the analytics consumer (group: streampulse-analytics-v1)
python streampulse_consumer.py main

# Terminal 3: Start a second consumer (different group)
# Edit streampulse_consumer.py or override via environment
KAFKA_CONFIG['group.id'] = 'streampulse-monitoring-v1'
python streampulse_consumer.py monitor

# Terminal 4: Monitor Kafka topics (optional)
# Watch messages in real-time
docker exec -it streampulse-kafka-1 kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic streaming.user.interactions \
  --from-beginning \
  --timeout-ms 5000 | head -20

# Check consumer groups and lag
docker exec -it streampulse-kafka-1 kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --group streampulse-analytics-v1 \
  --describe

# Check dead letter topic
docker exec -it streampulse-kafka-1 kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic streaming.user.dead-letter \
  --from-beginning \
  --max-messages 5