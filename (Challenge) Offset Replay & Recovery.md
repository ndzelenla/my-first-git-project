(Challenge) Offset Replay & Recovery
Author: Sammy Ndzelen
Date: 10.03.2026

Build a replay tool that can re-read events from any point for reprocessing.


Task: Write the Replay Tool

# replay_tool.py
"""
StreamPulse Event Replay Tool
Re-read events from a specific time, offset, or from the beginning.
"""
from confluent_kafka import Consumer, TopicPartition, OFFSET_BEGINNING, OFFSET_END
import json
import time
import argparse
from datetime import datetime, timedelta
 
class ReplayTool:
    def __init__(self, bootstrap_servers, group_id):
        self.config = {
            'bootstrap.servers': bootstrap_servers,
            'group.id': group_id,
            'auto.offset.reset': 'earliest',
            'enable.auto.commit': False,
        }
 
    def replay_from_beginning(self, topic, limit=None):
        """Replay all events from the beginning of a topic."""
        consumer = Consumer(self.config)
 
        def seek_beginning(c, partitions):
            for p in partitions:
                p.offset = OFFSET_BEGINNING
            c.assign(partitions)
 
        consumer.subscribe([topic], on_assign=seek_beginning)
 
        count = 0
        events = []
 
        try:
            while True:
                msg = consumer.poll(1.0)
                if msg is None:
                    if count > 0:
                        break  # No more events
                    continue
                if msg.error():
                    continue
 
                event = json.loads(msg.value().decode('utf-8'))
                events.append({
                    'partition': msg.partition(),
                    'offset': msg.offset(),
                    'key': msg.key().decode('utf-8') if msg.key() else None,
                    'event': event,
                })
                count += 1
 
                if limit and count >= limit:
                    break
        finally:
            consumer.close()
 
        return events
 
    def replay_from_timestamp(self, topic, hours_ago, limit=None):
        """Replay events from a specific time (hours ago)."""
        consumer = Consumer(self.config)
        consumer.subscribe([topic])
 
        # Wait for partition assignment
        consumer.poll(5.0)
        assignment = consumer.assignment()
 
        if not assignment:
            print('No partitions assigned')
            consumer.close()
            return []
 
        # Seek to timestamp
        target_ms = int((time.time() - hours_ago * 3600) * 1000)
        tps = [TopicPartition(tp.topic, tp.partition, target_ms)
               for tp in assignment]
 
        offsets = consumer.offsets_for_times(tps)
        for tp in offsets:
            if tp.offset >= 0:
                consumer.seek(tp)
                print(f'  Partition {tp.partition}: '
                      f'seeking to offset {tp.offset}')
 
        # Read events
        count = 0
        events = []
 
        try:
            while True:
                msg = consumer.poll(1.0)
                if msg is None:
                    if count > 0:
                        break
                    continue
                if msg.error():
                    continue
 
                event = json.loads(msg.value().decode('utf-8'))
                events.append({
                    'partition': msg.partition(),
                    'offset': msg.offset(),
                    'event': event,
                })
                count += 1
 
                if limit and count >= limit:
                    break
        finally:
            consumer.close()
 
        return events
 
    def replay_from_offset(self, topic, partition, offset, limit=100):
        """Replay from a specific partition and offset."""
        consumer = Consumer(self.config)
        consumer.assign([TopicPartition(topic, partition, offset)])
 
        events = []
        count = 0
 
        try:
            while count < limit:
                msg = consumer.poll(1.0)
                if msg is None:
                    break
                if msg.error():
                    continue
 
                event = json.loads(msg.value().decode('utf-8'))
                events.append({
                    'partition': msg.partition(),
                    'offset': msg.offset(),
                    'event': event,
                })
                count += 1
        finally:
            consumer.close()
 
        return events
 
# ============================================
# CLI Interface
# ============================================
def main():
    parser = argparse.ArgumentParser(description='StreamPulse Event Replay')
    parser.add_argument('--topic', required=True)
    parser.add_argument('--mode', choices=['beginning', 'time', 'offset'],
                       required=True)
    parser.add_argument('--hours-ago', type=float, default=1)
    parser.add_argument('--partition', type=int, default=0)
    parser.add_argument('--offset', type=int, default=0)
    parser.add_argument('--limit', type=int, default=100)
    parser.add_argument('--output', default=None,
                       help='Output file for replay data')
 
    args = parser.parse_args()
 
    tool = ReplayTool(
        'localhost:9092',
        f'replay-tool-{int(time.time())}'
    )
 
    print(f'Replay mode: {args.mode}')
 
    if args.mode == 'beginning':
        events = tool.replay_from_beginning(args.topic, args.limit)
    elif args.mode == 'time':
        events = tool.replay_from_timestamp(
            args.topic, args.hours_ago, args.limit)
    elif args.mode == 'offset':
        events = tool.replay_from_offset(
            args.topic, args.partition, args.offset, args.limit)
 
    print(f'\nReplayed {len(events)} events')
 
    # Print first 5
    for e in events[:5]:
        print(f"  P{e['partition']} offset={e['offset']}: "
              f"{json.dumps(e['event'])[:80]}...")
 
    # Save to file if requested
    if args.output:
        with open(args.output, 'w') as f:
            json.dump(events, f, indent=2)
        print(f'Saved to {args.output}')
 
if __name__ == '__main__':
    main()



Test the replay tool:

# Replay from beginning (first 50 events)
python replay_tool.py --topic streaming.user.interactions \
  --mode beginning --limit 50
 
# Replay from 1 hour ago
python replay_tool.py --topic streaming.user.interactions \
  --mode time --hours-ago 1 --limit 100
 
# Replay from specific offset
python replay_tool.py --topic streaming.user.interactions \
  --mode offset --partition 0 --offset 500 --limit 20
 
# Save replay to file
python replay_tool.py --topic streaming.user.interactions \
  --mode time --hours-ago 0.5 --limit 1000 \
  --output replay_output.json




Part 2: Offset Reset Tool (Estimated: 15 minutes)
Build a tool for resetting consumer offsets during incident recovery.

Task: Write the Offset Reset Tool
# offset_reset_tool.py
"""
StreamPulse Offset Reset Tool
Reset consumer group offsets for incident recovery.
"""
from confluent_kafka import Consumer, TopicPartition
from confluent_kafka.admin import AdminClient
import argparse
import time
 
class OffsetResetTool:
    def __init__(self, bootstrap_servers):
        self.bootstrap = bootstrap_servers
        self.admin = AdminClient({'bootstrap.servers': bootstrap_servers})
 
    def get_current_offsets(self, group_id, topic, num_partitions):
        """Get current committed offsets for a consumer group."""
        consumer = Consumer({
            'bootstrap.servers': self.bootstrap,
            'group.id': f'{group_id}-inspector',
            'enable.auto.commit': False,
        })
 
        tps = [TopicPartition(topic, p) for p in range(num_partitions)]
        committed = consumer.committed(tps, timeout=10)
 
        result = {}
        for tp in committed:
            lo, hi = consumer.get_watermark_offsets(tp, timeout=10)
            result[tp.partition] = {
                'committed': tp.offset if tp.offset >= 0 else 'none',
                'earliest': lo,
                'latest': hi,
                'lag': hi - tp.offset if tp.offset >= 0 else hi - lo,
            }
 
        consumer.close()
        return result
 
    def reset_to_earliest(self, group_id, topic, num_partitions):
        """Reset all offsets to the beginning."""
        # Implement: use admin API or consumer.seek + commit
        consumer = Consumer({
            'bootstrap.servers': self.bootstrap,
            'group.id': group_id,
            'enable.auto.commit': False,
        })
 
        tps = [TopicPartition(topic, p) for p in range(num_partitions)]
        consumer.assign(tps)
 
        for tp in tps:
            lo, hi = consumer.get_watermark_offsets(tp, timeout=10)
            tp.offset = lo
 
        consumer.commit(offsets=tps, asynchronous=False)
        consumer.close()
        print(f'✅ Reset {group_id} to earliest for all {num_partitions} partitions')
 
    def reset_to_latest(self, group_id, topic, num_partitions):
        """Reset all offsets to the end (skip all existing events)."""
        consumer = Consumer({
            'bootstrap.servers': self.bootstrap,
            'group.id': group_id,
            'enable.auto.commit': False,
        })
 
        tps = [TopicPartition(topic, p) for p in range(num_partitions)]
        consumer.assign(tps)
 
        for tp in tps:
            lo, hi = consumer.get_watermark_offsets(tp, timeout=10)
            tp.offset = hi
 
        consumer.commit(offsets=tps, asynchronous=False)
        consumer.close()
        print(f'✅ Reset {group_id} to latest for all {num_partitions} partitions')
 
    def reset_to_timestamp(self, group_id, topic, num_partitions, hours_ago):
        """Reset offsets to a specific timestamp."""
        consumer = Consumer({
            'bootstrap.servers': self.bootstrap,
            'group.id': group_id,
            'enable.auto.commit': False,
        })
 
        target_ms = int((time.time() - hours_ago * 3600) * 1000)
        tps = [TopicPartition(topic, p, target_ms)
               for p in range(num_partitions)]
 
        offsets = consumer.offsets_for_times(tps, timeout=10)
        consumer.assign([TopicPartition(tp.topic, tp.partition)
                        for tp in offsets])
        consumer.commit(offsets=offsets, asynchronous=False)
        consumer.close()
 
        for tp in offsets:
            print(f'  P{tp.partition}: reset to offset {tp.offset}')
        print(f'✅ Reset {group_id} to {hours_ago}h ago')
 
# CLI
def main():
    parser = argparse.ArgumentParser(description='Offset Reset Tool')
    parser.add_argument('--group', required=True)
    parser.add_argument('--topic', required=True)
    parser.add_argument('--partitions', type=int, default=6)
    parser.add_argument('--action',
                       choices=['status', 'earliest', 'latest', 'timestamp'],
                       required=True)
    parser.add_argument('--hours-ago', type=float, default=1)
 
    args = parser.parse_args()
    tool = OffsetResetTool('localhost:9092')
 
    if args.action == 'status':
        offsets = tool.get_current_offsets(
            args.group, args.topic, args.partitions)
 
        print(f'\nGroup: {args.group}')
        print(f'Topic: {args.topic}')
        print(f'{"Part":>6} {"Committed":>12} {"Earliest":>12} '
              f'{"Latest":>12} {"Lag":>8}')
        print('-' * 56)
 
        total_lag = 0
        for p in sorted(offsets.keys()):
            o = offsets[p]
            total_lag += o['lag']
            print(f"{p:>6} {str(o['committed']):>12} {o['earliest']:>12} "
                  f"{o['latest']:>12} {o['lag']:>8}")
        print(f'{"TOTAL":>6} {"":>12} {"":>12} {"":>12} {total_lag:>8}')
 
    elif args.action == 'earliest':
        tool.reset_to_earliest(args.group, args.topic, args.partitions)
 
    elif args.action == 'latest':
        tool.reset_to_latest(args.group, args.topic, args.partitions)
 
    elif args.action == 'timestamp':
        tool.reset_to_timestamp(
            args.group, args.topic, args.partitions, args.hours_ago)
 
if __name__ == '__main__':
    main()


Test the offset reset tool:

# Check current status
python offset_reset_tool.py --group streampulse-analytics-v1 \
  --topic streaming.user.interactions --action status
 
# Reset to beginning (reprocess everything)
python offset_reset_tool.py --group streampulse-analytics-v1 \
  --topic streaming.user.interactions --action earliest
 
# Reset to 2 hours ago
python offset_reset_tool.py --group streampulse-analytics-v1 \
  --topic streaming.user.interactions --action timestamp --hours-ago 2
 
# Skip to latest (ignore backlog)
python offset_reset_tool.py --group streampulse-analytics-v1 \
  --topic streaming.user.interactions --action latest
Explain this code



Part 3: Duplicate-Safe Processing (Estimated: 20 minutes)
Task: Build a Consumer That Handles Duplicates

# idempotent_consumer.py
"""
Consumer with idempotent processing — safe for at-least-once delivery.
Uses a local dedup store to detect and skip duplicate events.
"""
from confluent_kafka import Consumer
import json
import time
import sqlite3
 
class IdempotentConsumer:
    def __init__(self, db_path='processed_events.db'):
        # SQLite for dedup tracking
        self.db = sqlite3.connect(db_path)
        self.db.execute('''
            CREATE TABLE IF NOT EXISTS processed (
                event_id TEXT PRIMARY KEY,
                processed_at REAL,
                partition INTEGER,
                offset_val INTEGER
            )
        ''')
        self.db.commit()
 
        self.consumer = Consumer({
            'bootstrap.servers': 'localhost:9092',
            'group.id': 'idempotent-consumer-v1',
            'auto.offset.reset': 'earliest',
            'enable.auto.commit': False,
        })
        self.consumer.subscribe(['streaming.user.interactions'])
 
        self.stats = {
            'processed': 0,
            'duplicates_skipped': 0,
            'errors': 0,
        }
 
    def is_duplicate(self, event_id):
        """Check if event was already processed."""
        cursor = self.db.execute(
            'SELECT 1 FROM processed WHERE event_id = ?',
            (event_id,)
        )
        return cursor.fetchone() is not None
 
    def mark_processed(self, event_id, partition, offset):
        """Record that event was processed."""
        self.db.execute(
            'INSERT OR IGNORE INTO processed VALUES (?, ?, ?, ?)',
            (event_id, time.time(), partition, offset)
        )
 
    def process_event(self, event, partition, offset):
        """Process a single event idempotently."""
        event_id = event.get('event_id')
        if not event_id:
            event_id = f'{partition}-{offset}'
 
        if self.is_duplicate(event_id):
            self.stats['duplicates_skipped'] += 1
            return True  # Already processed
 
        # YOUR BUSINESS LOGIC HERE
        # Example: write to database, update aggregation, etc.
 
        self.mark_processed(event_id, partition, offset)
        self.stats['processed'] += 1
        return True
 
    def run(self):
        batch_count = 0
 
        try:
            print('Idempotent Consumer running...')
 
            while True:
                msg = self.consumer.poll(1.0)
                if msg is None:
                    continue
                if msg.error():
                    continue
 
                event = json.loads(msg.value().decode('utf-8'))
                self.process_event(event, msg.partition(), msg.offset())
                batch_count += 1
 
                if batch_count >= 100:
                    self.db.commit()  # Batch DB writes
                    self.consumer.commit(asynchronous=False)
                    batch_count = 0
 
                total = self.stats['processed'] + self.stats['duplicates_skipped']
                if total % 500 == 0:
                    print(f"  Processed: {self.stats['processed']}, "
                          f"Duplicates skipped: {self.stats['duplicates_skipped']}")
 
        except KeyboardInterrupt:
            self.db.commit()
            self.consumer.commit(asynchronous=False)
 
            print(f"\nFinal stats:")
            print(f"  Processed: {self.stats['processed']}")
            print(f"  Duplicates skipped: {self.stats['duplicates_skipped']}")
            print(f"  Errors: {self.stats['errors']}")
 
        finally:
            self.consumer.close()
            self.db.close()
 
if __name__ == '__main__':
    consumer = IdempotentConsumer()
    consumer.run()



Part 4: Lag Dashboard (Estimated: 15 minutes)
Task: Build a Multi-Group Lag Dashboard

# lag_dashboard.py
"""
Multi-group consumer lag dashboard.
"""
from confluent_kafka import Consumer, TopicPartition
import time
import os
 
GROUPS = {
    'streampulse-analytics-v1': {
        'topic': 'streaming.user.interactions',
        'partitions': 6,
    },
    'streampulse-engagement-v1': {
        'topic': 'streaming.user.interactions',
        'partitions': 6,
    },
    'streampulse-revenue-v1': {
        'topic': 'payments.transaction.events',
        'partitions': 3,
    },
}
 
def check_group_lag(bootstrap, group_id, topic, num_partitions):
    """Check lag for a single consumer group."""
    consumer = Consumer({
        'bootstrap.servers': bootstrap,
        'group.id': f'{group_id}-dashboard',
        'enable.auto.commit': False,
    })
 
    tps = [TopicPartition(topic, p) for p in range(num_partitions)]
 
    try:
        committed = consumer.committed(tps, timeout=5)
    except:
        consumer.close()
        return None
 
    result = {'partitions': {}, 'total_lag': 0}
 
    for tp in committed:
        try:
            lo, hi = consumer.get_watermark_offsets(tp, timeout=5)
            offset = tp.offset if tp.offset >= 0 else lo
            lag = hi - offset
            result['partitions'][tp.partition] = {
                'committed': offset,
                'end': hi,
                'lag': lag,
            }
            result['total_lag'] += lag
        except:
            result['partitions'][tp.partition] = {
                'committed': '?', 'end': '?', 'lag': '?'
            }
 
    consumer.close()
    return result
 
def render_dashboard():
    """Render the lag dashboard."""
    os.system('clear')
 
    print(f'╔{"═"*60}╗')
    print(f'║  STREAMPULSE KAFKA LAG DASHBOARD  '
          f'{time.strftime("%H:%M:%S"):>25} ║')
    print(f'╠{"═"*60}╣')
 
    for group_id, info in GROUPS.items():
        result = check_group_lag(
            'localhost:9092',
            group_id,
            info['topic'],
            info['partitions']
        )
 
        if result is None:
            print(f'║  ❓ {group_id}: unable to fetch')
            continue
 
        lag = result['total_lag']
        status = '🟢' if lag < 100 else '🟡' if lag < 10000 else '🔴'
 
        print(f'║')
        print(f'║  {status} {group_id}')
        print(f'║     Topic: {info["topic"]}')
        print(f'║     Total lag: {lag:,}')
 
        # Per-partition bars
        for p in sorted(result['partitions'].keys()):
            pdata = result['partitions'][p]
            if isinstance(pdata['lag'], int):
                bar_len = min(int(pdata['lag'] / 100), 30)
                bar = '█' * bar_len
                print(f'║     P{p}: {pdata["lag"]:>8,} {bar}')
 
        print(f'║')
 
    print(f'╚{"═"*60}╝')
    print(f'\nRefreshing every 5 seconds... (Ctrl+C to stop)')
 
# Main loop
try:
    while True:
        render_dashboard()
        time.sleep(5)
except KeyboardInterrupt:
    print('\nDashboard stopped')
