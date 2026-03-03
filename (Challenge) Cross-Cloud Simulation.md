(Challenge) Cross-Cloud Simulation

Author: Sammy Ndzelen
Date: 03.03.2026



## Part 1: Lock-in Inventory
# Step 1: Categorize Components

============================================================================================================
| Component                | Category    | Lock-in Severity | Databricks Equivalent      | Migration Effort |
============================================================================================================
| Snowpipe                 | Ingestion   | High (3)         | Auto Loader                | 160 hours        |
| COPY INTO                | Loading     | Low (1)          | COPY INTO (Spark)          | 40 hours         |
| Snowpark (Python)        | Processing  | High (3)         | Databricks Notebooks       | 200 hours        |
| Snowflake Tasks          | Scheduling  | High (3)         | Airflow/Delta Live Tables  | 120 hours        |
| Snowflake Streams        | CDC         | High (3)         | Delta Live Tables/CDF      | 160 hours        |
| FLATTEN / VARIANT        | SQL         | Medium (2)       | explode(), from_json()     | 240 hours        |
| QUALIFY                  | SQL         | Medium (2)       | ROW_NUMBER() + WHERE       | 80 hours         |
| Dynamic Data Masking     | Security    | High (3)         | Unity Catalog Dynamic Views| 120 hours        |
| Row Access Policies      | Security    | High (3)         | Unity Catalog Row Filters  | 120 hours        |
| Data Sharing (3 partners)| Collaboration| High (3)        | Delta Sharing              | 200 hours        |
| Time Travel (90 days)    | Recovery    | Medium (2)       | Delta Time Travel          | 40 hours         |
| Micro-partitions         | Storage     | Medium (2)       | Delta File Management      | 80 hours         |
| Snowflake Marketplace    | Data        | Low (1)          | Databricks Marketplace     | 40 hours         |
============================================================================================================


## Step 2: Risk Score Calculation
Lock-in Score Formula:
Score = (High-severity items × 3) + (Medium × 2) + (Low × 1)

Count:
- High severity: 7 items (Snowpipe, Snowpark, Tasks, Streams, Data Masking, 
                       Row Policies, Data Sharing)
- Medium severity: 5 items (FLATTEN, QUALIFY, Time Travel, Micro-partitions, 
                            COPY INTO)
- Low severity: 2 items (COPY INTO, Marketplace)

Calculation:
(7 × 3) + (5 × 2) + (2 × 1) = 21 + 10 + 2 = 33

StreamPulse Lock-in Score: 33 (HIGH lock-in)



## Part 2: Replication Architecture
# Step 1: Data Tiering
====================================================================================================
| Tier         | Tables                       | Size   | RPO   | RTO   | Replication Target      |
====================================================================================================
| Critical     | Dashboard tables, revenue,    | 15 TB  | 15 min| 5 min | Snowflake EU replica   |
|              | customer 360, subscriptions  |        |       |       |                        |
| Important    | Analytics, feature store,    | 25 TB  | 1 hour| 30 min| Snowflake EU replica   |
|              | aggregated metrics           |        |       |       |                        |
| Portable     | RAW events, staging tables,  | 30 TB  | 4 hours| 2 hours| S3 (Delta/Parquet)    |
|              | intermediate transforms      |        |       |       |                        |
| Archive      | Historical logs, old exports,| 10 TB  | 24 hrs| 24 hrs| S3 Glacier             |
|              | deprecated tables            |        |       |       |                        |
====================================================================================================

## Step 2: Architecture Diagram
┌─────────────────────────────────────────────────────────────────────────────────┐
│ STREAMPULSE MULTI-TIER REPLICATION ARCHITECTURE                                  │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                   │
│  ┌───────────────────────────────────────────────────────────────────────────┐  │
│  │ PRIMARY: Snowflake (AWS us-east-1)                                         │  │
│  │ ├── Critical tier (15 TB): real-time serving                               │  │
│  │ ├── Important tier (25 TB): analytics                                      │  │
│  │ ├── Portable tier (30 TB): raw + staging                                   │  │
│  │ └── Archive tier (10 TB): historical                                       │  │
│  └───────────────────────────────────────────────────────────────────────────┘  │
│                                    │                                              │
│            ┌───────────────────────┼───────────────────────┐                    │
│            ▼                       ▼                       ▼                    │
│  ┌───────────────────┐   ┌───────────────────┐   ┌───────────────────┐         │
│  │ REPLICA 1:        │   │ REPLICA 2:        │   │ ESCAPE HATCH:     │         │
│  │ Snowflake (EU)    │   │ Snowflake (US)    │   │ S3 us-east-1      │         │
│  │ ├── Critical:     │   │ ├── Read replica  │   │ ├── Portable:     │         │
│  │ │   15-min refresh│   │ │   for BI workloads│ │ │   Parquet export │         │
│  │ ├── Important:    │   │ └── DR standby    │   │ │   every 4 hours  │         │
│  │ │   hourly refresh│   └───────────────────┘   │ ├── Archive:      │         │
│  │ └── DR failover   │                           │ │   Parquet →     │         │
│  └───────────────────┘                           │ │   S3 Glacier    │         │
│                                                    │ └── FORMAT:      │         │
│                                                    │   Delta Lake     │         │
│                                                    └───────────────────┘         │
│                                                           │                      │
│                                                           ▼                      │
│                                          ┌────────────────────────────┐         │
│                                          │ FUTURE STATE: Databricks   │         │
│                                          │ (if migration approved)    │         │
│                                          │ └── Read from S3 escape    │         │
│                                          │     hatch (zero data move) │         │
│                                          └────────────────────────────┘         │
└─────────────────────────────────────────────────────────────────────────────────┘


## Step 3: Snowflake SQL Implementation
-- 1. Enable replication to EU account
USE ROLE ACCOUNTADMIN;

-- Create replication group for critical and important tiers
CREATE OR REPLACE REPLICATION GROUP streampulse_prod_repl
  OBJECT_TYPES = DATABASES, ROLES, USERS, WAREHOUSES
  ALLOWED_DATABASES = streampulse_prod, streampulse_staging
  ALLOWED_ACCOUNTS = 'orgname.eu_account';

-- 2. Refresh tasks for each tier
USE ROLE SYSADMIN;
USE DATABASE streampulse_prod;
USE SCHEMA audit;

-- Create task for critical tier refresh (every 15 minutes)
CREATE OR REPLACE TASK refresh_critical_tier
  WAREHOUSE = ETL_WH
  SCHEDULE = '15 MINUTE'
AS
  -- Refresh critical tables via replication
  SELECT SYSTEM$REFRESH_REPLICATION_GROUP('streampulse_prod_repl');

-- Create task for important tier refresh (hourly)
CREATE OR REPLACE TASK refresh_important_tier
  WAREHOUSE = ETL_WH
  SCHEDULE = '60 MINUTE'
AS
  -- Refresh important tables
  SELECT SYSTEM$REFRESH_REPLICATION_GROUP('streampulse_prod_repl');

-- 3. Export to S3 (escape hatch) - Delta format
CREATE OR REPLACE STORAGE INTEGRATION s3_export
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'S3'
  ENABLED = TRUE
  STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::123456789012:role/snowflake-export'
  STORAGE_ALLOWED_LOCATIONS = ('s3://sp-escape-hatch/portable/', 's3://sp-escape-hatch/archive/');

CREATE OR REPLACE STAGE s3_export_stage
  STORAGE_INTEGRATION = s3_export
  URL = 's3://sp-escape-hatch/'
  FILE_FORMAT = (TYPE = PARQUET);

-- Stored procedure to export portable tier tables
CREATE OR REPLACE PROCEDURE export_portable_tier()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
  tables CURSOR FOR
    SELECT table_schema, table_name 
    FROM information_schema.tables 
    WHERE table_schema IN ('RAW', 'STAGING')
      AND table_name NOT LIKE '%archive%';
BEGIN
  FOR t IN tables DO
    EXECUTE IMMEDIATE 'COPY INTO @s3_export_stage/portable/' || t.table_schema || '/' || t.table_name || '/'
      FROM ' || t.table_schema || '.' || t.table_name || '
      FILE_FORMAT = (TYPE = PARQUET)
      HEADER = TRUE
      OVERWRITE = TRUE;
  END FOR;
  RETURN 'Portable tier export completed';
END;
$$;

-- Scheduled task for portable tier export
CREATE OR REPLACE TASK export_portable_tier_task
  WAREHOUSE = ETL_WH
  SCHEDULE = '240 MINUTE'
AS
  CALL export_portable_tier();

-- Archive tier export (daily, with compression)
CREATE OR REPLACE PROCEDURE export_archive_tier()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
  COPY INTO @s3_export_stage/archive/historical/
  FROM (
    SELECT * FROM streampulse_prod.analytics.historical_events
    WHERE event_date < DATEADD(year, -2, CURRENT_DATE())
  )
  FILE_FORMAT = (TYPE = PARQUET, COMPRESSION = SNAPPY)
  HEADER = TRUE;
  
  RETURN 'Archive export completed';
END;
$$;

-- 4. Failover group configuration
CREATE OR REPLACE FAILOVER GROUP streampulse_failover
  OBJECT_TYPES = DATABASES, ROLES, USERS, WAREHOUSES
  ALLOWED_DATABASES = streampulse_prod
  ALLOWED_ACCOUNTS = 'orgname.eu_account';

-- Enable automatic failover for critical tier
ALTER FAILOVER GROUP streampulse_failover
  SET REPLICATION_SCHEDULE = '10 MINUTE'
  ENABLE_AUTO_FAILOVER = TRUE;



## Part 3: Migration Planning
# Step 1: Phased Migration Plan

====================================================================================================
| PHASE 1 — Foundation (Weeks 1-2)                                                                 |
====================================================================================================
| Goal: Set up Databricks workspace, configure storage, establish connectivity                     |
|                                                                                                  |
| Tasks:                                                                                           |
| □ Provision Databricks workspace in AWS us-east-1                                                |
| □ Configure S3 buckets for Delta Lake (same as escape hatch location)                           |
| □ Set up Unity Catalog metastore with external location                                          |
| □ Create initial Databricks clusters (Jobs, SQL, Interactive)                                    |
| □ Establish network connectivity and firewall rules                                              |
| □ Configure identity federation (SSO) for user access                                            |
| □ Install and configure required libraries (dbt, Airflow plugins)                                |
|                                                                                                  |
| Success criteria:                                                                                 |
| - Databricks workspace accessible to all team members                                            |
| - Unity Catalog configured with external S3 location                                             |
| - Basic Spark jobs can read/write to S3 location                                                 |
| - Airflow can trigger Databricks jobs                                                            |
====================================================================================================

====================================================================================================
| PHASE 2 — Data Migration (Weeks 3-6)                                                              |
====================================================================================================
| Goal: Move data from Snowflake to Delta Lake with validation                                      |
|                                                                                                  |
| Tasks:                                                                                           |
| □ Create Delta Lake table schemas mirroring Snowflake curated tables                             |
| □ Develop and test export pipelines for portable tier (30 TB)                                    |
| □ Run initial full export of portable tier to S3 Delta format                                    |
| □ Validate data completeness and quality (row counts, null checks)                               |
| □ Implement incremental export for portable tier (changes since last export)                     |
| □ Begin export of important tier (25 TB) to Delta format                                         |
| □ Create data validation framework (automated comparison between sources)                        |
| □ Document data lineage from Snowflake to Delta                                                  |
|                                                                                                  |
| Success criteria:                                                                                 |
| - All portable tier data (30 TB) available in Delta format on S3                                |
| - At least 50% of important tier (12.5 TB) migrated                                              |
| - Validation framework shows <0.1% discrepancy between sources                                  |
| - Incremental exports working correctly                                                          |
====================================================================================================

====================================================================================================
| PHASE 3 — Workload Migration (Weeks 7-12)                                                         |
====================================================================================================
| Goal: Migrate queries, pipelines, and BI connections to Databricks                               |
|                                                                                                  |
| Tasks:                                                                                           |
| □ Convert Snowflake SQL to Spark SQL (focus on FLATTEN, QUALIFY patterns)                        |
| □ Migrate dbt models from Snowflake to Databricks dialect                                        |
| □ Rewrite Snowpark Python code to Databricks notebooks                                            |
| □ Convert Snowpipe streams to Auto Loader streaming                                               |
| □ Reimplement Snowflake Tasks as Airflow DAGs or Delta Live Tables                               |
| □ Recreate RBAC in Unity Catalog (15 roles, column/row policies)                                 |
| □ Migrate Tableau connections from Snowflake to Databricks SQL                                   |
| □ Set up Delta Sharing for external partners (replace Snowflake Sharing)                         |
| □ Run parallel workloads (Snowflake + Databricks) for validation                                 |
|                                                                                                  |
| Success criteria:                                                                                 |
| - 100% of dbt models running on Databricks with same results                                     |
| - All Tableau dashboards connected to Databricks and rendering correctly                         |
| - 3 external partners receiving data via Delta Sharing                                           |
| - Unity Catalog security policies match Snowflake exactly                                         |
| - Query performance within 20% of Snowflake baseline                                              |
====================================================================================================

====================================================================================================
| PHASE 4 — Cutover & Decommission (Weeks 13-16)                                                    |
====================================================================================================
| Goal: Switch production, decommission Snowflake, establish runbooks                               |
|                                                                                                  |
| Tasks:                                                                                           |
| □ Perform full dress rehearsal cutover (weekend)                                                 |
| □ Switch production BI tools to point exclusively to Databricks                                  |
| □ Redirect Airflow pipelines to Databricks (disable Snowflake tasks)                             |
| □ Monitor performance and error rates for 48 hours                                               |
| □ Decommission Snowflake warehouses and databases                                                |
| □ Extract final audit logs from Snowflake for compliance                                         |
| □ Update all documentation and runbooks                                                          |
| □ Conduct team training on Databricks operations                                                 |
| □ Establish Databricks monitoring and alerting                                                   |
|                                                                                                  |
| Success criteria:                                                                                 |
| - Zero data loss during cutover                                                                   |
| - All production queries running on Databricks                                                   |
| - No critical incidents in first 72 hours                                                        |
| - Snowflake account suspended                                                                     |
| - Team confident in new platform                                                                  |
====================================================================================================


##  Step 2: Migration Cost Model

====================================================================================================
| Cost Category          | Calculation                                 | Amount (USD)             |
====================================================================================================
| Data export            | 80TB export to S3 (same region, free)      | $0                        |
| Data transform         | Convert to Delta format (compute)           | $15,000                   |
| SQL rewriting         | 1,200 queries × 4 hours × $150/hr           | $720,000                  |
| Pipeline migration    | Snowpipe → Auto Loader, Tasks → Airflow    | $180,000                  |
| Security setup        | Recreate RBAC in Unity Catalog              | $60,000                   |
| BI reconnection       | Tableau/Looker → Databricks SQL             | $40,000                   |
| Testing               | End-to-end validation (8 weeks)             | $120,000                  |
| Dual-running          | 3 months × ($47K + $35K)                     | $246,000                  |
| Team training         | 80 users × 2 days × $500/day                | $80,000                   |
| Contract penalty      | Early termination (2 years remaining)       | $500,000                  |
| Contingency (15%)     | 15% of above                                 | $282,000                  |
====================================================================================================
| TOTAL MIGRATION COST  |                                              | $2,243,000                |
====================================================================================================


## Step 3: Decision Matrix
============================================================================================================================
| Criteria (Weight)     | Stay on Snowflake          | Migrate to Databricks         | Hybrid (both)                  |
============================================================================================================================
| Annual cost (30%)     | $564,000 ($47K × 12)       | $420,000 ($35K × 12)          | $984,000 ($47K+$35K × 12)     |
|                       | Score: 8/10                | Score: 10/10                   | Score: 4/10                    |
|                       | Weighted: 2.4               | Weighted: 3.0                  | Weighted: 1.2                   |
|-----------------------|----------------------------|--------------------------------|---------------------------------|
| Lock-in risk (20%)    | Very High (33 score)       | Medium (Databricks lock-in)   | Low (diversified)              |
|                       | Score: 3/10                | Score: 6/10                   | Score: 9/10                    |
|                       | Weighted: 0.6               | Weighted: 1.2                  | Weighted: 1.8                   |
|-----------------------|----------------------------|--------------------------------|---------------------------------|
| Feature richness (15%)| Excellent (mature)         | Very Good (growing fast)      | Best of both                   |
|                       | Score: 10/10                | Score: 8/10                   | Score: 9/10                    |
|                       | Weighted: 1.5               | Weighted: 1.2                  | Weighted: 1.35                  |
|-----------------------|----------------------------|--------------------------------|---------------------------------|
| Migration effort (15%)| 0 (no migration)           | Very High ($2.2M, 4 months)   | Moderate (half migration)      |
|                       | Score: 10/10                | Score: 3/10                   | Score: 7/10                    |
|                       | Weighted: 1.5               | Weighted: 0.45                 | Weighted: 1.05                  |
|-----------------------|----------------------------|--------------------------------|---------------------------------|
| Team productivity (10%)| Current state (familiar)   | Learning curve, then higher   | Complex, two platforms         |
|                       | Score: 7/10                | Score: 8/10                   | Score: 5/10                    |
|                       | Weighted: 0.7               | Weighted: 0.8                  | Weighted: 0.5                   |
|-----------------------|----------------------------|--------------------------------|---------------------------------|
| Future flexibility (10%)| Low (locked to Snowflake) | Medium (Databricks ecosystem) | High (open formats, portable)  |
|                       | Score: 3/10                | Score: 6/10                   | Score: 9/10                    |
|                       | Weighted: 0.3               | Weighted: 0.6                  | Weighted: 0.9                   |
============================================================================================================================
| WEIGHTED SCORE        | 7.0                        | 7.25                          | 6.8                            |
============================================================================================================================


## Recommendation
╔══════════════════════════════════════════════════════════════════════════════════════════════╗
║                                                                                                ║
║   RECOMMENDATION: STAY ON SNOWFLAKE + IMPLEMENT HYBRID ESCAPE HATCH                           ║
║                                                                                                ║
║   Rationale:                                                                                   ║
║   ──────────────────────────────────────────────────────────────────────────                   ║
║   • Contract penalty ($500K) makes immediate migration financially unattractive                ║
║   • Migration cost ($2.2M) and effort (4 months) exceed near-term benefits                     ║
║   • Lock-in score (33) is high, but can be mitigated with open format exports                  ║
║   • Hybrid approach scores lowest due to dual-running costs                                    ║
║                                                                                                ║
║   Action Plan:                                                                                 ║
║   ──────────────────────────────────────────────────────────────────────────                   ║
║   1. Implement escape hatch immediately (S3 Delta exports)                                     ║
║   2. Convert portable tier to Iceberg format for ultimate portability                          ║
║   3. Use remaining 2 years to gradually migrate workloads to open formats                      ║
║   4. Re-evaluate at contract end (2026) with clean data in open format                         ║
║   5. Maintain multi-cloud optionality without dual-running                                     ║
║                                                                                                ║
╚══════════════════════════════════════════════════════════════════════════════════════════════╝


## Part 4: Portable Architecture Design
# Design Principles Implementation
====================================================================================================
| Principle          | Current State                         | Target State                      |
====================================================================================================
| Open formats       | Snowflake micro-partitions            | Delta Lake + Iceberg dual-format  |
|                    | (proprietary, lock-in)                | (open, portable)                   |
|--------------------|---------------------------------------|------------------------------------|
| Standard SQL       | FLATTEN, VARIANT, QUALIFY             | ANSI SQL + Spark SQL               |
|                    | (Snowflake-specific)                  | (portable)                         |
|--------------------|---------------------------------------|------------------------------------|
| dbt                | Some dbt, some Snowflake Tasks        | dbt for all transformations        |
|                    | (mixed orchestration)                 | (single source of truth)           |
|--------------------|---------------------------------------|------------------------------------|
| Airflow            | Mix of Airflow + Snowflake Tasks      | Airflow for all orchestration      |
|                    | (split orchestration)                  | (vendor-neutral)                   |
|--------------------|---------------------------------------|------------------------------------|
| Abstraction        | Direct Snowflake connections          | JDBC/ODBC abstraction layer        |
|                    | (tightly coupled)                     | (swap backends via config)         |
|--------------------|---------------------------------------|------------------------------------|
| Cloud-agnostic     | S3 only (AWS lock-in)                 | Multi-cloud ready (S3/GCS/ADLS)    |
|                    |                                       | using Iceberg                      |
====================================================================================================

### Required Changes

╔══════════════════════════════════════════════════════════════════════════════════════════════╗
║ ║
║ STREAMPULSE PORTABLE ARCHITECTURE TRANSFORMATION ║
║ ║
╠══════════════════════════════════════════════════════════════════════════════════════════════╣
║ ║
║ Change 1: Implement Iceberg Tables ║
║ ────────────────────────────────────────────────────────────────────────── ║
║ • Convert all portable tier tables to Snowflake Iceberg tables ║
║ • Store data in S3 with Iceberg format (metadata in Snowflake) ║
║ • Enable future reads by any Iceberg-compatible engine ║
║ ║
║ SQL: ║
║ CREATE ICEBERG TABLE streampulse_prod.raw.events_iceberg ( ║
║ event_id STRING, ║
║ user_id STRING, ║
║ event_timestamp TIMESTAMP ║
║ ) ║
║ EXTERNAL_VOLUME = 's3_iceberg_volume' ║
║ CATALOG = 'SNOWFLAKE' ║
║ BASE_LOCATION = 'raw/events/'; ║
║ ║
╠══════════════════════════════════════════════════════════════════════════════════════════════╣
║ ║
║ Change 2: Rewrite SQL to ANSI Standards ║
║ ────────────────────────────────────────────────────────────────────────── ║
║ • Replace FLATTEN with LATERAL VIEW EXPLODE in Spark SQL ║
║ • Replace QUALIFY with subqueries or CTEs ║
║ • Use standard JSON functions (JSON_EXTRACT_PATH_TEXT) ║
║ ║
║ Before (Snowflake): ║
║ SELECT * FROM events ║
║ QUALIFY ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY timestamp DESC) = 1; ║
║ ║
║ After (ANSI): ║
║ WITH ranked AS ( ║
║ SELECT *, ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY timestamp DESC) AS rn ║
║ FROM events ║
║ ) SELECT * FROM ranked WHERE rn = 1; ║
║ ║
╠══════════════════════════════════════════════════════════════════════════════════════════════╣
║ ║
║ Change 3: Migrate All Orchestration to Airflow ║
║ ────────────────────────────────────────────────────────────────────────── ║
║ • Convert all Snowflake Tasks to Airflow DAGs ║
║ • Use Airflow operators for both Snowflake and Databricks ║
║ • Centralize monitoring and alerting ║
║ ║
╠══════════════════════════════════════════════════════════════════════════════════════════════╣
║ ║
║ Change 4: Create Database Abstraction Layer ║
║ ────────────────────────────────────────────────────────────────────────── ║
║ • Implement connection pooling with backend switching ║
║ • Use environment variables to control target database ║
║ • Create unified metrics layer that works across platforms ║
║ ║
║ Python Example: ║
║ def get_connection(): ║
║ if config.DB_BACKEND == 'snowflake': ║
║ return snowflake.connector.connect(...) ║
║ elif config.DB_BACKEND == 'databricks': ║
║ return databricks.sql.connect(...) ║
║ ║
╚══════════════════════════════════════════════════════════════════════════════════════════════╝



---

## Bonus Challenge: Apache Iceberg Analysis
╔══════════════════════════════════════════════════════════════════════════════════════════════╗
║ ║
║ APACHE ICEBERG VS DELTA LAKE: COMPARATIVE ANALYSIS ║
║ ║
╠══════════════════════════════════════════════════════════════════════════════════════════════╣
║ ║
║ What advantages does Iceberg have over Delta Lake?  ║
║ ────────────────────────────────────────────────────────────────────────── ║
║ ║
║ 1. Engine Agnostic Architecture ║
║ • Iceberg was designed as a pure specification, not tied to any engine  ║
║ • Native support in Spark, Flink, Trino, Presto, Dremio, Snowflake, Athena  ║
║ • Delta Lake is optimized for Spark/Databricks ecosystem  ║
║ ║
║ 2. REST Catalog Specification ║
║ • Standardized HTTP-based catalog API  ║
║ • Any engine can work with any REST-compatible catalog  ║
║ • Decouples storage, compute, and catalog layers  ║
║ ║
║ 3. Community Governance ║
║ • Apache Software Foundation governance (30+ contributing companies)  ║
║ • No single vendor controls the format direction  ║
║ • Delta Lake roadmap primarily influenced by Databricks  ║
║ ║
║ 4. Metadata Scalability ║
║ • Hierarchical metadata structure scales to billions of files  ║
║ • Manifest-based pruning for faster query planning  ║
║ • Column-level statistics in manifest files  ║
║ ║
║ 5. Hidden Partitioning ║
║ • Partition evolution without rewriting data  ║
║ • Queries don't need to reference partition columns  ║
║ ║
╠══════════════════════════════════════════════════════════════════════════════════════════════╣
║ ║
║ Which warehouse platforms support Iceberg natively?  ║
║ ────────────────────────────────────────────────────────────────────────── ║
║ ║
║ • Snowflake: Iceberg tables with Snowflake catalog or external catalogs  ║
║ • Databricks: Via UniForm feature (Delta → Iceberg compatibility)  ║
║ • AWS Athena: Native Iceberg support  ║
║ • AWS EMR: Native Iceberg support (v6.5.0+)  ║
║ • AWS Glue: Iceberg support (Glue 3.0+) with Glue Data Catalog  ║
║ • Google BigLake: Iceberg support via BigLake Metastore  ║
║ • Oracle Autonomous AI Lakehouse: Native Iceberg support  ║
║ • Dremio: Native Iceberg support  ║
║ • StarTree: Added Iceberg support for real-time analytics  ║
║ • Trino/Presto: Native Iceberg connectors  ║
║ ║
╠══════════════════════════════════════════════════════════════════════════════════════════════╣
║ ║
║ How would using Iceberg change your migration plan? ║
║ ────────────────────────────────────────────────────────────────────────── ║
║ ║
║ Positive Impacts: ║
║ • Zero-copy migration: Data stays in Iceberg format, just switch catalogs  ║
║ • Snowflake can write Iceberg tables directly (no export needed)  ║
║ • Databricks can read Iceberg via UniForm  ║
║ • True multi-cloud readiness from day one  ║
║ ║
║ Revised Migration Timeline: ║
║ • Phase 1 (Month 1): Convert all tables to Snowflake Iceberg tables ║
║ • Phase 2 (Month 2): Set up Iceberg REST catalog (Apache Polaris)  ║
║ • Phase 3 (Month 3): Point Databricks to same Iceberg tables (read-only) ║
║ • Phase 4 (Month 4): Gradual cutover with both engines writing ║
║ • Total migration cost reduction: ~40% (from $2.2M to $1.3M) ║
║ ║
╠══════════════════════════════════════════════════════════════════════════════════════════════╣
║ ║
║ Could Iceberg be the "universal" format that eliminates storage lock-in?  ║
║ ────────────────────────────────────────────────────────────────────────── ║
║ ║
║ YES - Iceberg is emerging as the universal standard for lakehouse architectures. ║
║ ║
║ Evidence: ║
║ • All major cloud providers now support Iceberg natively  ║
║ • Competing platforms (Snowflake, Databricks) both support Iceberg  ║
║ • REST catalog specification creates vendor-neutral metadata layer  ║
║ • Oracle positions Iceberg as key to "lakehouse without compromises"  ║
║ • Industry analysts confirm Iceberg as emerging standard  ║
║ ║
║ Strategic Recommendation for StreamPulse: ║
║ ────────────────────────────────────────────────────────────────────────── ║
║ • Adopt Iceberg as primary storage format for all new tables ║
║ • Convert existing portable tier to Iceberg over next 6 months ║
║ • Use Snowflake as Iceberg catalog initially, migrate to Apache Polaris later ║
║ • Achieve true storage independence by end of 2026 ║
║ • Eliminate migration risk for future platform changes ║
║ ║
╚══════════════════════════════════════════════════════════════════════════════════════════════╝

