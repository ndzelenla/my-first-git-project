(Challenge) BI Dashboard Design
Author: Sammy Ndzelen
Date: 06.03.2026


## Widget 1: KPI Cards

-- KPI: DAU (Daily Active Users)
WITH dau_metrics AS (
  SELECT 
    COUNT(DISTINCT user_id) as current_dau,
    LAG(COUNT(DISTINCT user_id), 7) OVER (ORDER BY date) as prev_dau
  FROM fct_engagement
  WHERE date = CURRENT_DATE()
  GROUP BY date
)
SELECT 
  current_dau as value,
  prev_dau as previous_value,
  ROUND(((current_dau - prev_dau) / prev_dau) * 100, 1) as pct_change
FROM dau_metrics;

-- KPI: MAU (Monthly Active Users)
WITH mau_metrics AS (
  SELECT 
    COUNT(DISTINCT user_id) as current_mau
  FROM fct_engagement
  WHERE date BETWEEN DATE_TRUNC('month', CURRENT_DATE()) 
                AND CURRENT_DATE()
)
SELECT 
  current_mau as value,
  LAG(current_mau, 1) OVER (ORDER BY DATE_TRUNC('month', CURRENT_DATE())) as prev_value,
  ROUND(((current_mau - LAG(current_mau, 1) OVER (ORDER BY DATE_TRUNC('month', CURRENT_DATE()))) / 
         LAG(current_mau, 1) OVER (ORDER BY DATE_TRUNC('month', CURRENT_DATE()))) * 100, 1) as pct_change
FROM mau_metrics;

-- KPI: MRR (Monthly Recurring Revenue)
WITH mrr_metrics AS (
  SELECT 
    SUM(monthly_subscription_amount) as current_mrr
  FROM dim_users u
  JOIN dim_subscriptions s ON u.current_subscription_id = s.subscription_id
  WHERE u.subscription_status = 'active'
)
SELECT 
  current_mrr as value,
  current_mrr * 0.965 as prev_value, -- Simplified: would use actual previous month
  ROUND(((current_mrr - (current_mrr * 0.965)) / (current_mrr * 0.965)) * 100, 1) as pct_change
FROM mrr_metrics;

-- KPI: Average Watch Time
WITH daily_watch_time AS (
  SELECT 
    date,
    SUM(watch_minutes) / COUNT(DISTINCT user_id) as avg_watch_minutes
  FROM fct_engagement
  WHERE date BETWEEN DATEADD(day, -7, CURRENT_DATE()) AND CURRENT_DATE()
  GROUP BY date
)
SELECT 
  ROUND(AVG(avg_watch_minutes), 0) as value,
  ROUND(AVG(avg_watch_minutes) * 0.88, 0) as prev_value, -- Simplified comparison
  ROUND(((AVG(avg_watch_minutes) - (AVG(avg_watch_minutes) * 0.88)) / 
         (AVG(avg_watch_minutes) * 0.88)) * 100, 1) as pct_change
FROM daily_watch_time;


## Widget 2: DAU Trend Line (90 days)
WITH daily_users AS (
  SELECT 
    date,
    COUNT(DISTINCT user_id) as dau
  FROM fct_engagement
  WHERE date >= DATEADD(day, -90, CURRENT_DATE())
  GROUP BY date
),
moving_avg AS (
  SELECT 
    date,
    dau,
    AVG(dau) OVER (ORDER BY date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) as dau_7d_moving_avg,
    LAG(dau, 7) OVER (ORDER BY date) as dau_previous_week
  FROM daily_users
)
SELECT 
  date,
  dau,
  ROUND(dau_7d_moving_avg, 0) as dau_7d_moving_avg,
  dau_previous_week,
  ROUND(((dau - dau_previous_week) / dau_previous_week) * 100, 1) as wow_change_pct
FROM moving_avg
WHERE dau_previous_week IS NOT NULL
ORDER BY date ASC;



##  Widget 3: Revenue by Plan (Pie Chart)
WITH active_subscriptions AS (
  SELECT 
    s.plan_name,
    COUNT(DISTINCT u.user_id) as subscriber_count,
    SUM(s.monthly_amount) as mrr,
    SUM(s.monthly_amount) * 100.0 / SUM(SUM(s.monthly_amount)) OVER () as pct_of_total_mrr
  FROM dim_users u
  JOIN dim_subscriptions s ON u.current_subscription_id = s.subscription_id
  WHERE u.subscription_status = 'active'
    AND u.subscription_end_date >= DATE_TRUNC('month', CURRENT_DATE())
  GROUP BY s.plan_name
)
SELECT 
  plan_name,
  subscriber_count,
  ROUND(mrr, 2) as mrr,
  ROUND(pct_of_total_mrr, 1) as pct_of_total_mrr
FROM active_subscriptions
ORDER BY mrr DESC;


## Widget 4: Top 5 Shows (Bar Chart)
WITH weekly_shows AS (
  SELECT 
    c.show_name,
    c.genre,
    COUNT(e.engagement_id) as total_views,
    COUNT(DISTINCT e.user_id) as unique_viewers,
    AVG(e.completion_pct) as avg_completion_rate
  FROM fct_engagement e
  JOIN dim_content c ON e.content_id = c.content_id
  WHERE e.date BETWEEN DATE_TRUNC('week', CURRENT_DATE()) 
                   AND DATEADD(day, 6, DATE_TRUNC('week', CURRENT_DATE()))
  GROUP BY c.show_name, c.genre
)
SELECT 
  show_name,
  genre,
  total_views,
  unique_viewers,
  ROUND(avg_completion_rate, 1) as avg_completion_rate
FROM weekly_shows
ORDER BY total_views DESC
LIMIT 5;



## Widget 5: Subscription Funnel (Table)
WITH monthly_metrics AS (
  SELECT 
    COUNT(DISTINCT CASE WHEN signup_date BETWEEN DATE_TRUNC('month', CURRENT_DATE()) 
                         AND CURRENT_DATE() THEN user_id END) as new_this_month,
    COUNT(DISTINCT CASE WHEN subscription_status = 'active' THEN user_id END) as active,
    COUNT(DISTINCT CASE WHEN last_activity_date < DATEADD(day, -14, CURRENT_DATE()) 
                         AND subscription_status = 'active' THEN user_id END) as at_risk,
    COUNT(DISTINCT CASE WHEN churn_date BETWEEN DATE_TRUNC('month', CURRENT_DATE()) 
                         AND CURRENT_DATE() THEN user_id END) as churned_this_month
  FROM dim_users
)
SELECT 
  new_this_month,
  active,
  at_risk,
  churned_this_month,
  (new_this_month - churned_this_month) as net_change
FROM monthly_metrics;



### Part 2: Content Performance Dashboard
## Widget 1: Content Scorecard
SELECT 
  COUNT(DISTINCT e.engagement_id) as total_views_last_30d,
  ROUND(AVG(e.completion_pct), 1) as avg_completion_rate,
  COUNT(DISTINCT c.content_id) as total_content_items,
  COUNT(DISTINCT CASE WHEN c.release_date >= DATE_TRUNC('month', CURRENT_DATE()) 
                      THEN c.content_id END) as new_releases_this_month
FROM dim_content c
LEFT JOIN fct_engagement e ON c.content_id = e.content_id 
  AND e.date >= DATEADD(day, -30, CURRENT_DATE());


## Widget 2: Genre × Day Heatmap
SELECT 
  c.genre,
  DAYOFWEEK(e.date) as day_of_week,
  DAYNAME(e.date) as day_name,
  COUNT(e.engagement_id) as total_views
FROM fct_engagement e
JOIN dim_content c ON e.content_id = c.content_id
WHERE e.date >= DATEADD(day, -30, CURRENT_DATE())
GROUP BY c.genre, DAYOFWEEK(e.date), DAYNAME(e.date)
ORDER BY c.genre, day_of_week;


## Widget 3: Content Lifecycle Curve
WITH released_shows AS (
  SELECT 
    c.show_name,
    c.release_date,
    c.content_id
  FROM dim_content c
  WHERE c.release_date >= DATEADD(day, -90, CURRENT_DATE())
    AND c.content_type = 'episode'
),
daily_engagement AS (
  SELECT 
    rs.show_name,
    rs.release_date,
    DATEDIFF(day, rs.release_date, e.date) as days_since_release,
    COUNT(e.engagement_id) as daily_views,
    SUM(COUNT(e.engagement_id)) OVER (PARTITION BY rs.show_name ORDER BY e.date 
                                      ROWS UNBOUNDED PRECEDING) as cumulative_views
  FROM released_shows rs
  JOIN fct_engagement e ON rs.content_id = e.content_id
  WHERE e.date BETWEEN rs.release_date AND DATEADD(day, 30, rs.release_date)
  GROUP BY rs.show_name, rs.release_date, e.date
)
SELECT 
  show_name,
  release_date,
  days_since_release,
  cumulative_views,
  daily_views
FROM daily_engagement
WHERE days_since_release BETWEEN 0 AND 30
ORDER BY show_name, days_since_release;


## Widget 4: Show Leaderboard
WITH show_metrics AS (
  SELECT 
    c.show_name,
    c.genre,
    COUNT(DISTINCT e.engagement_id) as total_views,
    COUNT(DISTINCT e.user_id) as unique_viewers,
    AVG(e.completion_pct) as avg_completion_rate
  FROM fct_engagement e
  JOIN dim_content c ON e.content_id = c.content_id
  WHERE e.date >= DATEADD(day, -90, CURRENT_DATE())
  GROUP BY c.show_name, c.genre
)
SELECT 
  show_name,
  genre,
  total_views,
  unique_viewers,
  ROUND(avg_completion_rate, 1) as avg_completion_rate,
  ROUND(
    (total_views * 0.3) + 
    (unique_viewers * 0.3) + 
    (avg_completion_rate * 100 * 0.4), 
  2) as engagement_score
FROM show_metrics
WHERE total_views >= 1000
ORDER BY engagement_score DESC
LIMIT 20;


## Widget 5: Completion Rate vs Duration Scatter
SELECT 
  c.content_id,
  c.title,
  c.duration_minutes,
  AVG(e.completion_pct) as completion_rate,
  COUNT(e.engagement_id) as total_views,
  c.genre
FROM dim_content c
JOIN fct_engagement e ON c.content_id = e.content_id
WHERE e.date >= DATEADD(day, -90, CURRENT_DATE())
GROUP BY c.content_id, c.title, c.duration_minutes, c.genre
HAVING COUNT(e.engagement_id) >= 1000
ORDER BY c.duration_minutes;


## Part 3: BI-Ready Views
-- ============================================
-- VIEW 1: Executive Daily Summary
-- ============================================
CREATE OR REPLACE VIEW MARTS.v_executive_daily AS
WITH daily_metrics AS (
  SELECT 
    e.date,
    COUNT(DISTINCT e.user_id) as dau,
    COUNT(DISTINCT u.user_id) as mau,
    SUM(CASE WHEN u.subscription_status = 'active' THEN s.monthly_amount ELSE 0 END) as mrr,
    SUM(e.watch_minutes) / NULLIF(COUNT(DISTINCT e.user_id), 0) as avg_watch_minutes,
    COUNT(DISTINCT CASE WHEN u.signup_date = e.date THEN u.user_id END) as new_signups,
    COUNT(DISTINCT CASE WHEN u.churn_date = e.date THEN u.user_id END) as churned
  FROM fct_engagement e
  CROSS JOIN dim_users u
  LEFT JOIN dim_subscriptions s ON u.current_subscription_id = s.subscription_id
  WHERE e.date >= DATEADD(day, -90, CURRENT_DATE())
  GROUP BY e.date
)
SELECT 
  date,
  dau,
  mau,
  mrr,
  ROUND(avg_watch_minutes, 0) as avg_watch_minutes,
  new_signups,
  churned,
  (new_signups - churned) as net_change,
  AVG(dau) OVER (ORDER BY date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) as dau_7d_avg,
  ROUND(((dau - LAG(dau, 7) OVER (ORDER BY date)) / 
         NULLIF(LAG(dau, 7) OVER (ORDER BY date), 0)) * 100, 1) as wow_pct
FROM daily_metrics;

-- ============================================
-- VIEW 2: Content Performance
-- ============================================
CREATE OR REPLACE VIEW MARTS.v_content_performance AS
SELECT 
  e.date,
  c.content_id,
  c.show_name,
  c.genre,
  c.content_type,
  c.release_date,
  COUNT(DISTINCT e.engagement_id) as views,
  COUNT(DISTINCT e.user_id) as unique_viewers,
  ROUND(AVG(e.completion_pct), 1) as completion_rate,
  ROUND(AVG(e.watch_minutes), 0) as avg_watch_min
FROM fct_engagement e
JOIN dim_content c ON e.content_id = c.content_id
WHERE e.date >= DATEADD(day, -90, CURRENT_DATE())
GROUP BY e.date, c.content_id, c.show_name, c.genre, c.content_type, c.release_date;

-- ============================================
-- VIEW 3: Subscription Analysis
-- ============================================
CREATE OR REPLACE VIEW MARTS.v_subscription_analysis AS
WITH monthly_cohorts AS (
  SELECT 
    DATE_TRUNC('month', u.signup_date) as cohort_month,
    DATE_TRUNC('month', e.date) as activity_month,
    s.plan_name,
    COUNT(DISTINCT CASE WHEN u.signup_date = e.date THEN u.user_id END) as new_subs,
    COUNT(DISTINCT u.user_id) as active_subs,
    COUNT(DISTINCT CASE WHEN u.churn_date = e.date THEN u.user_id END) as churned_subs,
    SUM(s.monthly_amount) as mrr,
    AVG(DATEDIFF(day, u.signup_date, COALESCE(u.churn_date, CURRENT_DATE()))) as avg_lifetime_days
  FROM dim_users u
  CROSS JOIN fct_engagement e
  LEFT JOIN dim_subscriptions s ON u.current_subscription_id = s.subscription_id
  WHERE e.date >= DATEADD(month, -12, CURRENT_DATE())
  GROUP BY cohort_month, activity_month, s.plan_name
)
SELECT * FROM monthly_cohorts;

-- ============================================
-- VIEW 4: Self-Service Explorer
-- ============================================
CREATE OR REPLACE VIEW MARTS.v_self_service AS
SELECT 
  e.engagement_id,
  e.date as engagement_date,
  e.watch_minutes,
  e.completion_pct,
  e.device_type,
  e.platform,
  u.user_id,
  u.age_group,
  u.gender,
  u.country,
  u.region,
  u.subscription_status,
  u.signup_date,
  u.churn_date,
  s.plan_name,
  s.monthly_amount as subscription_amount,
  c.content_id,
  c.show_name,
  c.episode_title,
  c.genre,
  c.content_type,
  c.release_date as content_release_date,
  c.duration_minutes,
  c.rating,
  c.production_studio
FROM fct_engagement e
JOIN dim_users u ON e.user_id = u.user_id
LEFT JOIN dim_subscriptions s ON u.current_subscription_id = s.subscription_id
JOIN dim_content c ON e.content_id = c.content_id;



## Part 4: Access Governance
# Task 1: BI Access Setup
-- ============================================
-- BI SERVICE ACCOUNTS AND ROLES
-- ============================================

-- Create service account for Tableau
CREATE USER IF NOT EXISTS tableau_svc
  PASSWORD = '<secure-password>'
  MUST_CHANGE_PASSWORD = FALSE
  DEFAULT_ROLE = BI_VIEWER
  DEFAULT_WAREHOUSE = REPORTING_WH;

-- Create service account for Looker
CREATE USER IF NOT EXISTS looker_svc
  PASSWORD = '<secure-password>'
  MUST_CHANGE_PASSWORD = FALSE
  DEFAULT_ROLE = BI_EXPLORER
  DEFAULT_WAREHOUSE = REPORTING_WH;

-- Create BI roles
CREATE ROLE IF NOT EXISTS BI_VIEWER;       -- Read access to marts
CREATE ROLE IF NOT EXISTS BI_EXPLORER;     -- Read access + self-service
CREATE ROLE IF NOT EXISTS BI_ADMIN;        -- Can create views in marts

-- Grant hierarchy
GRANT ROLE BI_VIEWER TO ROLE BI_EXPLORER;
GRANT ROLE BI_EXPLORER TO ROLE BI_ADMIN;

-- Grant table/view access
GRANT USAGE ON DATABASE STREAMPULSE TO ROLE BI_VIEWER;
GRANT USAGE ON SCHEMA STREAMPULSE.MARTS TO ROLE BI_VIEWER;
GRANT SELECT ON ALL VIEWS IN SCHEMA STREAMPULSE.MARTS TO ROLE BI_VIEWER;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA STREAMPULSE.MARTS TO ROLE BI_VIEWER;

-- Additional access for BI_EXPLORER
GRANT SELECT ON MARTS.v_self_service TO ROLE BI_EXPLORER;

-- Additional access for BI_ADMIN
GRANT CREATE VIEW ON SCHEMA STREAMPULSE.MARTS TO ROLE BI_ADMIN;
GRANT CREATE TABLE ON SCHEMA STREAMPULSE.MARTS TO ROLE BI_ADMIN;

-- Grant warehouse access
GRANT USAGE ON WAREHOUSE REPORTING_WH TO ROLE BI_VIEWER;
GRANT OPERATE ON WAREHOUSE REPORTING_WH TO ROLE BI_ADMIN;
GRANT MONITOR ON WAREHOUSE REPORTING_WH TO ROLE BI_ADMIN;

-- Assign roles to users
GRANT ROLE BI_VIEWER TO USER tableau_svc;
GRANT ROLE BI_EXPLORER TO USER looker_svc;
GRANT ROLE BI_ADMIN TO USER data_team_lead;


## Task 2: Column-Level Security
-- Create masking policy for PII
CREATE OR REPLACE MASKING POLICY mask_pii AS 
  (val STRING) RETURNS STRING ->
    CASE 
      WHEN CURRENT_ROLE() IN ('BI_ADMIN', 'DATA_ENGINEER', 'COMPLIANCE_OFFICER') 
      THEN val 
      ELSE '***REDACTED***' 
    END;

-- Apply masking to sensitive columns
ALTER TABLE dim_users MODIFY COLUMN email 
  SET MASKING POLICY mask_pii;

ALTER TABLE dim_users MODIFY COLUMN phone 
  SET MASKING POLICY mask_pii;

ALTER TABLE dim_users MODIFY COLUMN full_name 
  SET MASKING POLICY mask_pii;

ALTER TABLE dim_users MODIFY COLUMN ip_address 
  SET MASKING POLICY mask_pii;

-- Also apply to views
ALTER VIEW MARTS.v_self_service MODIFY COLUMN email 
  SET MASKING POLICY mask_pii;

-- Create regional roles
CREATE ROLE IF NOT EXISTS BI_VIEWER_US;
CREATE ROLE IF NOT EXISTS BI_VIEWER_EU;
CREATE ROLE IF NOT EXISTS BI_VIEWER_APAC;

-- Grant hierarchy
GRANT ROLE BI_VIEWER_US TO ROLE BI_EXPLORER;
GRANT ROLE BI_VIEWER_EU TO ROLE BI_EXPLORER;
GRANT ROLE BI_VIEWER_APAC TO ROLE BI_EXPLORER;


## Task 3: Row-Level Security

-- Create row access policy
CREATE OR REPLACE ROW ACCESS POLICY region_policy AS 
  (region STRING) RETURNS BOOLEAN ->
    CASE 
      WHEN CURRENT_ROLE() = 'BI_ADMIN' THEN TRUE
      WHEN CURRENT_ROLE() = 'BI_VIEWER_US' AND region IN ('US', 'CA') THEN TRUE
      WHEN CURRENT_ROLE() = 'BI_VIEWER_EU' AND region IN ('UK', 'FR', 'DE', 'IT', 'ES') THEN TRUE
      WHEN CURRENT_ROLE() = 'BI_VIEWER_APAC' AND region IN ('JP', 'KR', 'AU', 'NZ', 'SG') THEN TRUE
      ELSE FALSE
    END;

-- Apply to tables
ALTER TABLE dim_users 
  ADD ROW ACCESS POLICY region_policy ON (region);

ALTER TABLE MARTS.v_self_service 
  ADD ROW ACCESS POLICY region_policy ON (region);


## Part 5: Performance Optimization
# Task 1: Warehouse Configuration
-- Configure the BI warehouse for optimal dashboard performance
ALTER WAREHOUSE REPORTING_WH SET
  WAREHOUSE_SIZE = 'MEDIUM'  -- Balanced for concurrent queries
  AUTO_SUSPEND = 60          -- Suspend after 60 seconds idle
  AUTO_RESUME = TRUE         -- Resume automatically
  INITIALLY_SUSPENDED = TRUE
  MIN_CLUSTER_COUNT = 1      -- Start with 1 cluster
  MAX_CLUSTER_COUNT = 3      -- Scale up to 3 during peak
  SCALING_POLICY = 'STANDARD'
  WAIT_FOR_COMPLETION = FALSE
  STATEMENT_QUEUED_TIMEOUT_IN_SECONDS = 300   -- 5 min queue timeout
  STATEMENT_TIMEOUT_IN_SECONDS = 1800;         -- 30 min query timeout


## Task 2: Materialized Views for Heavy Queries

=====================================================================================================================================
| Query/View              | Complexity | Frequency  | Materialized View? | Justification                                           |
|-------------------------|------------|------------|--------------------|---------------------------------------------------------|
| v_executive_daily       | Medium     | Every 15m  | YES                | High refresh frequency; powers CEO dashboard with real- |
|                         |            |            |                    | time KPIs; complex window functions for WoW comparisons |
|-------------------------|------------|------------|--------------------|---------------------------------------------------------|
| v_content_performance   | High       | Every 15m  | YES                | Most complex aggregations; frequently accessed by       |
|                         |            |            |                    | multiple teams; large table joins impact performance    |
|-------------------------|------------|------------|--------------------|---------------------------------------------------------|
| v_subscription_analysis | Medium     | Hourly     | YES                | Monthly cohort analysis expensive to recalc hourly;     |
|                         |            |            |                    | stable historical patterns; revenue tracking consistency |
|-------------------------|------------|------------|--------------------|---------------------------------------------------------|
| v_self_service          | High       | On-demand  | NO                 | Too broad with dynamic filters; would stale quickly;    |
|                         |            |            |                    | better served by query caching and result set cache     |
=====================================================================================================================================

=============================================================
MATERIALIZED VIEW 1: mv_executive_daily
=============================================================
-- Purpose: Powers CEO dashboard with pre-aggregated daily KPIs
-- Refresh: Every 15 minutes
-- Complexity: Medium - Window functions for comparisons

CREATE OR REPLACE MATERIALIZED VIEW MARTS.mv_executive_daily AS
SELECT 
    e.date,
    COUNT(DISTINCT e.user_id) as dau,
    COUNT(DISTINCT u.user_id) as mau,
    SUM(CASE WHEN u.subscription_status = 'active' THEN s.monthly_amount ELSE 0 END) as mrr,
    SUM(e.watch_minutes) / NULLIF(COUNT(DISTINCT e.user_id), 0) as avg_watch_minutes,
    COUNT(DISTINCT CASE WHEN u.signup_date = e.date THEN u.user_id END) as new_signups,
    COUNT(DISTINCT CASE WHEN u.churn_date = e.date THEN u.user_id END) as churned
FROM fct_engagement e
CROSS JOIN dim_users u
LEFT JOIN dim_subscriptions s ON u.current_subscription_id = s.subscription_id
WHERE e.date >= DATEADD(day, -90, CURRENT_DATE())
GROUP BY e.date;

=============================================================
MATERIALIZED VIEW 2: mv_content_performance
=============================================================
-- Purpose: Powers content dashboard with show/genre metrics
-- Refresh: Every 15 minutes
-- Complexity: High - Multi-table joins with aggregations

CREATE OR REPLACE MATERIALIZED VIEW MARTS.mv_content_performance AS
SELECT 
    e.date,
    c.content_id,
    c.show_name,
    c.genre,
    c.content_type,
    c.release_date,
    COUNT(DISTINCT e.engagement_id) as views,
    COUNT(DISTINCT e.user_id) as unique_viewers,
    AVG(e.completion_pct) as completion_rate,
    AVG(e.watch_minutes) as avg_watch_min
FROM fct_engagement e
JOIN dim_content c ON e.content_id = c.content_id
WHERE e.date >= DATEADD(day, -90, CURRENT_DATE())
GROUP BY e.date, c.content_id, c.show_name, c.genre, c.content_type, c.release_date;

=============================================================
MATERIALIZED VIEW 3: mv_subscription_analysis
=============================================================
-- Purpose: Monthly subscription cohorts for revenue tracking
-- Refresh: Hourly
-- Complexity: Medium - Cohort analysis with date math

CREATE OR REPLACE MATERIALIZED VIEW MARTS.mv_subscription_analysis AS
SELECT 
    DATE_TRUNC('month', u.signup_date) as cohort_month,
    s.plan_name,
    COUNT(DISTINCT u.user_id) as total_subs,
    SUM(s.monthly_amount) as total_mrr,
    AVG(DATEDIFF(day, u.signup_date, COALESCE(u.churn_date, CURRENT_DATE()))) as avg_lifetime_days,
    COUNT(DISTINCT CASE WHEN u.subscription_status = 'active' THEN u.user_id END) as active_subs,
    COUNT(DISTINCT CASE WHEN u.churn_date IS NOT NULL THEN u.user_id END) as churned_subs
FROM dim_users u
LEFT JOIN dim_subscriptions s ON u.current_subscription_id = s.subscription_id
GROUP BY DATE_TRUNC('month', u.signup_date), s.plan_name;

=============================================================
CLUSTERING CONFIGURATION
=============================================================

ALTER MATERIALIZED VIEW MARTS.mv_executive_daily 
    CLUSTER BY (date);

ALTER MATERIALIZED VIEW MARTS.mv_content_performance 
    CLUSTER BY (date, genre);

ALTER MATERIALIZED VIEW MARTS.mv_subscription_analysis 
    CLUSTER BY (cohort_month, plan_name);

=============================================================
REFRESH TASKS
=============================================================

CREATE OR REPLACE TASK refresh_executive_mv
    WAREHOUSE = REPORTING_WH
    SCHEDULE = '15 MINUTE'
AS
    ALTER MATERIALIZED VIEW MARTS.mv_executive_daily REFRESH;

CREATE OR REPLACE TASK refresh_content_mv
    WAREHOUSE = REPORTING_WH
    SCHEDULE = '15 MINUTE'
AS
    ALTER MATERIALIZED VIEW MARTS.mv_content_performance REFRESH;

CREATE OR REPLACE TASK refresh_subscription_mv
    WAREHOUSE = REPORTING_WH
    SCHEDULE = '60 MINUTE'
AS
    ALTER MATERIALIZED VIEW MARTS.mv_subscription_analysis REFRESH;

ALTER TASK refresh_executive_mv RESUME;
ALTER TASK refresh_content_mv RESUME;
ALTER TASK refresh_subscription_mv RESUME;

=============================================================
MONITORING QUERY
=============================================================

SELECT 
    table_name,
    rows,
    bytes,
    last_altered,
    DATEDIFF(minute, last_altered, CURRENT_TIMESTAMP()) as minutes_since_refresh,
    auto_clustering_on
FROM information_schema.tables 
WHERE table_schema = 'MARTS' 
    AND table_type = 'MATERIALIZED VIEW'
ORDER BY table_name;


## Task 3: Dashboard Refresh Strategy

=================================================================================================================================================
| Dashboard            | Current Refresh | Recommended Refresh | Query Cost (credits/day) | Optimization Strategy                                    |
|----------------------|-----------------|----------------------|--------------------------|---------------------------------------------------------|
| Executive            | Every 15 min    | Every 15 min         | 2.5 credits             | Use materialized views for pre-aggregation; implement  |
|                      |                 |                      |                          | result cache for repeated queries; cluster by date     |
|----------------------|-----------------|----------------------|--------------------------|---------------------------------------------------------|
| Content Performance  | Every 15 min    | Every 30 min         | 3.0 credits             | Partition by date; use materialized views with genre   |
|                      |                 |                      |                          | clustering; implement incremental refresh strategy     |
|----------------------|-----------------|----------------------|--------------------------|---------------------------------------------------------|
| Self-Service         | On-demand       | On-demand (cached)   | 0.5 credits             | Leverage query cache (24hr TTL); result set cache      |
|                      |                 |                      |                          | (24hr); implement query timeout limits; use search      |
|                      |                 |                      |                          | optimization service for frequent filter patterns       |
=================================================================================================================================================

=============================================================
DETAILED REFRESH CONFIGURATION
=============================================================

-- ===========================================================
-- EXECUTIVE DASHBOARD - High Frequency Refresh
-- ===========================================================
-- Business Critical: CEO daily decisions
-- Current Cost: 2.5 credits/day
-- Optimization Target: 1.8 credits/day (28% reduction)

-- Implement materialized view with automatic refresh
CREATE OR REPLACE MATERIALIZED VIEW MARTS.mv_executive_daily 
    CLUSTER BY (date)
    AUTO_REFRESH = TRUE
AS
    SELECT * FROM MARTS.v_executive_daily;

-- Set up result cache for repeated queries
ALTER SESSION SET USE_CACHED_RESULT = TRUE;

-- Configure query timeout for dashboard queries
ALTER WAREHOUSE REPORTING_WH 
    SET STATEMENT_TIMEOUT_IN_SECONDS = 30;  -- Dashboard queries timeout after 30s

-- ===========================================================
-- CONTENT PERFORMANCE DASHBOARD - Medium Frequency Refresh
-- ===========================================================
-- Current Cost: 3.0 credits/day
-- Optimization Target: 1.5 credits/day (50% reduction)

-- Partitioned materialized view for incremental refresh
CREATE OR REPLACE MATERIALIZED VIEW MARTS.mv_content_performance
    CLUSTER BY (date, genre)
    AUTO_REFRESH = TRUE
AS
    SELECT 
        date,
        genre,
        show_name,
        COUNT(DISTINCT content_id) as unique_content,
        SUM(views) as total_views,
        AVG(completion_rate) as avg_completion
    FROM MARTS.v_content_performance
    WHERE date >= DATEADD(day, -90, CURRENT_DATE())
    GROUP BY date, genre, show_name;

-- Create incremental refresh task
CREATE OR REPLACE TASK refresh_content_dashboard
    WAREHOUSE = REPORTING_WH
    SCHEDULE = '30 MINUTE'
WHEN
    SYSTEM$STREAM_HAS_DATA('content_engagement_stream')
AS
    MERGE INTO MARTS.mv_content_performance t
    USING (
        SELECT 
            date,
            genre,
            show_name,
            COUNT(DISTINCT content_id) as unique_content,
            SUM(views) as total_views,
            AVG(completion_rate) as avg_completion
        FROM MARTS.v_content_performance
        WHERE date >= CURRENT_DATE() - 1  -- Only last 24 hours
        GROUP BY date, genre, show_name
    ) s
    ON t.date = s.date AND t.genre = s.genre AND t.show_name = s.show_name
    WHEN MATCHED THEN UPDATE SET
        t.unique_content = s.unique_content,
        t.total_views = s.total_views,
        t.avg_completion = s.avg_completion
    WHEN NOT MATCHED THEN INSERT
        (date, genre, show_name, unique_content, total_views, avg_completion)
    VALUES
        (s.date, s.genre, s.show_name, s.unique_content, s.total_views, s.avg_completion);

-- ===========================================================
-- SELF-SERVICE DASHBOARD - On-demand with Caching
-- ===========================================================
-- Current Cost: 0.5 credits/day
-- Optimization Target: 0.2 credits/day (60% reduction)

-- Enable result caching for self-service
ALTER SESSION SET 
    USE_CACHED_RESULT = TRUE,
    RESULT_SCAN_TTL_SECONDS = 86400;  -- 24 hour cache

-- Create search optimization for common filter patterns
ALTER TABLE MARTS.v_self_service 
    ADD SEARCH OPTIMIZATION ON EQUALITY(genre, country, device_type, age_group);

-- Create aggregated rolling 30-day snapshot for common queries
CREATE OR REPLACE TABLE MARTS.snap_self_service_30d AS
SELECT 
    DATE_TRUNC('day', engagement_date) as day,
    genre,
    country,
    age_group,
    device_type,
    platform,
    COUNT(DISTINCT user_id) as active_users,
    COUNT(engagement_id) as total_engagements,
    SUM(watch_minutes) as total_watch_minutes
FROM MARTS.v_self_service
WHERE engagement_date >= DATEADD(day, -30, CURRENT_DATE())
GROUP BY 1, 2, 3, 4, 5, 6;

-- ===========================================================
== CACHING CONFIGURATION SUMMARY
== ===========================================================

-- Result Cache Settings (24-hour TTL)
ALTER ACCOUNT SET 
    RESULT_SCAN_TTL_SECONDS = 86400,           -- Cache query results for 24h
    STATEMENT_QUEUED_TIMEOUT_IN_SECONDS = 300; -- Queue timeout for BI tools

-- Warehouse Configuration for Dashboard Queries
ALTER WAREHOUSE REPORTING_WH SET
    MIN_CLUSTER_COUNT = 2,                      -- Minimum 2 clusters during peak
    MAX_CLUSTER_COUNT = 4,                      -- Scale to 4 clusters
    SCALING_POLICY = 'ECONOMY',                  -- Balance cost and performance
    AUTO_SUSPEND = 120,                          -- 2 minute auto-suspend
    AUTO_RESUME = TRUE,
    STATEMENT_TIMEOUT_IN_SECONDS = 600,          -- Query timeout 10 minutes
    STATEMENT_QUEUED_TIMEOUT_IN_SECONDS = 120;   -- Queue timeout 2 minutes

-- ===========================================================
== REFRESH SCHEDULE OPTIMIZATION TABLE
== ===========================================================

------------------------------------------------------------------------------------------------
| Time Window    | Dashboard    | Refresh Interval | Cluster Size | Expected Cost/Hour |
|----------------|--------------|-------------------|--------------|---------------------|
| 00:00 - 06:00  | All          | 60 min           | Small        | 0.05 credits        |
| 06:00 - 09:00  | Executive    | 30 min           | Medium       | 0.10 credits        |
|                | Content      | 60 min           | Small        | 0.05 credits        |
| 09:00 - 17:00  | Executive    | 15 min           | Large        | 0.25 credits        |
|                | Content      | 30 min           | Medium       | 0.15 credits        |
|                | Self-Service | On-demand        | Medium       | 0.08 credits        |
| 17:00 - 20:00  | Executive    | 15 min           | Large        | 0.25 credits        |
|                | Content      | 30 min           | Medium       | 0.15 credits        |
| 20:00 - 00:00  | Executive    | 30 min           | Medium       | 0.10 credits        |
|                | Content      | 60 min           | Small        | 0.05 credits        |
------------------------------------------------------------------------------------------------

-- ===========================================================
== PERFORMANCE MONITORING QUERY
== ===========================================================

-- Monitor dashboard performance and cost
SELECT 
    DATE_TRUNC('hour', start_time) as hour,
    warehouse_name,
    COUNT(query_id) as query_count,
    SUM(credits_used) as total_credits,
    AVG(execution_time/1000) as avg_execution_seconds,
    SUM(CASE WHEN execution_time < 1000 THEN 1 ELSE 0 END) as subsecond_queries,
    SUM(CACHE_HIT) as cached_queries,
    AVG(bytes_scanned/1024/1024/1024) as avg_gb_scanned
FROM snowflake.account_usage.query_history
WHERE warehouse_name = 'REPORTING_WH'
    AND start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP())
    AND query_type = 'SELECT'
GROUP BY 1, 2
ORDER BY 1 DESC;

-- ===========================================================
== ALERT CONFIGURATION FOR REFRESH FAILURES
== ===========================================================

-- Create alert for dashboard refresh failures
CREATE OR REPLACE ALERT dashboard_refresh_alert
    WAREHOUSE = REPORTING_WH
    SCHEDULE = '5 MINUTE'
IF (EXISTS (
    SELECT 1
    FROM snowflake.account_usage.task_history
    WHERE state = 'FAILED'
        AND scheduled_time >= DATEADD(minute, -5, CURRENT_TIMESTAMP())
        AND database_name = 'STREAMPULSE'
        AND schema_name = 'MARTS'
))
THEN
    CALL SYSTEM$SEND_EMAIL(
        'dashboard_alerts',
        'data-team@streampulse.com',
        'Dashboard Refresh Failure Alert',
        'One or more dashboard materialized views failed to refresh. Please investigate.'
    );

-- Enable the alert
ALTER ALERT dashboard_refresh_alert RESUME;



## Bonus Challenge
Embedded Analytics - "My Stats" Widget
-- User's personal engagement stats
WITH user_stats AS (
  SELECT 
    u.user_id,
    u.full_name,
    COUNT(DISTINCT e.engagement_id) as total_views_lifetime,
    COUNT(DISTINCT CASE WHEN e.date >= DATEADD(day, -30, CURRENT_DATE()) 
                       THEN e.engagement_id END) as views_last_30d,
    SUM(e.watch_minutes) as total_watch_minutes,
    ROUND(AVG(e.completion_pct), 1) as avg_completion_rate,
    COUNT(DISTINCT c.show_name) as unique_shows_watched,
    MODE(c.genre) as favorite_genre,
    MAX(e.date) as last_watch_date
  FROM dim_users u
  LEFT JOIN fct_engagement e ON u.user_id = e.user_id
  LEFT JOIN dim_content c ON e.content_id = c.content_id
  WHERE u.user_id = CURRENT_USER_ID()  -- Parameterized
  GROUP BY u.user_id, u.full_name
)
SELECT 
  full_name,
  total_views_lifetime,
  views_last_30d,
  total_watch_minutes,
  avg_completion_rate,
  unique_shows_watched,
  favorite_genre,
  DATEDIFF(day, last_watch_date, CURRENT_DATE()) as days_since_last_watch
FROM user_stats;


## Alerting Query - Anomaly Detection
-- DAU anomaly detection (20% drop)
WITH daily_dau AS (
  SELECT 
    date,
    COUNT(DISTINCT user_id) as dau,
    AVG(COUNT(DISTINCT user_id)) OVER (ORDER BY date ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING) as avg_dau_7day
  FROM fct_engagement
  WHERE date >= DATEADD(day, -14, CURRENT_DATE())
  GROUP BY date
)
SELECT 
  date,
  dau,
  avg_dau_7day,
  ROUND(((dau - avg_dau_7day) / avg_dau_7day) * 100, 1) as pct_change,
  CASE 
    WHEN ((dau - avg_dau_7day) / avg_dau_7day) <= -0.20 
    THEN 'CRITICAL: DAU dropped >20%'
    WHEN ((dau - avg_dau_7day) / avg_dau_7day) <= -0.10 
    THEN 'WARNING: DAU dropped 10-20%'
    ELSE 'NORMAL'
  END as alert_level
FROM daily_dau
WHERE date = CURRENT_DATE()
  AND ((dau - avg_dau_7day) / avg_dau_7day) <= -0.10;


## Data App Spec - Streamlit Genre Explorer
# Streamlit app for genre performance exploration
"""
import streamlit as st
import pandas as pd
import plotly.express as px
from snowflake.snowpark import Session

# App title
st.title("🎬 Genre Performance Explorer")
st.markdown("Interactive analysis of content performance by genre")

# Sidebar filters
st.sidebar.header("Filters")
date_range = st.sidebar.date_input(
    "Date Range",
    value=[pd.to_datetime("2026-01-01"), pd.to_datetime("2026-02-17")]
)

selected_genres = st.sidebar.multiselect(
    "Genres",
    options=["Drama", "Comedy", "Action", "Documentary", "Sci-Fi"],
    default=["Drama", "Comedy", "Action"]
)

min_views = st.sidebar.slider("Minimum Views", 100, 10000, 1000)

# Query data
@st.cache_data
def load_genre_data(start_date, end_date, genres, min_views):
    query = f"""
    SELECT 
        c.genre,
        c.show_name,
        COUNT(e.engagement_id) as views,
        COUNT(DISTINCT e.user_id) as unique_viewers,
        AVG(e.completion_pct) as completion_rate,
        AVG(e.watch_minutes) as avg_watch_time
    FROM fct_engagement e
    JOIN dim_content c ON e.content_id = c.content_id
    WHERE e.date BETWEEN '{start_date}' AND '{end_date}'
        AND c.genre IN ({','.join(["'" + g + "'" for g in genres])})
    GROUP BY c.genre, c.show_name
    HAVING views >= {min_views}
    """
    # Execute query and return DataFrame
    return pd.read_sql(query)

df = load_genre_data(date_range[0], date_range[1], selected_genres, min_views)

# Tabs for different visualizations
tab1, tab2, tab3 = st.tabs(["Overview", "Genre Comparison", "Show Details"])

with tab1:
    col1, col2, col3 = st.columns(3)
    with col1:
        st.metric("Total Views", f"{df['views'].sum():,}")
    with col2:
        st.metric("Unique Viewers", f"{df['unique_viewers'].sum():,}")
    with col3:
        st.metric("Avg Completion", f"{df['completion_rate'].mean():.1f}%")
    
    # Views by genre
    fig = px.bar(df.groupby('genre')['views'].sum().reset_index(), 
                 x='genre', y='views', title="Views by Genre")
    st.plotly_chart(fig)

with tab2:
    # Scatter plot: Completion Rate vs Views
    fig = px.scatter(df, x='views', y='completion_rate', 
                     color='genre', size='unique_viewers',
                     hover_data=['show_name'],
                     title="Completion Rate vs Views by Genre")
    st.plotly_chart(fig)

with tab3:
    # Show leaderboard
    st.dataframe(
        df.sort_values('views', ascending=False)
          .head(20)[['show_name', 'genre', 'views', 'unique_viewers', 'completion_rate']]
    )
"""


