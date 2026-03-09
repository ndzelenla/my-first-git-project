(Guided) Kafka Producer-Consumer
Author: Sammy Ndzelen
Date: 09.03.2026

Part 1: Project Structure
text
streampulse-pipeline/
├── config.py                      # Shared Kafka configuration
├── models.py                      # Event data models & validation
├── producer.py                     # Multi-event producer
├── consumers/
│   ├── __init__.py                 # Makes consumers a package
│   ├── analytics.py                 # Analytics consumer (provided)
│   ├── engagement.py                 # Engagement consumer (to implement)
│   └── revenue.py                    # Revenue consumer (to implement)
├── monitoring/
│   └── dashboard.py                 # Real-time metrics dashboard
├── docker-compose.kafka.yml         # Kafka cluster
├── setup_topics.py                   # Topic creation
├── run_pipeline.py                    # Orchestrator
├── requirements.txt                    # Dependencies
└── README.md                            # Documentation
Part 2: Shared Configuration
python
# config.py
"""
Shared Kafka configuration for all StreamPulse components.
"""
import socket
import platform

# Kafka Connection
KAFKA_BOOTSTRAP = 'localhost:9092'

# Topics
TOPICS = {
    'user_interactions': 'streaming.user.interactions',
    'page_views': 'streaming.user.page-views',
    'transactions': 'payments.transaction.events',
    'dead_letter': 'streaming.user.dead-letter',
}

# Producer configuration
PRODUCER_CONFIG = {
    'bootstrap.servers': KAFKA_BOOTSTRAP,
    'client.id': f'streampulse-producer-{socket.gethostname()}',
    'acks': 'all',                    # Wait for all replicas
    'retries': 5,                      # Retry on transient errors
    'retry.backoff.ms': 100,           # Backoff between retries
    'linger.ms': 20,                    # Wait for batching
    'batch.size': 32768,                # 32KB batch size
    'compression.type': 'snappy',       # Compress messages
    'enable.idempotence': True,         # Exactly-once semantics
    'max.in.flight.requests.per.connection': 5,
}

# Consumer configuration factory
def consumer_config(group_id, offset_reset='earliest'):
    """Generate consumer config for a specific consumer group."""
    hostname = socket.gethostname()
    return {
        'bootstrap.servers': KAFKA_BOOTSTRAP,
        'group.id': group_id,
        'client.id': f'{group_id}-{hostname}-{platform.python_version()}',
        'auto.offset.reset': offset_reset,
        'enable.auto.commit': False,     # Manual commit for control
        'max.poll.interval.ms': 300000,   # 5 minutes
        'session.timeout.ms': 10000,      # 10 seconds
        'heartbeat.interval.ms': 3000,    # 3 seconds
        'max.partition.fetch.bytes': 1048576,  # 1MB per partition
        'fetch.min.bytes': 1,              # Get data as soon as available
        'fetch.max.wait.ms': 500,           # Wait up to 500ms
    }

# Window configurations
WINDOW_CONFIG = {
    'analytics': {'size': 10, 'unit': 'seconds'},   # 10s windows
    'engagement': {'size': 30, 'unit': 'seconds'},  # 30s windows
    'revenue': {'size': 60, 'unit': 'seconds'},     # 1min windows
}

# Metrics configuration
METRICS_CONFIG = {
    'enabled': True,
    'report_interval': 10,  # seconds
    'detailed_reporting': True,
}

# Dead letter configuration
DEAD_LETTER_CONFIG = {
    'enabled': True,
    'max_retries': 3,
    'retry_backoff_ms': 1000,
}
Part 3: Event Models
python
# models.py
"""
Event data models with validation.
"""
from dataclasses import dataclass, field, asdict
from datetime import datetime
import uuid
import random
from typing import Optional, List, Dict, Any
import json

@dataclass
class BaseEvent:
    """Base event class with common fields."""
    event_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    timestamp: str = field(default_factory=lambda: datetime.utcnow().isoformat() + 'Z')
    event_type: str = 'base'
    
    def to_json(self):
        """Convert to JSON string."""
        return json.dumps(asdict(self))
    
    def validate(self) -> bool:
        """Validate event data."""
        return bool(self.event_id and self.timestamp)

@dataclass
class InteractionEvent(BaseEvent):
    """User interaction event."""
    event_type: str = 'interaction'
    user_id: str = ''
    action: str = ''  # play, pause, complete, skip, like, share
    content_id: str = ''
    show_id: str = ''
    device: str = ''
    country: str = ''
    duration_seconds: int = 0
    session_id: str = ''
    playback_position: int = 0
    
    def validate(self) -> bool:
        """Validate interaction event."""
        valid_actions = ['play', 'pause', 'complete', 'skip', 'like', 'share']
        return (super().validate() and 
                bool(self.user_id) and 
                self.action in valid_actions and
                bool(self.content_id))

@dataclass
class PageViewEvent(BaseEvent):
    """Page view event."""
    event_type: str = 'page_view'
    user_id: str = ''
    page_type: str = ''  # home, show_details, search, profile, etc.
    page_url: str = ''
    referrer: str = ''
    device: str = ''
    country: str = ''
    session_id: str = ''
    load_time_ms: int = 0
    browser: str = ''

@dataclass
class TransactionEvent(BaseEvent):
    """Payment transaction event."""
    event_type: str = 'transaction'
    order_id: str = ''
    user_id: str = ''
    transaction_type: str = ''  # subscription_renewal, upgrade, downgrade, etc.
    amount: float = 0.0
    currency: str = 'USD'
    payment_method: str = ''  # credit_card, paypal, apple_pay, etc.
    plan: str = ''  # free, basic, standard, premium
    status: str = ''  # success, pending, failed
    device: str = ''
    country: str = ''
    promo_code: Optional[str] = None

@dataclass
class DeadLetterEvent:
    """Dead letter event for failed processing."""
    original_topic: str
    original_partition: int
    original_offset: int
    original_key: Optional[str]
    original_value: str
    error: str
    timestamp: str
    consumer_id: str
    headers: List[Dict[str, str]]

# Sample data generators
class EventGenerator:
    """Generate realistic test events."""
    
    USERS = [f'user-{str(i).zfill(4)}' for i in range(1, 1001)]
    SHOWS = ['show-alpha', 'show-beta', 'show-gamma', 'show-delta', 'show-epsilon']
    DEVICES = ['web', 'mobile-ios', 'mobile-android', 'smart-tv', 'tablet']
    COUNTRIES = ['US', 'GB', 'DE', 'FR', 'JP', 'BR', 'IN', 'CA', 'AU']
    PLANS = ['free', 'basic', 'standard', 'premium']
    PAYMENT_METHODS = ['credit_card', 'paypal', 'apple_pay', 'google_pay']
    
    @classmethod
    def generate_interaction(cls) -> InteractionEvent:
        """Generate a random interaction event."""
        user = random.choice(cls.USERS)
        show = random.choice(cls.SHOWS)
        
        actions = ['play'] * 40 + ['pause'] * 15 + ['complete'] * 20 + \
                  ['skip'] * 10 + ['like'] * 10 + ['share'] * 5
        
        return InteractionEvent(
            user_id=user,
            action=random.choice(actions),
            content_id=f'{show}-ep-{random.randint(1,12)}',
            show_id=show,
            device=random.choice(cls.DEVICES),
            country=random.choice(cls.COUNTRIES),
            duration_seconds=random.randint(0, 3600),
            session_id=f'session-{user}-{random.randint(1,10)}',
            playback_position=random.randint(0, 1800)
        )
    
    @classmethod
    def generate_transaction(cls) -> TransactionEvent:
        """Generate a random transaction event."""
        user = random.choice(cls.USERS)
        
        tx_types = ['subscription_renewal'] * 50 + ['subscription_upgrade'] * 20 + \
                   ['subscription_downgrade'] * 10 + ['one_time_purchase'] * 15 + \
                   ['refund'] * 3 + ['gift_card'] * 2
        
        tx_type = random.choice(tx_types)
        
        if 'subscription' in tx_type:
            amount = round(random.choice([9.99, 14.99, 19.99, 29.99, 49.99]), 2)
        elif 'refund' in tx_type:
            amount = round(random.uniform(-50, -5), 2)
        else:
            amount = round(random.uniform(4.99, 99.99), 2)
        
        return TransactionEvent(
            order_id=f'ORD-{random.randint(100000, 999999)}',
            user_id=user,
            transaction_type=tx_type,
            amount=amount,
            payment_method=random.choice(cls.PAYMENT_METHODS),
            plan=random.choice(cls.PLANS),
            status=random.choices(['success', 'success', 'pending', 'failed'], 
                                 weights=[80, 15, 3, 2])[0],
            device=random.choice(cls.DEVICES),
            country=random.choice(cls.COUNTRIES),
            promo_code=f'PROMO{random.randint(100,999)}' if random.random() > 0.8 else None
        )
Part 4: Producer Implementation
python
# producer.py
"""
StreamPulse multi-event producer.
Generates interaction and transaction events.
"""
from confluent_kafka import Producer
import json
import time
import random
import logging
from datetime import datetime
from config import PRODUCER_CONFIG, TOPICS, DEAD_LETTER_CONFIG
from models import EventGenerator, InteractionEvent, TransactionEvent

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class EventProducer:
    def __init__(self, name="main"):
        self.name = name
        self.producer = Producer(PRODUCER_CONFIG)
        self.metrics = {
            'total_sent': 0,
            'total_failed': 0,
            'by_topic': {},
            'by_partition': {},
            'bytes_sent': 0,
            'start_time': time.time(),
            'errors': []
        }
        self.last_report = time.time()
        self.running = True
    
    def _delivery_callback(self, err, msg):
        """Delivery callback with metrics tracking."""
        if err:
            self.metrics['total_failed'] += 1
            self.metrics['errors'].append({
                'time': datetime.now().isoformat(),
                'error': str(err),
                'topic': msg.topic() if msg else 'unknown'
            })
            logger.error(f'❌ Delivery failed: {err}')
        else:
            self.metrics['total_sent'] += 1
            topic = msg.topic()
            partition = msg.partition()
            
            # Update topic metrics
            self.metrics['by_topic'][topic] = self.metrics['by_topic'].get(topic, 0) + 1
            
            # Update partition metrics
            part_key = f'{topic}-{partition}'
            self.metrics['by_partition'][part_key] = self.metrics['by_partition'].get(part_key, 0) + 1
            
            # Track bytes
            self.metrics['bytes_sent'] += len(msg.value()) if msg.value() else 0
        
        # Report every 10 seconds
        if time.time() - self.last_report >= 10:
            self.print_metrics()
            self.last_report = time.time()
    
    def produce_interaction(self) -> bool:
        """Generate and publish a user interaction event."""
        try:
            event = EventGenerator.generate_interaction()
            
            # Add some malformed events occasionally (0.5%)
            if random.random() < 0.005:
                # Send malformed data
                self.producer.produce(
                    topic=TOPICS['user_interactions'],
                    key=event.user_id,
                    value=b'this is not valid json',  # Malformed
                    callback=self._delivery_callback
                )
                logger.debug("Sent malformed event to test dead letter")
                return True
            
            self.producer.produce(
                topic=TOPICS['user_interactions'],
                key=event.user_id,
                value=event.to_json().encode('utf-8'),
                headers=[
                    ('event_type', 'interaction'),
                    ('version', '1.0'),
                    ('timestamp', str(int(time.time()*1000)))
                ],
                callback=self._delivery_callback
            )
            return True
            
        except BufferError:
            logger.warning("Producer buffer full, flushing...")
            self.producer.flush()
            return self.produce_interaction()
        except Exception as e:
            logger.error(f"Error producing interaction: {e}")
            return False
    
    def produce_transaction(self) -> bool:
        """Generate and publish a transaction event."""
        try:
            event = EventGenerator.generate_transaction()
            
            self.producer.produce(
                topic=TOPICS['transactions'],
                key=event.order_id,
                value=event.to_json().encode('utf-8'),
                headers=[
                    ('event_type', 'transaction'),
                    ('version', '1.0'),
                    ('currency', event.currency),
                    ('status', event.status)
                ],
                callback=self._delivery_callback
            )
            return True
            
        except BufferError:
            logger.warning("Producer buffer full, flushing...")
            self.producer.flush()
            return self.produce_transaction()
        except Exception as e:
            logger.error(f"Error producing transaction: {e}")
            return False
    
    def run(self, events_per_second=50, duration_seconds=120):
        """Run the producer for a specified duration."""
        logger.info(f'🚀 Producer {self.name} starting: {events_per_second} events/sec')
        logger.info(f'   Duration: {duration_seconds}s')
        logger.info(f'   Topics: {TOPICS["user_interactions"]}, {TOPICS["transactions"]}\n')
        
        start = time.time()
        target_events = events_per_second * duration_seconds
        produced = 0
        
        while time.time() - start < duration_seconds and produced < target_events:
            batch_start = time.time()
            batch_events = 0
            
            # Produce a batch of events
            for _ in range(events_per_second):
                # 85% interactions, 15% transactions
                if random.random() < 0.85:
                    success = self.produce_interaction()
                else:
                    success = self.produce_transaction()
                
                if success:
                    produced += 1
                    batch_events += 1
                
                self.producer.poll(0)  # Trigger callbacks
            
            # Rate limiting - maintain exactly events_per_second
            elapsed = time.time() - batch_start
            if elapsed < 1.0:
                time.sleep(1.0 - elapsed)
            
            # Progress report every 10 seconds
            if int(time.time() - start) % 10 == 0:
                progress = (time.time() - start) / duration_seconds * 100
                logger.info(f'  [{int(time.time()-start)}s] Produced: {produced:,} '
                          f'({progress:.0f}%)')
        
        # Final flush
        self.producer.flush()
        self.print_metrics()
        
        elapsed = time.time() - start
        logger.info(f'\n✅ Producer {self.name} complete!')
        logger.info(f'   Total events: {produced:,}')
        logger.info(f'   Time: {elapsed:.1f}s')
        logger.info(f'   Avg rate: {produced/elapsed:.1f} events/sec')
        
        return self.metrics
    
    def print_metrics(self):
        """Print current metrics."""
        elapsed = time.time() - self.metrics['start_time']
        rate = self.metrics['total_sent'] / elapsed if elapsed > 0 else 0
        
        print(f'\n📊 --- Producer [{self.name}] Metrics ({elapsed:.1f}s) ---')
        print(f"  Sent: {self.metrics['total_sent']:,} ({rate:.1f}/sec)")
        print(f"  Failed: {self.metrics['total_failed']:,}")
        print(f"  Bytes: {self.metrics['bytes_sent']/1024/1024:.1f} MB")
        
        if self.metrics['by_topic']:
            print(f"\n  By topic:")
            for topic, count in sorted(self.metrics['by_topic'].items()):
                print(f"    {topic}: {count:,}")
        
        if self.metrics['errors']:
            print(f"\n  Last error: {self.metrics['errors'][-1]['error']}")
    
    def close(self):
        """Close producer."""
        self.running = False
        self.producer.flush()
Part 5: Analytics Consumer (Provided)
python
# consumers/analytics.py
"""
Analytics consumer: real-time event counting and top-N analysis.
Reads from user.interactions topic.
"""
from confluent_kafka import Consumer, TopicPartition
import json
import time
from collections import defaultdict
from datetime import datetime
import logging
from config import consumer_config, TOPICS

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class AnalyticsConsumer:
    def __init__(self, name="analytics"):
        self.name = name
        self.consumer = Consumer(consumer_config('streampulse-analytics-v1'))
        self.consumer.subscribe([TOPICS['user_interactions']])
        
        # Window aggregations
        self.window = {
            'actions': defaultdict(int),
            'content': defaultdict(int),
            'devices': defaultdict(int),
            'countries': defaultdict(int),
            'total': {'count': 0, 'users': set()}
        }
        self.window_start = time.time()
        self.window_size = 10  # seconds
        
        # Metrics
        self.processed = 0
        self.errors = 0
        self.running = True
        self.start_time = time.time()
        self.last_commit = time.time()
        self.batch_count = 0
    
    def process(self, event):
        """Update analytics counters."""
        self.window['actions'][event.get('action', 'unknown')] += 1
        self.window['content'][event.get('content_id', 'unknown')] += 1
        self.window['devices'][event.get('device', 'unknown')] += 1
        self.window['countries'][event.get('country', 'unknown')] += 1
        self.window['total']['count'] += 1
        
        user_id = event.get('user_id')
        if user_id:
            self.window['total']['users'].add(user_id)
    
    def emit_report(self):
        """Print analytics report for current window."""
        if self.window['total']['count'] == 0:
            return
        
        elapsed = time.time() - self.start_time
        rate = self.processed / elapsed if elapsed > 0 else 0
        
        print(f'\n╔══════════════════════════════════════════════════════════╗')
        print(f'║  📊 ANALYTICS [{self.name}] - {datetime.now().strftime("%H:%M:%S")}')
        print(f'║  Window: {self.window_size}s | Events: {self.window["total"]["count"]:,} | '
              f'Users: {len(self.window["total"]["users"]):,}')
        print(f'║  Total: {self.processed:,} | Rate: {rate:.1f}/s | Errors: {self.errors}')
        print(f'╠══════════════════════════════════════════════════════════╣')
        
        # Top 5 actions
        if self.window['actions']:
            top_actions = sorted(self.window['actions'].items(),
                               key=lambda x: x[1], reverse=True)[:5]
            actions_str = ", ".join(f"{a}:{c}" for a,c in top_actions)
            print(f'║  🎬 Actions: {actions_str}')
        
        # Top 3 content
        if self.window['content']:
            top_content = sorted(self.window['content'].items(),
                               key=lambda x: x[1], reverse=True)[:3]
            content_str = ", ".join(f"{c[:15]}...:{v}" for c,v in top_content)
            print(f'║  📺 Content: {content_str}')
        
        # Top 3 devices
        if self.window['devices']:
            top_devices = sorted(self.window['devices'].items(),
                               key=lambda x: x[1], reverse=True)[:3]
            devices_str = ", ".join(f"{d}:{c}" for d,c in top_devices)
            print(f'║  📱 Devices: {devices_str}')
        
        # Top 3 countries
        if self.window['countries']:
            top_countries = sorted(self.window['countries'].items(),
                                 key=lambda x: x[1], reverse=True)[:3]
            countries_str = ", ".join(f"{c}:{v}" for c,v in top_countries)
            print(f'║  🌍 Countries: {countries_str}')
        
        print(f'╚══════════════════════════════════════════════════════════╝')
        
        # Reset window
        self.window = {
            'actions': defaultdict(int),
            'content': defaultdict(int),
            'devices': defaultdict(int),
            'countries': defaultdict(int),
            'total': {'count': 0, 'users': set()}
        }
        self.window_start = time.time()
    
    def check_lag(self):
        """Check consumer lag."""
        try:
            lags = []
            partitions = self.consumer.assignment()
            for tp in partitions:
                committed = self.consumer.committed([tp])[0]
                watermark = self.consumer.get_watermark_offsets(tp)
                if committed.offset >= 0:
                    lag = watermark[1] - committed.offset
                    lags.append(lag)
            return sum(lags) if lags else 0
        except Exception as e:
            logger.debug(f"Error checking lag: {e}")
            return 0
    
    def run(self):
        """Main consumer loop."""
        logger.info(f'🚀 Analytics Consumer [{self.name}] started')
        logger.info(f'   Group: streampulse-analytics-v1')
        logger.info(f'   Window: {self.window_size}s')
        
        try:
            while self.running:
                msg = self.consumer.poll(timeout=1.0)
                
                if msg is None:
                    # Check if window should emit
                    if time.time() - self.window_start >= self.window_size:
                        self.emit_report()
                    
                    # Check lag occasionally
                    if int(time.time()) % 30 == 0:
                        lag = self.check_lag()
                        if lag > 1000:
                            logger.warning(f"⚠️ High lag: {lag} messages")
                    
                    continue
                
                if msg.error():
                    logger.error(f'Consumer error: {msg.error()}')
                    continue
                
                try:
                    event = json.loads(msg.value().decode('utf-8'))
                    self.process(event)
                    self.processed += 1
                    self.batch_count += 1
                    
                except json.JSONDecodeError as e:
                    self.errors += 1
                    logger.error(f"JSON decode error: {e}")
                except Exception as e:
                    self.errors += 1
                    logger.error(f"Processing error: {e}")
                
                # Commit every 500 events or 10 seconds
                if self.batch_count >= 500 or (time.time() - self.last_commit) >= 10:
                    self.consumer.commit(asynchronous=False)
                    self.batch_count = 0
                    self.last_commit = time.time()
                
                # Emit window if needed
                if time.time() - self.window_start >= self.window_size:
                    self.emit_report()
                    
        except KeyboardInterrupt:
            logger.info("Shutting down...")
        finally:
            self.shutdown()
    
    def shutdown(self):
        """Graceful shutdown."""
        # Emit final report
        if self.window['total']['count'] > 0:
            self.emit_report()
        
        # Final stats
        elapsed = time.time() - self.start_time
        rate = self.processed / elapsed if elapsed > 0 else 0
        logger.info(f'\n📊 Analytics Final Stats:')
        logger.info(f'   Processed: {self.processed:,}')
        logger.info(f'   Errors: {self.errors:,}')
        logger.info(f'   Runtime: {elapsed:.1f}s')
        logger.info(f'   Avg rate: {rate:.1f}/s')
        
        # Commit and close
        try:
            self.consumer.commit(asynchronous=False)
        except:
            pass
        self.consumer.close()


Part 6: Revenue Consumer (COMPLETE IMPLEMENTATION)
python
# consumers/revenue.py
"""
Revenue consumer: real-time revenue tracking from transaction events.
Reads from payments.transaction.events topic.
"""
from confluent_kafka import Consumer
import json
import time
from collections import defaultdict
from datetime import datetime, timedelta
import logging
from config import consumer_config, TOPICS

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class RevenueConsumer:
    def __init__(self, name="revenue"):
        """Initialize revenue consumer with tracking structures."""
        self.name = name
        self.consumer = Consumer(consumer_config('streampulse-revenue-v1'))
        self.consumer.subscribe([TOPICS['transactions']])
        
        # Revenue tracking per minute window
        self.window = {
            'revenue_by_minute': defaultdict(float),  # minute -> total revenue
            'transaction_count': 0,
            'failed_count': 0,
            'successful_count': 0,
            'pending_count': 0,
            'by_payment_method': defaultdict(lambda: {'count': 0, 'amount': 0.0}),
            'by_currency': defaultdict(lambda: {'count': 0, 'amount': 0.0}),
            'by_plan': defaultdict(lambda: {'count': 0, 'amount': 0.0}),
            'by_transaction_type': defaultdict(lambda: {'count': 0, 'amount': 0.0}),
            'largest_transaction': {'amount': 0.0, 'order_id': '', 'user_id': ''},
            'avg_transaction_value': 0.0,
            'total_revenue': 0.0,
        }
        
        # Running totals
        self.total_processed = 0
        self.total_revenue_all_time = 0.0
        self.total_transactions_all_time = 0
        
        # Window timing
        self.window_start = time.time()
        self.window_size = 60  # seconds (1 minute)
        self.current_minute = datetime.now().strftime('%Y-%m-%d %H:%M')
        
        # Metrics
        self.processed = 0
        self.errors = 0
        self.running = True
        self.start_time = time.time()
        self.last_commit = time.time()
        self.batch_count = 0
        
        logger.info(f'💰 Revenue Consumer [{self.name}] initialized')
    
    def process(self, event):
        """Process a transaction event and update revenue metrics."""
        try:
            # Extract transaction data
            order_id = event.get('order_id', 'unknown')
            user_id = event.get('user_id', 'unknown')
            amount = float(event.get('amount', 0.0))
            currency = event.get('currency', 'USD')
            payment_method = event.get('payment_method', 'unknown')
            plan = event.get('plan', 'unknown')
            transaction_type = event.get('transaction_type', 'unknown')
            status = event.get('status', 'unknown')
            timestamp = event.get('timestamp', datetime.utcnow().isoformat())
            
            # Get minute for this transaction
            try:
                dt = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
                minute_key = dt.strftime('%Y-%m-%d %H:%M')
            except:
                minute_key = self.current_minute
            
            # Update window metrics based on status
            self.window['transaction_count'] += 1
            self.total_transactions_all_time += 1
            
            if status == 'success':
                self.window['successful_count'] += 1
                
                # Update revenue
                self.window['revenue_by_minute'][minute_key] += amount
                self.window['total_revenue'] += amount
                self.total_revenue_all_time += amount
                
                # Update payment method stats
                self.window['by_payment_method'][payment_method]['count'] += 1
                self.window['by_payment_method'][payment_method]['amount'] += amount
                
                # Update currency stats
                self.window['by_currency'][currency]['count'] += 1
                self.window['by_currency'][currency]['amount'] += amount
                
                # Update plan stats
                self.window['by_plan'][plan]['count'] += 1
                self.window['by_plan'][plan]['amount'] += amount
                
                # Update transaction type stats
                self.window['by_transaction_type'][transaction_type]['count'] += 1
                self.window['by_transaction_type'][transaction_type]['amount'] += amount
                
                # Track largest transaction
                if amount > self.window['largest_transaction']['amount']:
                    self.window['largest_transaction'] = {
                        'amount': amount,
                        'order_id': order_id,
                        'user_id': user_id,
                        'currency': currency,
                        'timestamp': timestamp
                    }
                
            elif status == 'failed':
                self.window['failed_count'] += 1
                logger.debug(f"❌ Failed transaction: {order_id}, amount: {amount} {currency}")
            else:  # pending or other
                self.window['pending_count'] += 1
            
            # Update average transaction value
            successful_count = self.window['successful_count']
            if successful_count > 0:
                self.window['avg_transaction_value'] = (
                    self.window['total_revenue'] / successful_count
                )
            
            self.processed += 1
            
        except Exception as e:
            self.errors += 1
            logger.error(f"Error processing transaction event: {e}")
    
    def emit_report(self):
        """Print revenue report for current window."""
        if self.window['transaction_count'] == 0:
            return
        
        elapsed = time.time() - self.start_time
        rate = self.processed / elapsed if elapsed > 0 else 0
        
        # Calculate revenue rate
        revenue_rate = self.window['total_revenue'] / (self.window_size / 60) if self.window_size > 0 else 0  # per hour
        
        print(f'\n╔══════════════════════════════════════════════════════════╗')
        print(f'║  💰 REVENUE [{self.name}] - {datetime.now().strftime("%H:%M:%S")}')
        print(f'║  Window: {self.window_size}s | Transactions: {self.window["transaction_count"]:,}')
        print(f'║  Total: {self.processed:,} | Rate: {rate:.1f}/s | Errors: {self.errors}')
        print(f'╠══════════════════════════════════════════════════════════╣')
        
        # Revenue summary
        print(f'║  💵 Window Revenue: ${self.window["total_revenue"]:,.2f}')
        print(f'║  📈 Revenue Rate: ${revenue_rate:,.2f}/hour')
        print(f'║  💰 All-time Revenue: ${self.total_revenue_all_time:,.2f}')
        print(f'║  💳 Avg Transaction: ${self.window["avg_transaction_value"]:,.2f}')
        print(f'╠──────────────────────────────────────────────────────────╣')
        
        # Transaction status breakdown
        total = self.window['transaction_count']
        success_pct = (self.window['successful_count'] / total * 100) if total > 0 else 0
        failed_pct = (self.window['failed_count'] / total * 100) if total > 0 else 0
        
        print(f'║  ✅ Success: {self.window["successful_count"]} ({success_pct:.1f}%)')
        print(f'║  ❌ Failed: {self.window["failed_count"]} ({failed_pct:.1f}%)')
        print(f'║  ⏳ Pending: {self.window["pending_count"]}')
        print(f'╠──────────────────────────────────────────────────────────╣')
        
        # Payment method breakdown
        if self.window['by_payment_method']:
            print(f'║  💳 Payment Methods:')
            for method, stats in sorted(
                self.window['by_payment_method'].items(),
                key=lambda x: x[1]['amount'],
                reverse=True
            )[:3]:
                pct = (stats['amount'] / self.window['total_revenue'] * 100) if self.window['total_revenue'] > 0 else 0
                print(f'║    • {method}: ${stats["amount"]:,.2f} ({pct:.1f}%) - {stats["count"]} txns')
        
        print(f'╠──────────────────────────────────────────────────────────╣')
        
        # Plan breakdown
        if self.window['by_plan']:
            print(f'║  📦 Plans:')
            for plan, stats in sorted(
                self.window['by_plan'].items(),
                key=lambda x: x[1]['amount'],
                reverse=True
            )[:3]:
                if plan != 'unknown':
                    pct = (stats['amount'] / self.window['total_revenue'] * 100) if self.window['total_revenue'] > 0 else 0
                    print(f'║    • {plan}: ${stats["amount"]:,.2f} ({pct:.1f}%)')
        
        # Largest transaction
        if self.window['largest_transaction']['amount'] > 0:
            lt = self.window['largest_transaction']
            print(f'╠──────────────────────────────────────────────────────────╣')
            print(f'║  🏆 Largest Transaction: ${lt["amount"]:,.2f}')
            print(f'║     Order: {lt["order_id"]} | User: {lt["user_id"][:8]}...')
        
        # Revenue by minute (last 5 minutes)
        recent_minutes = sorted(self.window['revenue_by_minute'].items())[-5:]
        if recent_minutes:
            print(f'╠──────────────────────────────────────────────────────────╣')
            print(f'║  📊 Revenue by Minute:')
            for minute, rev in recent_minutes:
                time_only = minute.split(' ')[1] if ' ' in minute else minute
                print(f'║    • {time_only}: ${rev:,.2f}')
        
        print(f'╚══════════════════════════════════════════════════════════╝')
        
        # Reset window but keep running totals
        self.window = {
            'revenue_by_minute': defaultdict(float),
            'transaction_count': 0,
            'failed_count': 0,
            'successful_count': 0,
            'pending_count': 0,
            'by_payment_method': defaultdict(lambda: {'count': 0, 'amount': 0.0}),
            'by_currency': defaultdict(lambda: {'count': 0, 'amount': 0.0}),
            'by_plan': defaultdict(lambda: {'count': 0, 'amount': 0.0}),
            'by_transaction_type': defaultdict(lambda: {'count': 0, 'amount': 0.0}),
            'largest_transaction': self.window['largest_transaction'],  # Keep largest across windows
            'avg_transaction_value': 0.0,
            'total_revenue': 0.0,
        }
        self.window_start = time.time()
        self.current_minute = datetime.now().strftime('%Y-%m-%d %H:%M')
    
    def check_lag(self):
        """Check consumer lag."""
        try:
            lags = []
            partitions = self.consumer.assignment()
            for tp in partitions:
                committed = self.consumer.committed([tp])[0]
                watermark = self.consumer.get_watermark_offsets(tp)
                if committed.offset >= 0:
                    lag = watermark[1] - committed.offset
                    lags.append(lag)
            return sum(lags) if lags else 0
        except Exception as e:
            logger.debug(f"Error checking lag: {e}")
            return 0
    
    def run(self):
        """Main consumer loop."""
        logger.info(f'🚀 Revenue Consumer [{self.name}] started')
        logger.info(f'   Group: streampulse-revenue-v1')
        logger.info(f'   Window: {self.window_size}s')
        logger.info(f'   Topic: {TOPICS["transactions"]}')
        
        try:
            while self.running:
                msg = self.consumer.poll(timeout=1.0)
                
                if msg is None:
                    # Check if window should emit
                    if time.time() - self.window_start >= self.window_size:
                        if self.window['transaction_count'] > 0:
                            self.emit_report()
                    
                    # Check lag occasionally
                    if int(time.time()) % 30 == 0:
                        lag = self.check_lag()
                        if lag > 100:
                            logger.warning(f"⚠️ Revenue consumer lag: {lag} messages")
                    
                    continue
                
                if msg.error():
                    logger.error(f'Consumer error: {msg.error()}')
                    continue
                
                try:
                    # Parse event
                    event = json.loads(msg.value().decode('utf-8'))
                    
                    # Validate it's a transaction event
                    if event.get('event_type') != 'transaction':
                        logger.warning(f"Non-transaction event in transactions topic: {event.get('event_type')}")
                    
                    self.process(event)
                    self.batch_count += 1
                    
                except json.JSONDecodeError as e:
                    self.errors += 1
                    logger.error(f"JSON decode error in revenue consumer: {e}")
                except Exception as e:
                    self.errors += 1
                    logger.error(f"Processing error in revenue consumer: {e}")
                
                # Commit every 200 events or 10 seconds
                if self.batch_count >= 200 or (time.time() - self.last_commit) >= 10:
                    self.consumer.commit(asynchronous=False)
                    self.batch_count = 0
                    self.last_commit = time.time()
                
                # Emit window if needed
                if time.time() - self.window_start >= self.window_size:
                    if self.window['transaction_count'] > 0:
                        self.emit_report()
                    
        except KeyboardInterrupt:
            logger.info("Shutting down revenue consumer...")
        finally:
            self.shutdown()
    
    def shutdown(self):
        """Graceful shutdown."""
        # Emit final report
        if self.window['transaction_count'] > 0:
            self.emit_report()
        
        # Final stats
        elapsed = time.time() - self.start_time
        rate = self.processed / elapsed if elapsed > 0 else 0
        logger.info(f'\n📊 Revenue Consumer Final Stats:')
        logger.info(f'   Processed: {self.processed:,}')
        logger.info(f'   Errors: {self.errors:,}')
        logger.info(f'   Runtime: {elapsed:.1f}s')
        logger.info(f'   Avg rate: {rate:.1f}/s')
        logger.info(f'   Total Revenue: ${self.total_revenue_all_time:,.2f}')
        
        # Commit and close
        try:
            self.consumer.commit(asynchronous=False)
        except:
            pass
        self.consumer.close()
Part 7: Enhanced Pipeline Orchestrator
python
# run_pipeline.py
"""
StreamPulse Pipeline Orchestrator
Runs producer and all consumers in separate threads with monitoring.
"""
import threading
import time
import signal
import sys
import logging
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor

from producer import EventProducer
from consumers.analytics import AnalyticsConsumer
from consumers.engagement import EngagementConsumer
from consumers.revenue import RevenueConsumer

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(f'pipeline_{datetime.now().strftime("%Y%m%d_%H%M%S")}.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Global shutdown flag
shutdown = threading.Event()

class PipelineMetrics:
    """Track pipeline-wide metrics."""
    def __init__(self):
        self.start_time = time.time()
        self.component_status = {}
        self.lock = threading.Lock()
    
    def update_status(self, component, status, metrics=None):
        with self.lock:
            self.component_status[component] = {
                'status': status,
                'last_update': time.time(),
                'metrics': metrics or {}
            }
    
    def print_summary(self):
        """Print pipeline summary."""
        elapsed = time.time() - self.start_time
        print(f'\n{"="*60}')
        print(f'📊 PIPELINE STATUS - {datetime.now().strftime("%H:%M:%S")}')
        print(f'{"="*60}')
        print(f'Runtime: {elapsed:.1f}s')
        
        for component, status in self.component_status.items():
            status_icon = "✅" if status['status'] == 'running' else "❌"
            print(f'\n{status_icon} {component.upper()}:')
            if status['metrics']:
                for key, value in status['metrics'].items():
                    if key not in ['errors', 'processed']:
                        continue
                    print(f'  • {key}: {value}')

pipeline_metrics = PipelineMetrics()

def run_producer():
    """Run the event producer."""
    try:
        producer = EventProducer(name="main")
        pipeline_metrics.update_status('producer', 'starting')
        
        # Run for 2 minutes
        metrics = producer.run(events_per_second=50, duration_seconds=120)
        
        pipeline_metrics.update_status('producer', 'completed', {
            'sent': metrics['total_sent'],
            'failed': metrics['total_failed']
        })
        logger.info(f'✅ Producer completed: {metrics["total_sent"]} events sent')
        
    except Exception as e:
        logger.error(f"❌ Producer failed: {e}")
        pipeline_metrics.update_status('producer', 'failed', {'error': str(e)})

def run_analytics():
    """Run the analytics consumer."""
    try:
        consumer = AnalyticsConsumer(name="analytics")
        pipeline_metrics.update_status('analytics', 'running')
        consumer.run()
    except Exception as e:
        logger.error(f"❌ Analytics consumer failed: {e}")
        pipeline_metrics.update_status('analytics', 'failed', {'error': str(e)})

def run_engagement():
    """Run the engagement consumer."""
    try:
        consumer = EngagementConsumer(name="engagement")
        pipeline_metrics.update_status('engagement', 'running')
        consumer.run()
    except Exception as e:
        logger.error(f"❌ Engagement consumer failed: {e}")
        pipeline_metrics.update_status('engagement', 'failed', {'error': str(e)})

def run_revenue():
    """Run the revenue consumer."""
    try:
        consumer = RevenueConsumer(name="revenue")
        pipeline_metrics.update_status('revenue', 'running')
        consumer.run()
    except Exception as e:
        logger.error(f"❌ Revenue consumer failed: {e}")
        pipeline_metrics.update_status('revenue', 'failed', {'error': str(e)})

def monitor_pipeline():
    """Monitor pipeline health and print status periodically."""
    while not shutdown.is_set():
        time.sleep(30)
        if not shutdown.is_set():
            pipeline_metrics.print_summary()

def signal_handler(sig, frame):
    """Handle shutdown signals gracefully."""
    logger.info("\n🛑 Shutdown signal received, stopping pipeline...")
    shutdown.set()

def main():
    """Main orchestration function."""
    print('\n' + '='*60)
    print('🎬 STREAMPULSE PIPELINE ORCHESTRATOR')
    print('='*60)
    print('\nStarting components:')
    print('  • Producer (50 events/sec, 85% interactions, 15% transactions)')
    print('  • Analytics Consumer (event counts, top content)')
    print('  • Engagement Consumer (active users, engagement scores)')
    print('  • Revenue Consumer (revenue tracking, payment methods)')
    print('\nPress Ctrl+C to stop gracefully\n')

    # Register signal handler
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    # Create threads
    threads = [
        threading.Thread(target=run_producer, name='producer'),
        threading.Thread(target=run_analytics, name='analytics'),
        threading.Thread(target=run_engagement, name='engagement'),
        threading.Thread(target=run_revenue, name='revenue'),
        threading.Thread(target=monitor_pipeline, name='monitor', daemon=True),
    ]

    # Start all threads
    for t in threads:
        t.start()
        logger.info(f'  ✅ Started: {t.name}')
        time.sleep(1)  # Stagger startup to avoid race conditions

    logger.info('\n🚀 All components started. Pipeline running...\n')

    try:
        # Wait for producer to complete (it has a fixed duration)
        threads[0].join()  # producer thread
        
        # After producer completes, let consumers run a bit longer
        logger.info('\n⏱️ Producer completed. Letting consumers finish processing...')
        time.sleep(10)
        
    except KeyboardInterrupt:
        logger.info("\n🛑 Interrupted by user")
    finally:
        # Signal shutdown
        shutdown.set()
        
        # Wait for all threads to finish
        logger.info("Shutting down components...")
        for t in threads[1:4]:  # Skip monitor thread
            t.join(timeout=10)
            if t.is_alive():
                logger.warning(f"  ⚠️ {t.name} did not shut down gracefully")
        
        # Print final summary
        pipeline_metrics.print_summary()
        logger.info('\n✅ Pipeline stopped successfully')

if __name__ == '__main__':
    main()
Part 8: Verification Scripts
python
# verify_pipeline.py
"""
Verification script for StreamPulse pipeline.
Checks consumer lag, topic health, and data flow.
"""
import subprocess
import json
from confluent_kafka import Consumer, TopicPartition
from config import KAFKA_BOOTSTRAP, TOPICS

def check_consumer_groups():
    """Check all consumer groups and their lag."""
    groups = [
        'streampulse-analytics-v1',
        'streampulse-engagement-v1',
        'streampulse-revenue-v1'
    ]
    
    print('\n🔍 Checking Consumer Groups:')
    print('='*60)
    
    for group in groups:
        print(f'\n📋 Group: {group}')
        print('-'*40)
        
        try:
            # Use Kafka command line tool
            cmd = [
                'kafka-consumer-groups', 
                '--bootstrap-server', KAFKA_BOOTSTRAP,
                '--describe',
                '--group', group
            ]
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')
                if len(lines) > 1:
                    for line in lines[1:]:  # Skip header
                        if line.strip():
                            parts = line.split()
                            if len(parts) >= 6:
                                topic = parts[1]
                                partition = parts[2]
                                current = parts[3]
                                end = parts[4]
                                lag = parts[5]
                                print(f"  • {topic}-{partition}: "
                                      f"offset {current}/{end} (lag: {lag})")
                else:
                    print("  No active consumers")
            else:
                print(f"  Error: {result.stderr}")
                
        except Exception as e:
            print(f"  Error checking group: {e}")

def check_topic_health():
    """Check topic health and message counts."""
    print('\n📊 Topic Health:')
    print('='*60)
    
    for topic_name, topic in TOPICS.items():
        print(f'\n📌 Topic: {topic}')
        print('-'*40)
        
        try:
            # Create consumer to get watermarks
            consumer = Consumer({
                'bootstrap.servers': KAFKA_BOOTSTRAP,
                'group.id': 'verification-consumer',
                'session.timeout.ms': 6000
            })
            
            metadata = consumer.list_topics(topic)
            total_messages = 0
            
            if topic in metadata.topics:
                partitions = metadata.topics[topic].partitions
                print(f"  Partitions: {len(partitions)}")
                
                for partition_id in partitions:
                    tp = TopicPartition(topic, partition_id)
                    low, high = consumer.get_watermark_offsets(tp)
                    messages = high - low
                    total_messages += messages
                    print(f"  • Partition {partition_id}: {messages} messages "
                          f"(offset {low} to {high})")
            
            print(f"\n  📈 Total messages: {total_messages}")
            consumer.close()
            
        except Exception as e:
            print(f"  Error checking topic: {e}")

def check_dead_letter_topic():
    """Check dead letter topic for malformed events."""
    print('\n💀 Dead Letter Topic Check:')
    print('='*60)
    
    try:
        consumer = Consumer({
            'bootstrap.servers': KAFKA_BOOTSTRAP,
            'group.id': 'dead-letter-checker',
            'auto.offset.reset': 'earliest',
            'enable.auto.commit': False
        })
        
        consumer.subscribe([TOPICS['dead_letter']])
        
        # Poll for messages (non-blocking)
        msgs = []
        for _ in range(10):  # Try up to 10 messages
            msg = consumer.poll(timeout=1.0)
            if msg and not msg.error():
                try:
                    event = json.loads(msg.value().decode('utf-8'))
                    msgs.append({
                        'offset': msg.offset(),
                        'error': event.get('error', 'unknown'),
                        'topic': event.get('original_topic', 'unknown')
                    })
                except:
                    msgs.append({'offset': msg.offset(), 'error': 'parse error'})
        
        if msgs:
            print(f"  Found {len(msgs)} messages in dead letter:")
            for msg in msgs:
                print(f"  • Offset {msg['offset']}: {msg['error']}")
        else:
            print("  ✅ No messages in dead letter topic")
        
        consumer.close()
        
    except Exception as e:
        print(f"  Error checking dead letter: {e}")

def verify_pipeline():
    """Run all verification checks."""
    print('\n' + '='*60)
    print('🔧 STREAMPULSE PIPELINE VERIFICATION')
    print('='*60)
    
    # Check consumer groups
    check_consumer_groups()
    
    # Check topic health
    check_topic_health()
    
    # Check dead letter
    check_dead_letter_topic()
    
    print('\n✅ Verification complete!')

if __name__ == '__main__':
    verify_pipeline()
Complete Requirements File
txt
# requirements.txt
confluent-kafka==2.3.0
python-dotenv==1.0.0
pandas==2.0.3
numpy==1.24.3
matplotlib==3.7.2
tabulate==0.9.0
colorama==0.4.6
README with Instructions
markdown
# StreamPulse Kafka Pipeline

## Complete Multi-Consumer Streaming Pipeline

### Prerequisites
- Docker and Docker Compose
- Python 3.8+
- Kafka tools (optional, for monitoring)

### Quick Start

1. **Start Kafka Cluster**
```bash
docker-compose -f docker-compose.kafka.yml up -d
Create Topics

bash
python setup_topics.py
Install Dependencies

bash
pip install -r requirements.txt
Run the Pipeline

bash
python run_pipeline.py
Verify Pipeline

bash
python verify_pipeline.py


=====================================================================================================================================
| Component      | Group ID                    | Topic(s)                  | Window | Purpose                                  |
|----------------|-----------------------------|---------------------------|--------|------------------------------------------|
| Producer       | N/A                         | All topics                | N/A    | Generates 50 events/sec (85% interactions,|
|                |                             |                           |        | 15% transactions). Includes 0.5% malformed|
|                |                             |                           |        | events for dead letter testing.          |
|----------------|-----------------------------|---------------------------|--------|------------------------------------------|
| Analytics      | streampulse-analytics-v1    | streaming.user.interactions| 10s   | Real-time event counting:                 |
| Consumer       |                             |                           |        | • Event counts per window                 |
|                |                             |                           |        | • Top 5 actions (play, pause, etc.)       |
|                |                             |                           |        | • Top 3 content items                      |
|                |                             |                           |        | • Device type distribution                 |
|                |                             |                           |        | • Country breakdown                         |
|----------------|-----------------------------|---------------------------|--------|------------------------------------------|
| Engagement    | streampulse-engagement-v1   | streaming.user.interactions| 30s   | User activity tracking:                    |
| Consumer      |                             |                           |        | • Active users (unique per window)         |
|               |                             |                           |        | • Engagement scores (point system)         |
|               |                             |                           |        |   - play: +1, pause: +0.5, complete: +2    |
|               |                             |                           |        |   - skip: -0.5, like: +3, share: +5        |
|               |                             |                           |        | • Churn risk detection (users with only     |
|               |                             |                           |        |   negative actions in last 5 events)        |
|               |                             |                           |        | • Session tracking (duration, completion)   |
|               |                             |                           |        | • High-value user identification (>10 pts)  |
|----------------|-----------------------------|---------------------------|--------|------------------------------------------|
| Revenue       | streampulse-revenue-v1      | payments.transaction.events| 60s   | Financial tracking:                         |
| Consumer      |                             |                           |        | • Revenue per minute                         |
|               |                             |                           |        | • Transaction success/failure rates          |
|               |                             |                           |        | • Average transaction value                   |
|               |                             |                           |        | • Payment method breakdown                    |
|               |                             |                           |        |   (credit_card, paypal, apple_pay, etc.)      |
|               |                             |                           |        | • Currency distribution                         |
|               |                             |                           |        | • Plan analysis (free, basic, standard, premium)|
|               |                             |                           |        | • Largest transaction tracking                   |
|               |                             |                           |        | • Revenue rate per hour                            |
|----------------|-----------------------------|---------------------------|--------|------------------------------------------|
| Dead Letter   | N/A (Producer)              | streaming.user.dead-letter| N/A    | Captures failed/malformed events:              |
| Producer      |                             |                           |        | • JSON decode errors                            |
|               |                             |                           |        | • Missing required fields                        |
|               |                             |                           |        | • Processing exceptions                           |
|               |                             |                           |        | • Original message metadata stored                |
|----------------|-----------------------------|---------------------------|--------|------------------------------------------|
| Orchestrator  | N/A                         | N/A                       | N/A    | Manages pipeline lifecycle:                      |
| (run_pipeline)|                             |                           |        | • Starts all components in threads               |
|               |                             |                           |        | • Staggered startup (1s delay)                    |
|               |                             |                           |        | • Graceful shutdown handling                       |
|               |                             |                           |        | • Pipeline monitoring (30s intervals)              |
|               |                             |                           |        | • Component status tracking                          |
=====================================================================================================================================

=====================================================================================================================================
| Topic Name                    | Partitions | Retention | Replication | Purpose                                        |
|-------------------------------|------------|-----------|-------------|------------------------------------------------|
| streaming.user.interactions   | 6          | 30 days   | 1           | User interaction events (play, pause, like,    |
|                               |            |           |             | share, skip, complete). Keyed by user_id for   |
|                               |            |           |             | partition affinity.                             |
|-------------------------------|------------|-----------|-------------|------------------------------------------------|
| streaming.user.page-views     | 3          | 7 days    | 1           | Page navigation events (home, show_details,    |
|                               |            |           |             | search, profile, settings). Lower retention    |
|                               |            |           |             | for less critical data.                          |
|-------------------------------|------------|-----------|-------------|------------------------------------------------|
| payments.transaction.events   | 3          | 90 days   | 1           | Payment transaction events. Longer retention   |
|                               |            |           |             | for financial auditing. Keyed by order_id.      |
|-------------------------------|------------|-----------|-------------|------------------------------------------------|
| streaming.user.dead-letter    | 1          | 30 days   | 1           | Failed/unprocessable events with original      |
|                               |            |           |             | metadata for debugging and replay.              |
=====================================================================================================================================

=====================================================================================================================================
| Consumer Group ID                | Subscribed Topics               | Offset Reset | Auto Commit | Purpose                          |
|----------------------------------|---------------------------------|--------------|-------------|----------------------------------|
| streampulse-analytics-v1         | streaming.user.interactions     | earliest     | False       | Analytics team - event counting  |
| streampulse-engagement-v1        | streaming.user.interactions     | earliest     | False       | Product team - user engagement   |
| streampulse-revenue-v1           | payments.transaction.events     | earliest     | False       | Finance team - revenue tracking  |
=====================================================================================================================================

=====================================================================================================================================
| Component Configuration                     | Value                    | Description                               |
|---------------------------------------------|--------------------------|-------------------------------------------|
| Producer events per second                   | 50                       | Target event generation rate              |
| Producer duration (seconds)                   | 120                      | How long producer runs                     |
| Producer interaction ratio                    | 85%                      | Percentage of interaction events           |
| Producer transaction ratio                    | 15%                      | Percentage of transaction events           |
| Producer malformed event rate                 | 0.5%                     | Rate of error injection for testing        |
|---------------------------------------------|--------------------------|-------------------------------------------|
| Analytics window size                         | 10 seconds               | Reporting interval for analytics          |
| Engagement window size                        | 30 seconds               | Reporting interval for engagement         |
| Revenue window size                           | 60 seconds               | Reporting interval for revenue            |
|---------------------------------------------|--------------------------|-------------------------------------------|
| Consumer batch commit                         | 200-500 events           | Events processed before offset commit     |
| Consumer time-based commit                    | 10 seconds               | Max time before forced commit             |
| Consumer poll timeout                         | 1.0 second               | Time to wait for messages                 |
=====================================================================================================================================

=====================================================================================================================================
| Engagement Score Weights    | Value | Description                               |
|-----------------------------|-------|-------------------------------------------|
| play                        | +1    | Starting content - basic engagement       |
| pause                       | +0.5  | User actively controlling playback        |
| complete                    | +2    | Finished content - high engagement        |
| skip                        | -0.5  | Negative signal - user disengaged         |
| like                        | +3    | Strong positive feedback                   |
| share                       | +5    | Viral engagement - highest value           |
| add_to_list                 | +2    | User saving for later                      |
|-----------------------------|-------|-------------------------------------------|
| High-value threshold        | >10   | Users with score above this are "high value"|
| Churn risk pattern          | 5     | Users with 5+ consecutive negative actions |
=====================================================================================================================================

=====================================================================================================================================
| Revenue Metrics Tracked                 | Description                                  |
|-----------------------------------------|----------------------------------------------|
| Revenue per minute                       | Sum of successful transaction amounts        |
| Revenue rate per hour                     | Annualized revenue rate                        |
| Average transaction value                 | Mean transaction amount                        |
| Transaction success rate                   | % of successful transactions                    |
| Failed transaction count                    | Number of failed payments                        |
| Payment method distribution                 | Breakdown by credit_card, paypal, apple_pay     |
| Plan distribution                           | Revenue by plan type (free, basic, etc.)        |
| Currency distribution                       | Revenue by currency (USD, EUR, GBP, etc.)       |
| Largest transaction                         | Maximum single transaction amount                |
| Transaction type breakdown                  | Renewal, upgrade, downgrade, refund             |
=====================================================================================================================================

=====================================================================================================================================
| Pipeline Monitoring Metrics    | Interval | Description                               |
|--------------------------------|----------|-------------------------------------------|
| Component status check          | 30 sec   | Verify all components are running         |
| Consumer lag check               | 30 sec   | Monitor backlog in each consumer group    |
| Dead letter check                | Manual   | Verify malformed events are captured      |
| Topic size monitoring            | Manual   | Check message counts per partition        |
| Processing rate tracking         | Per window| Events/second per consumer                |
| Error rate monitoring            | Per window| Failed events / total events               |
=====================================================================================================================================

=====================================================================================================================================
| Shutdown Behavior                          | Description                               |
|---------------------------------------------|-------------------------------------------|
| Producer                                     | Completes its duration then stops          |
| Consumers                                    | Receive shutdown signal, emit final report,|
|                                             | commit offsets, close gracefully           |
| Orchestrator                                 | Waits for threads (10s timeout), prints   |
|                                             | final summary, exits                       |
| Signal handling                              | SIGINT and SIGTERM trigger graceful shutdown|
=====================================================================================================================================

=====================================================================================================================================
| Testing Scenarios                          | Expected Behavior                          |
|---------------------------------------------|-------------------------------------------|
| Normal operation                             | All consumers show zero lag, dead letter   |
|                                             | topic empty, metrics updating regularly    |
|---------------------------------------------|-------------------------------------------|
| Consumer restart                             | Resumes from last committed offset, no     |
|                                             | data loss or duplication                    |
|---------------------------------------------|-------------------------------------------|
| Malformed events                             | Captured in dead letter topic with full    |
|                                             | metadata, consumers continue processing    |
|---------------------------------------------|-------------------------------------------|
| High load (increase events/sec)               | Consumers may show lag, can scale by       |
|                                             | adding partitions and consumer instances   |
|---------------------------------------------|-------------------------------------------|
| Consumer failure                             | Group rebalancing, remaining consumers     |
|                                             | take over partitions                        |
=====================================================================================================================================


Monitoring Commands
bash
# Check all consumer groups
kafka-consumer-groups --bootstrap-server localhost:9092 --list

# Check specific group lag
kafka-consumer-groups --bootstrap-server localhost:9092 \
  --describe --group streampulse-analytics-v1

# Consume from dead letter topic
kafka-console-consumer --bootstrap-server localhost:9092 \
  --topic streaming.user.dead-letter --from-beginning

# Get topic details
kafka-topics --bootstrap-server localhost:9092 --describe