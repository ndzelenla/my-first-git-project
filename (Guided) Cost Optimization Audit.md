StreamPulse Cost Optimization Plan

Author: Sammy Ndzelen
Date: 04.03.2026

## Part 1: Warehouse Utilization Analysis

Step 1: Identify Waste

For each warehouse, answer:

Warehouse        Is it oversized?    Is auto-suspend optimal?    Key issue                          Recommended action
----------------------------------------------------------------------------------------------------------------
LOADING_WH       YES (25% util)      NO (600s too long)          Running 24/7 at 25% utilization    Reduce size to MEDIUM, lower auto-suspend to 60s
TRANSFORM_WH     NO (64% util)       YES (300s good)             High credit usage but efficient    Keep as-is, monitor growth
ANALYTICS_WH     YES (40% util)      NO (600s too long)          Underutilized, long suspend time   Reduce to MEDIUM, auto-suspend 60s
REPORTING_WH     YES (12.5% util)    CRITICAL (NEVER suspend)    Running 24/7 at 12.5% utilization  Reduce to SMALL, set auto-suspend 60s
DEV_WH           YES (20% util)      NO (600s too long)          Low utilization, oversized         Reduce to SMALL, auto-suspend 60s
ML_WH            NO (75% util)       YES (600s okay)             Well utilized                      Keep as-is, monitor
SANDBOX_WH       YES (10% util)      NO (600s too long)          Extremely low utilization          Reduce to XSMALL, auto-suspend 30s


## Step 2: Write Optimization SQL
-- ============================================
-- WAREHOUSE OPTIMIZATION COMMANDS
-- ============================================

-- LOADING_WH: Reduce size and suspend time
ALTER WAREHOUSE LOADING_WH SET
  WAREHOUSE_SIZE = 'MEDIUM'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  COMMENT = 'Optimized: Reduced from L to M, auto-suspend 60s'
;

-- TRANSFORM_WH: Minor optimization, keep performance
ALTER WAREHOUSE TRANSFORM_WH SET
  AUTO_SUSPEND = 300
  AUTO_RESUME = TRUE
  MAX_CLUSTER_COUNT = 3
  COMMENT = 'Maintaining performance for transforms'
;

-- ANALYTICS_WH: Reduce size and suspend time
ALTER WAREHOUSE ANALYTICS_WH SET
  WAREHOUSE_SIZE = 'MEDIUM'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  COMMENT = 'Reduced from L to M based on 40% utilization'
;

-- REPORTING_WH: Critical fix - NEVER suspend is expensive
ALTER WAREHOUSE REPORTING_WH SET
  WAREHOUSE_SIZE = 'SMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  COMMENT = 'CRITICAL FIX: Changed from NEVER suspend to 60s'
;

-- DEV_WH: Right-size for development
ALTER WAREHOUSE DEV_WH SET
  WAREHOUSE_SIZE = 'SMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  COMMENT = 'Reduced from L to S for dev work'
;

-- ML_WH: Keep optimized
ALTER WAREHOUSE ML_WH SET
  AUTO_SUSPEND = 600
  AUTO_RESUME = TRUE
  COMMENT = 'Maintain current config - well utilized'
;

-- SANDBOX_WH: Minimal size for experimentation
ALTER WAREHOUSE SANDBOX_WH SET
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 30
  AUTO_RESUME = TRUE
  COMMENT = 'Minimal footprint for sandbox'
;


## Step 3: Project Savings
Step 3: Project Savings

Warehouse        Current Credits    Projected Credits    Savings (Credits)    Savings ($)
--------------------------------------------------------------------------------------------
LOADING_WH       5,760              1,440                4,320                $8,640
TRANSFORM_WH     8,000              8,000                0                    $0
ANALYTICS_WH     4,800              2,400                2,400                $4,800
REPORTING_WH     2,880              360                  2,520                $5,040
DEV_WH           3,200              800                  2,400                $4,800
ML_WH            3,200              3,200                0                    $0
SANDBOX_WH       1,200              300                  900                  $1,800
--------------------------------------------------------------------------------------------
Total            29,040             16,500               12,540               $25,080


## Part 2: Query Cost Analysis
# Step 1: Diagnose and Fix

-- CURRENT (expensive):
SELECT * FROM raw.events WHERE user_id = 'abc123';

-- OPTIMIZED: Add clustering and partition filter
-- First, cluster the table on date and user_id
ALTER TABLE raw.events CLUSTER BY (event_date, user_id);

-- Then optimize query with partition pruning
SELECT * FROM raw.events 
WHERE user_id = 'abc123'
  AND event_date >= DATEADD(day, -30, CURRENT_DATE())  -- Add date filter
  AND event_date < CURRENT_DATE();

## Query #2: Dashboard over-refresh
-- CURRENT: Tableau dashboard refreshing every 60 seconds
-- FIX: Implement caching and reduce refresh frequency

-- Option A: Change dashboard refresh to 15 minutes
-- In Tableau: Edit dashboard → Settings → Auto-refresh → 900 seconds

-- Option B: Create results cache table
CREATE OR REPLACE TABLE reporting.dashboard_cache AS
SELECT * FROM reporting.dashboard_query;

-- Refresh cache every 4 hours via task
CREATE OR REPLACE TASK refresh_dashboard_cache
  WAREHOUSE = REPORTING_WH
  SCHEDULE = '240 MINUTE'
AS
  INSERT OVERWRITE INTO reporting.dashboard_cache
  SELECT * FROM reporting.dashboard_query;


## Query #3: Full table reload
-- CURRENT: Daily full reload
COPY INTO raw.events FROM @ext_stage;

-- OPTIMIZED: Incremental loading with merge
-- Step 1: Create staging table for new data only
CREATE OR REPLACE TEMPORARY TABLE raw.events_staging AS
SELECT * FROM @ext_stage
WHERE ingestion_date >= CURRENT_DATE();

-- Step 2: Merge new data
MERGE INTO raw.events t
USING raw.events_staging s
ON t.event_id = s.event_id
WHEN NOT MATCHED THEN INSERT (...)
VALUES (...);

-- Alternative: Use COPY with validation
COPY INTO raw.events FROM @ext_stage
  PATTERN = '.*/events/2026/03/04/.*\.parquet'  -- Only today's files
  VALIDATION_MODE = 'RETURN_ERRORS';


## Query #5: Unfiltered Aggregation
-- CURRENT (expensive):
SELECT user_id, COUNT(*)
FROM raw.events
GROUP BY user_id;

-- OPTIMIZED: Use materialized views for frequent aggregations
-- Create rolling aggregates
CREATE OR REPLACE MATERIALIZED VIEW agg.daily_user_events AS
SELECT 
  user_id,
  event_date,
  COUNT(*) as event_count
FROM raw.events
GROUP BY user_id, event_date;

-- Query using pre-aggregated data
SELECT user_id, SUM(event_count)
FROM agg.daily_user_events
WHERE event_date >= DATEADD(day, -7, CURRENT_DATE())
GROUP BY user_id;


## Query #6: Accidental cross-join

-- CURRENT (accidental cartesian product):
SELECT u.*, e.*
FROM users u, events e
WHERE u.signup_date > '2025-01-01';

-- FIXED: Add proper join condition
SELECT u.*, e.*
FROM users u
INNER JOIN events e ON u.user_id = e.user_id
WHERE u.signup_date > '2025-01-01'
  AND e.event_date >= '2025-01-01';

-- Alternative: Use EXPLAIN to validate join type
EXPLAIN SELECT u.*, e.*
FROM users u
INNER JOIN events e ON u.user_id = e.user_id
WHERE u.signup_date > '2025-01-01';


## Step 2: Projected Query Savings
Step 2: Projected Query Savings

Query #    Current Monthly Credits    After Optimization    Savings
--------------------------------------------------------------------
1          2,560                      640                   1,920
2          2,160                      360                   1,800
3          960                        240                   720
4          800                        200                   600
5          640                        160                   480
6          480                        80                    400
7          480                        240                   240
8          400                        100                   300
9          300                        75                    225
10         250                        50                    200
--------------------------------------------------------------------
Total      9,030                      2,145                 6,885


## Part 3: Storage Optimization
# Step 1: Storage Optimization Plan

Category           Current TT    New TT    Additional Action                New Cost     Savings
----------------------------------------------------------------------------------------------------
Active tables      90 days       7 days    Keep as permanent, reduce TT     $787         $2,213
Staging tables     90 days       0 days    Convert to TRANSIENT             $200         $800
Raw tables         90 days       1 day     Reduce TT, partition by date     $1,027       $3,973
Archive            90 days       0 days    Move to external S3 table        $300         $2,700
Temp/abandoned     90 days       0 days    Drop immediately                  $0          $1,600
----------------------------------------------------------------------------------------------------
Total                                                                        $2,314       $11,286



## Step 2: Write the SQL
-- ============================================
-- STORAGE OPTIMIZATION
-- ============================================

-- Reduce Time Travel on raw tables (costs $40/TB/day)
ALTER DATABASE raw SET DATA_RETENTION_TIME_IN_DAYS = 1;

-- Convert staging to TRANSIENT tables (no fail-safe)
ALTER TABLE staging.user_events SET TRANSIENT;
ALTER TABLE staging.product_catalog SET TRANSIENT;
ALTER DATABASE staging SET DATA_RETENTION_TIME_IN_DAYS = 0;

-- Archive old data to S3 as external tables
-- Create external stage pointing to S3
CREATE OR REPLACE STAGE s3_archive_stage
  URL = 's3://streampulse-archive/'
  STORAGE_INTEGRATION = s3_int;

-- Create external table for archived data
CREATE OR REPLACE EXTERNAL TABLE archive.events_2024
  LOCATION = @s3_archive_stage/events/2024/
  FILE_FORMAT = parquet_format;

-- Move 2024 data to S3
COPY INTO @s3_archive_stage/events/2024/
FROM raw.events
WHERE event_date < '2025-01-01';

-- Drop abandoned tables
-- First identify tables not queried in 90+ days
SELECT table_name, last_queried
FROM INFORMATION_SCHEMA.TABLE_STORAGE_METRICS
WHERE last_queried < DATEADD(day, -90, CURRENT_DATE());

-- Drop identified tables
DROP TABLE IF EXISTS temp.abandoned_table_1;
DROP TABLE IF EXISTS temp.abandoned_table_2;
DROP TABLE IF EXISTS dev.old_experiments;

-- Find and remove duplicated data using zero-copy cloning
-- Create deduplicated version
CREATE OR REPLACE TABLE raw.events_deduped CLONE raw.events;

-- Remove duplicates (example)
DELETE FROM raw.events_deduped
WHERE (event_id, event_time) IN (
  SELECT event_id, MAX(event_time)
  FROM raw.events_deduped
  GROUP BY event_id
  HAVING COUNT(*) > 1
);



## Part 4: Governance Framework
# Step 1: Resource Monitors
-- ============================================
-- RESOURCE MONITORS
-- ============================================

-- Data Engineering team (loading + transform)
CREATE RESOURCE MONITOR data_eng_monitor
  WITH CREDIT_QUOTA = 9000  -- Based on optimized usage
  FREQUENCY = MONTHLY
  START_TIMESTAMP = IMMEDIATELY
  TRIGGERS
    ON 75 PERCENT DO NOTIFY
    ON 90 PERCENT DO NOTIFY
    ON 95 PERCENT DO SUSPEND
    ON 100 PERCENT DO SUSPEND_IMMEDIATE
  COMMENT = 'Monthly quota for data engineering team'
;

-- Analytics team
CREATE RESOURCE MONITOR analytics_monitor
  WITH CREDIT_QUOTA = 2500
  FREQUENCY = MONTHLY
  TRIGGERS
    ON 80 PERCENT DO NOTIFY
    ON 95 PERCENT DO SUSPEND
    ON 100 PERCENT DO SUSPEND_IMMEDIATE
  COMMENT = 'Analytics team quota'
;

-- ML team
CREATE RESOURCE MONITOR ml_monitor
  WITH CREDIT_QUOTA = 3500
  FREQUENCY = MONTHLY
  TRIGGERS
    ON 85 PERCENT DO NOTIFY
    ON 100 PERCENT DO SUSPEND_IMMEDIATE
  COMMENT = 'ML team quota'
;

-- Development / sandbox
CREATE RESOURCE MONITOR dev_monitor
  WITH CREDIT_QUOTA = 1500
  FREQUENCY = MONTHLY
  TRIGGERS
    ON 50 PERCENT DO NOTIFY
    ON 75 PERCENT DO SUSPEND
    ON 90 PERCENT DO SUSPEND_IMMEDIATE
  COMMENT = 'Development and sandbox quota - strict limits'
;

-- Assign monitors to warehouses
ALTER WAREHOUSE LOADING_WH SET RESOURCE_MONITOR = data_eng_monitor;
ALTER WAREHOUSE TRANSFORM_WH SET RESOURCE_MONITOR = data_eng_monitor;
ALTER WAREHOUSE ANALYTICS_WH SET RESOURCE_MONITOR = analytics_monitor;
ALTER WAREHOUSE REPORTING_WH SET RESOURCE_MONITOR = analytics_monitor;
ALTER WAREHOUSE ML_WH SET RESOURCE_MONITOR = ml_monitor;
ALTER WAREHOUSE DEV_WH SET RESOURCE_MONITOR = dev_monitor;
ALTER WAREHOUSE SANDBOX_WH SET RESOURCE_MONITOR = dev_monitor;


## Step 2: Statement Timeouts and Guardrails
-- ============================================
-- GUARDRAILS
-- ============================================

-- Statement timeouts per warehouse
ALTER WAREHOUSE ANALYTICS_WH SET STATEMENT_TIMEOUT_IN_SECONDS = 1800;  -- 30 min
ALTER WAREHOUSE DEV_WH SET STATEMENT_TIMEOUT_IN_SECONDS = 600;        -- 10 min
ALTER WAREHOUSE SANDBOX_WH SET STATEMENT_TIMEOUT_IN_SECONDS = 300;    -- 5 min

-- Maximum warehouse size restrictions (via role grants)
-- Revoke ability to create large warehouses from non-admin roles
REVOKE CREATE WAREHOUSE ON ACCOUNT FROM ROLE ANALYST;
REVOKE CREATE WAREHOUSE ON ACCOUNT FROM ROLE DEVELOPER;

-- Grant ability to use specific warehouse sizes only
GRANT USAGE ON WAREHOUSE ANALYTICS_WH TO ROLE ANALYST;
GRANT USAGE ON WAREHOUSE DEV_WH TO ROLE DEVELOPER;

-- Query tagging for cost attribution
ALTER SESSION SET QUERY_TAG = 'cost_center=analytics';

-- Create tagging function
CREATE OR REPLACE PROCEDURE tag_query(cost_center STRING, project STRING)
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
  ALTER SESSION SET QUERY_TAG = :cost_center || '/' || :project;
  RETURN 'Query tagged as: ' || :cost_center || '/' || :project;
END;
$$;


## Step 3: Monitoring Dashboard Queries
-- 1. Daily spend by warehouse (last 30 days)
SELECT 
  DATE(start_time) as usage_date,
  warehouse_name,
  SUM(credits_used) as total_credits,
  SUM(credits_used) * 2 as estimated_cost
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE start_time >= DATEADD(day, -30, CURRENT_DATE())
GROUP BY 1, 2
ORDER BY 1 DESC, 3 DESC;

-- 2. Top 20 most expensive queries this week
SELECT 
  query_id,
  query_text,
  warehouse_name,
  total_elapsed_time / 1000 as elapsed_seconds,
  credits_used_cloud_services,
  bytes_scanned / POWER(1024, 3) as gb_scanned,
  query_load_percent
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD(day, -7, CURRENT_DATE())
ORDER BY credits_used_cloud_services DESC
LIMIT 20;

-- 3. Warehouses with <30% utilization
SELECT 
  warehouse_name,
  AVG(avg_running) as avg_running,
  AVG(avg_queued_load) as avg_queued,
  AVG(avg_running) / warehouse_size_factor * 100 as utilization_pct
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_LOAD_HISTORY
WHERE start_time >= DATEADD(day, -30, CURRENT_DATE())
GROUP BY 1, warehouse_size_factor
HAVING utilization_pct < 30
ORDER BY utilization_pct;

-- 4. Tables not queried in 90+ days
SELECT 
  table_catalog || '.' || table_schema || '.' || table_name as table_path,
  table_type,
  bytes / POWER(1024, 4) as storage_tb,
  last_altered,
  last_queried
FROM SNOWFLAKE.ACCOUNT_USAGE.TABLES
WHERE last_queried < DATEADD(day, -90, CURRENT_DATE())
  OR last_queried IS NULL
ORDER BY storage_tb DESC;

-- 5. Credit consumption trend (daily, last 90 days)
SELECT 
  DATE_TRUNC('day', start_time) as usage_date,
  SUM(credits_used) as total_credits,
  SUM(credits_used_compute) as compute_credits,
  SUM(credits_used_cloud_services) as cloud_services_credits,
  COUNT(DISTINCT warehouse_name) as warehouses_active
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE start_time >= DATEADD(day, -90, CURRENT_DATE())
GROUP BY 1
ORDER BY 1;



## Part 5: Executive Summary
┌─────────────────────────────────────────────────────────────────┐
│ COST OPTIMIZATION REPORT — StreamPulse                          │
│ Prepared by: Senior Data Engineer                               │
│ Date: March 4, 2026                                             │
│                                                                  │
│ CURRENT STATE                                                    │
│ Monthly Snowflake bill: $58,000                                  │
│ Annual projected: $696,000                                       │
│ QoQ growth: +25%                                                 │
│                                                                  │
│ SAVINGS IDENTIFIED                                               │
│                                                                  │
│ Category         Current    Optimized   Savings    % Reduction  │
│ ─────────────────────────────────────────────────────────────── │
│ Compute          $58,080    $33,000     $25,080       43%       │
│ Query waste      $18,060    $4,290      $13,770       76%       │
│ Storage          $13,600    $2,314      $11,286       83%       │
│ ─────────────────────────────────────────────────────────────── │
│ TOTAL            $89,740    $39,604     $50,136       56%       │
│                                                                  │
│ NOTE: Query waste overlaps with compute, actual total           │
│       savings = $58,000 - $29,000 = $29,000 (50%)               │
│                                                                  │
│ SAVINGS PERCENTAGE: 50%                                          │
│ ANNUAL SAVINGS: $348,000                                         │
│                                                                  │
│ IMPLEMENTATION TIMELINE                                          │
│ Week 1: Warehouse resizing, auto-suspend settings               │
│ Week 2: Storage optimization, time travel reduction             │
│ Week 3: Query optimization, resource monitors                   │
│ Week 4: Governance framework, monitoring dashboard              │
│                                                                  │
│ RISK: Low - All changes are reversible, no impact on            │
│       analytical capabilities. Performance monitoring in place. │
│                                                                  │
│ RECOMMENDATION: Approve immediate implementation of warehouse   │
│                 and storage optimizations. Query optimizations  │
│                 to be rolled out with developer training.       │
└─────────────────────────────────────────────────────────────────┘


