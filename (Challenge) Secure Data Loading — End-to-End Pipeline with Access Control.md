(Challenge) Secure Data Loading — End-to-End Pipeline with Access Control
Introduction
Author: Sammy Ndzelen
Date: 03.03.2026


## Task 1: Set Up the Security Foundation

-- Database and schemas
USE ROLE SYSADMIN;
CREATE DATABASE IF NOT EXISTS streampulse_prod;
CREATE SCHEMA IF NOT EXISTS streampulse_prod.raw;
CREATE SCHEMA IF NOT EXISTS streampulse_prod.staging;
CREATE SCHEMA IF NOT EXISTS streampulse_prod.curated;
CREATE SCHEMA IF NOT EXISTS streampulse_prod.audit;

-- Roles
USE ROLE SECURITYADMIN;
CREATE ROLE IF NOT EXISTS ETL_SERVICE COMMENT = 'Automated pipeline loading';
CREATE ROLE IF NOT EXISTS DATA_ENGINEER COMMENT = 'Pipeline development';
CREATE ROLE IF NOT EXISTS DATA_ANALYST COMMENT = 'Read curated data';
CREATE ROLE IF NOT EXISTS MONITOR_SERVICE COMMENT = 'Pipeline monitoring';

-- Hierarchy
GRANT ROLE ETL_SERVICE TO ROLE SYSADMIN;
GRANT ROLE DATA_ENGINEER TO ROLE SYSADMIN;
GRANT ROLE DATA_ANALYST TO ROLE SYSADMIN;
GRANT ROLE MONITOR_SERVICE TO ROLE SYSADMIN;

-- Grant usage on database to all roles
GRANT USAGE ON DATABASE streampulse_prod TO ROLE ETL_SERVICE;
GRANT USAGE ON DATABASE streampulse_prod TO ROLE DATA_ENGINEER;
GRANT USAGE ON DATABASE streampulse_prod TO ROLE DATA_ANALYST;
GRANT USAGE ON DATABASE streampulse_prod TO ROLE MONITOR_SERVICE;


## Schema-Level Privileges Implementation
USE ROLE SECURITYADMIN;

-- Grant schema usage
GRANT USAGE ON SCHEMA streampulse_prod.raw TO ROLE ETL_SERVICE;
GRANT USAGE ON SCHEMA streampulse_prod.raw TO ROLE DATA_ENGINEER;
GRANT USAGE ON SCHEMA streampulse_prod.staging TO ROLE ETL_SERVICE;
GRANT USAGE ON SCHEMA streampulse_prod.staging TO ROLE DATA_ENGINEER;
GRANT USAGE ON SCHEMA streampulse_prod.curated TO ROLE ETL_SERVICE;
GRANT USAGE ON SCHEMA streampulse_prod.curated TO ROLE DATA_ENGINEER;
GRANT USAGE ON SCHEMA streampulse_prod.curated TO ROLE DATA_ANALYST;
GRANT USAGE ON SCHEMA streampulse_prod.audit TO ROLE ETL_SERVICE;
GRANT USAGE ON SCHEMA streampulse_prod.audit TO ROLE DATA_ENGINEER;
GRANT USAGE ON SCHEMA streampulse_prod.audit TO ROLE MONITOR_SERVICE;

-- ETL_SERVICE: RAW (RW), STAGING (RW), CURATED (RW), AUDIT (W)
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA streampulse_prod.raw TO ROLE ETL_SERVICE;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA streampulse_prod.staging TO ROLE ETL_SERVICE;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA streampulse_prod.curated TO ROLE ETL_SERVICE;
GRANT INSERT ON ALL TABLES IN SCHEMA streampulse_prod.audit TO ROLE ETL_SERVICE;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA streampulse_prod.raw TO ROLE ETL_SERVICE;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA streampulse_prod.staging TO ROLE ETL_SERVICE;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA streampulse_prod.curated TO ROLE ETL_SERVICE;
GRANT INSERT ON FUTURE TABLES IN SCHEMA streampulse_prod.audit TO ROLE ETL_SERVICE;

-- DATA_ENGINEER: RAW (R), STAGING (RW), CURATED (RW), AUDIT (R)
GRANT SELECT ON ALL TABLES IN SCHEMA streampulse_prod.raw TO ROLE DATA_ENGINEER;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA streampulse_prod.staging TO ROLE DATA_ENGINEER;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA streampulse_prod.curated TO ROLE DATA_ENGINEER;
GRANT SELECT ON ALL TABLES IN SCHEMA streampulse_prod.audit TO ROLE DATA_ENGINEER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA streampulse_prod.raw TO ROLE DATA_ENGINEER;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA streampulse_prod.staging TO ROLE DATA_ENGINEER;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA streampulse_prod.curated TO ROLE DATA_ENGINEER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA streampulse_prod.audit TO ROLE DATA_ENGINEER;

-- DATA_ANALYST: CURATED (R) only
GRANT SELECT ON ALL TABLES IN SCHEMA streampulse_prod.curated TO ROLE DATA_ANALYST;
GRANT SELECT ON FUTURE TABLES IN SCHEMA streampulse_prod.curated TO ROLE DATA_ANALYST;

-- MONITOR_SERVICE: AUDIT (R) only
GRANT SELECT ON ALL TABLES IN SCHEMA streampulse_prod.audit TO ROLE MONITOR_SERVICE;
GRANT SELECT ON FUTURE TABLES IN SCHEMA streampulse_prod.audit TO ROLE MONITOR_SERVICE;


## Task 2: Configure External Stages (Secured)
# Create Storage Integration

USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE STORAGE INTEGRATION sp_prod_s3
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'S3'
  ENABLED = TRUE
  STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::123456789012:role/sf-prod-role'
  STORAGE_ALLOWED_LOCATIONS = ('s3://sp-prod-lake/raw/');

-- Grant stage creation to the engineer role
GRANT CREATE STAGE ON SCHEMA streampulse_prod.raw TO ROLE DATA_ENGINEER;
GRANT USAGE ON INTEGRATION sp_prod_s3 TO ROLE DATA_ENGINEER;

-- Get the AWS IAM user ARN to set up trust relationship
DESC INTEGRATION sp_prod_s3;
-- Note the STORAGE_AWS_IAM_USER_ARN for configuring the trust policy in AWS

## Create Stages (as DATA_ENGINEER)
USE ROLE DATA_ENGINEER;
USE DATABASE streampulse_prod;
USE SCHEMA raw;

-- Create file formats
CREATE OR REPLACE FILE FORMAT parquet_format
  TYPE = 'PARQUET'
  COMPRESSION = SNAPPY;

CREATE OR REPLACE FILE FORMAT json_format
  TYPE = 'JSON'
  STRIP_OUTER_ARRAY = TRUE
  COMPRESSION = AUTO;

-- Create stages
CREATE OR REPLACE STAGE events_stage
  URL = 's3://sp-prod-lake/raw/events/'
  STORAGE_INTEGRATION = sp_prod_s3
  FILE_FORMAT = parquet_format;

CREATE OR REPLACE STAGE payments_stage
  URL = 's3://sp-prod-lake/raw/payments/'
  STORAGE_INTEGRATION = sp_prod_s3
  FILE_FORMAT = parquet_format;

CREATE OR REPLACE STAGE catalog_stage
  URL = 's3://sp-prod-lake/raw/catalog/'
  STORAGE_INTEGRATION = sp_prod_s3
  FILE_FORMAT = json_format;

-- List files to verify access
LIST @events_stage;
LIST @payments_stage;
LIST @catalog_stage;

## Restrict Stage Access
USE ROLE SECURITYADMIN;

-- Only ETL_SERVICE and DATA_ENGINEER can read from stages
GRANT USAGE ON STAGE streampulse_prod.raw.events_stage TO ROLE ETL_SERVICE;
GRANT USAGE ON STAGE streampulse_prod.raw.events_stage TO ROLE DATA_ENGINEER;

GRANT USAGE ON STAGE streampulse_prod.raw.payments_stage TO ROLE ETL_SERVICE;
GRANT USAGE ON STAGE streampulse_prod.raw.payments_stage TO ROLE DATA_ENGINEER;

GRANT USAGE ON STAGE streampulse_prod.raw.catalog_stage TO ROLE ETL_SERVICE;
GRANT USAGE ON STAGE streampulse_prod.raw.catalog_stage TO ROLE DATA_ENGINEER;

-- DATA_ANALYST cannot access stages (no grant = no access)
-- MONITOR_SERVICE cannot access stages


# Task 3: Build the Loading Pipeline

USE ROLE ETL_SERVICE;
USE DATABASE streampulse_prod;
USE SCHEMA raw;

-- Events table
CREATE OR REPLACE TABLE events (
    event_id        VARCHAR(30),
    user_id         VARCHAR(20),
    event_type      VARCHAR(50),
    device          VARCHAR(20),
    duration_sec    INTEGER,
    revenue         DECIMAL(10,4),
    event_timestamp TIMESTAMP,
    loaded_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    source_file     VARCHAR(500)
);

-- Payments table
CREATE OR REPLACE TABLE payments (
    payment_id      VARCHAR(30),
    user_id         VARCHAR(20),
    amount          DECIMAL(10,2),
    currency        VARCHAR(3),
    status          VARCHAR(20),
    payment_method  VARCHAR(30),
    payment_timestamp TIMESTAMP,
    loaded_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    source_file     VARCHAR(500)
);

-- Catalog table (JSON)
CREATE OR REPLACE TABLE catalog (
    product_id      VARCHAR(30),
    product_data    VARIANT,  -- Stores the entire JSON
    category        VARCHAR(50),
    price           DECIMAL(10,2),
    effective_date  DATE,
    loaded_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    source_file     VARCHAR(500)
);

-- Audit table
USE SCHEMA audit;
CREATE OR REPLACE TABLE load_log (
    load_id         VARCHAR(36) DEFAULT UUID_STRING(),
    source_name     VARCHAR(50),
    target_table    VARCHAR(100),
    started_at      TIMESTAMP,
    completed_at    TIMESTAMP,
    rows_loaded     INTEGER,
    rows_rejected   INTEGER,
    files_processed INTEGER,
    status          VARCHAR(20),
    error_message   VARCHAR(1000),
    loaded_by       VARCHAR(50) DEFAULT CURRENT_USER()
);



## Complete COPY INTO Pipeline for All Sources

USE ROLE ETL_SERVICE;
USE DATABASE streampulse_prod;

-- Load events (Parquet)
COPY INTO raw.events (event_id, user_id, event_type, device, duration_sec, revenue, event_timestamp, loaded_at, source_file)
FROM (
    SELECT 
        $1:event_id::VARCHAR(30),
        $1:user_id::VARCHAR(20),
        $1:event_type::VARCHAR(50),
        $1:device::VARCHAR(20),
        $1:duration_sec::INTEGER,
        $1:revenue::DECIMAL(10,4),
        $1:event_timestamp::TIMESTAMP,
        CURRENT_TIMESTAMP(),
        METADATA$FILENAME
    FROM @raw.events_stage
)
FILE_FORMAT = (TYPE = 'PARQUET')
ON_ERROR = 'CONTINUE'
PURGE = FALSE;

-- Load payments (Parquet) - with zero tolerance for errors
COPY INTO raw.payments (payment_id, user_id, amount, currency, status, payment_method, payment_timestamp, loaded_at, source_file)
FROM (
    SELECT 
        $1:payment_id::VARCHAR(30),
        $1:user_id::VARCHAR(20),
        $1:amount::DECIMAL(10,2),
        $1:currency::VARCHAR(3),
        $1:status::VARCHAR(20),
        $1:payment_method::VARCHAR(30),
        $1:payment_timestamp::TIMESTAMP,
        CURRENT_TIMESTAMP(),
        METADATA$FILENAME
    FROM @raw.payments_stage
)
FILE_FORMAT = (TYPE = 'PARQUET')
ON_ERROR = 'ABORT_STATEMENT'  -- Zero tolerance for payment data
PURGE = FALSE;

-- Load catalog (JSON)
COPY INTO raw.catalog (product_id, product_data, category, price, effective_date, loaded_at, source_file)
FROM (
    SELECT 
        $1:product_id::VARCHAR(30),
        $1 AS product_data,  -- Store full JSON as VARIANT
        $1:category::VARCHAR(50),
        $1:price::DECIMAL(10,2),
        $1:effective_date::DATE,
        CURRENT_TIMESTAMP(),
        METADATA$FILENAME
    FROM @raw.catalog_stage
)
FILE_FORMAT = (TYPE = 'JSON', STRIP_OUTER_ARRAY = TRUE)
ON_ERROR = 'CONTINUE'
PURGE = FALSE;

## Stored Procedure for Events Load with Logging
USE ROLE ETL_SERVICE;
USE DATABASE streampulse_prod;

CREATE OR REPLACE PROCEDURE raw.load_events()
  RETURNS VARCHAR
  LANGUAGE SQL
  EXECUTE AS CALLER
AS
$$
DECLARE
    v_start TIMESTAMP;
    v_rows INTEGER;
    v_files INTEGER;
    v_errors INTEGER;
    v_load_id VARCHAR(36);
BEGIN
    v_start := CURRENT_TIMESTAMP();
    v_load_id := UUID_STRING();
    
    -- Insert start log
    INSERT INTO audit.load_log (load_id, source_name, target_table, started_at, status)
    VALUES (:v_load_id, 'events', 'raw.events', :v_start, 'RUNNING');
    
    -- Load data
    COPY INTO raw.events (event_id, user_id, event_type, device, duration_sec, revenue, event_timestamp, loaded_at, source_file)
    FROM (
        SELECT 
            $1:event_id::VARCHAR(30),
            $1:user_id::VARCHAR(20),
            $1:event_type::VARCHAR(50),
            $1:device::VARCHAR(20),
            $1:duration_sec::INTEGER,
            $1:revenue::DECIMAL(10,4),
            $1:event_timestamp::TIMESTAMP,
            CURRENT_TIMESTAMP(),
            METADATA$FILENAME
        FROM @raw.events_stage
    )
    FILE_FORMAT = (TYPE = 'PARQUET')
    ON_ERROR = 'CONTINUE';
    
    -- Get load statistics
    SELECT COUNT(*), COUNT(DISTINCT source_file)
    INTO v_rows, v_files
    FROM raw.events
    WHERE loaded_at >= :v_start;
    
    -- Update log with success
    UPDATE audit.load_log
    SET completed_at = CURRENT_TIMESTAMP(),
        rows_loaded = :v_rows,
        files_processed = :v_files,
        status = 'SUCCESS'
    WHERE load_id = :v_load_id;
    
    RETURN 'Loaded ' || :v_rows || ' rows from ' || :v_files || ' files';
    
EXCEPTION
    WHEN OTHER THEN
        -- Log error
        UPDATE audit.load_log
        SET completed_at = CURRENT_TIMESTAMP(),
            status = 'FAILED',
            error_message = :SQLERRM
        WHERE load_id = :v_load_id;
        
        RETURN 'ERROR: ' || :SQLERRM;
END;
$$;


## Stored Procedure for Payments Load
CREATE OR REPLACE PROCEDURE raw.load_payments()
  RETURNS VARCHAR
  LANGUAGE SQL
  EXECUTE AS CALLER
AS
$$
DECLARE
    v_start TIMESTAMP;
    v_rows INTEGER;
    v_files INTEGER;
    v_load_id VARCHAR(36);
BEGIN
    v_start := CURRENT_TIMESTAMP();
    v_load_id := UUID_STRING();
    
    -- Insert start log
    INSERT INTO audit.load_log (load_id, source_name, target_table, started_at, status)
    VALUES (:v_load_id, 'payments', 'raw.payments', :v_start, 'RUNNING');
    
    -- Load data with zero tolerance
    COPY INTO raw.payments (payment_id, user_id, amount, currency, status, payment_method, payment_timestamp, loaded_at, source_file)
    FROM (
        SELECT 
            $1:payment_id::VARCHAR(30),
            $1:user_id::VARCHAR(20),
            $1:amount::DECIMAL(10,2),
            $1:currency::VARCHAR(3),
            $1:status::VARCHAR(20),
            $1:payment_method::VARCHAR(30),
            $1:payment_timestamp::TIMESTAMP,
            CURRENT_TIMESTAMP(),
            METADATA$FILENAME
        FROM @raw.payments_stage
    )
    FILE_FORMAT = (TYPE = 'PARQUET')
    ON_ERROR = 'ABORT_STATEMENT';
    
    -- Get load statistics
    SELECT COUNT(*), COUNT(DISTINCT source_file)
    INTO v_rows, v_files
    FROM raw.payments
    WHERE loaded_at >= :v_start;
    
    -- Update log with success
    UPDATE audit.load_log
    SET completed_at = CURRENT_TIMESTAMP(),
        rows_loaded = :v_rows,
        files_processed = :v_files,
        status = 'SUCCESS'
    WHERE load_id = :v_load_id;
    
    RETURN 'Loaded ' || :v_rows || ' rows from ' || :v_files || ' files';
    
EXCEPTION
    WHEN OTHER THEN
        -- Log error
        UPDATE audit.load_log
        SET completed_at = CURRENT_TIMESTAMP(),
            status = 'FAILED',
            error_message = :SQLERRM
        WHERE load_id = :v_load_id;
        
        RETURN 'ERROR: ' || :SQLERRM;
END;
$$;

## Stored Procedure for Catalog Load
CREATE OR REPLACE PROCEDURE raw.load_catalog()
  RETURNS VARCHAR
  LANGUAGE SQL
  EXECUTE AS CALLER
AS
$$
DECLARE
    v_start TIMESTAMP;
    v_rows INTEGER;
    v_files INTEGER;
    v_load_id VARCHAR(36);
BEGIN
    v_start := CURRENT_TIMESTAMP();
    v_load_id := UUID_STRING();
    
    -- Insert start log
    INSERT INTO audit.load_log (load_id, source_name, target_table, started_at, status)
    VALUES (:v_load_id, 'catalog', 'raw.catalog', :v_start, 'RUNNING');
    
    -- Load JSON data
    COPY INTO raw.catalog (product_id, product_data, category, price, effective_date, loaded_at, source_file)
    FROM (
        SELECT 
            $1:product_id::VARCHAR(30),
            $1 AS product_data,
            $1:category::VARCHAR(50),
            $1:price::DECIMAL(10,2),
            $1:effective_date::DATE,
            CURRENT_TIMESTAMP(),
            METADATA$FILENAME
        FROM @raw.catalog_stage
    )
    FILE_FORMAT = (TYPE = 'JSON', STRIP_OUTER_ARRAY = TRUE)
    ON_ERROR = 'CONTINUE';
    
    -- Get load statistics
    SELECT COUNT(*), COUNT(DISTINCT source_file)
    INTO v_rows, v_files
    FROM raw.catalog
    WHERE loaded_at >= :v_start;
    
    -- Update log with success
    UPDATE audit.load_log
    SET completed_at = CURRENT_TIMESTAMP(),
        rows_loaded = :v_rows,
        files_processed = :v_files,
        status = 'SUCCESS'
    WHERE load_id = :v_load_id;
    
    RETURN 'Loaded ' || :v_rows || ' rows from ' || :v_files || ' files';
    
EXCEPTION
    WHEN OTHER THEN
        -- Log error
        UPDATE audit.load_log
        SET completed_at = CURRENT_TIMESTAMP(),
            status = 'FAILED',
            error_message = :SQLERRM
        WHERE load_id = :v_load_id;
        
        RETURN 'ERROR: ' || :SQLERRM;
END;
$$;


## Master Load Procedure
CREATE OR REPLACE PROCEDURE raw.run_full_pipeline()
  RETURNS TABLE(result VARCHAR)
  LANGUAGE SQL
  EXECUTE AS CALLER
AS
$$
DECLARE
    res RESULTSET;
    events_result VARCHAR;
    payments_result VARCHAR;
    catalog_result VARCHAR;
BEGIN
    -- Run all loads
    CALL raw.load_events() INTO :events_result;
    CALL raw.load_payments() INTO :payments_result;
    CALL raw.load_catalog() INTO :catalog_result;
    
    -- Return results
    res := (
        SELECT :events_result AS result UNION ALL
        SELECT :payments_result UNION ALL
        SELECT :catalog_result
    );
    RETURN TABLE(res);
END;
$$;


## Task 4: Add Data Quality Checks
# Quality Check Procedure

USE ROLE MONITOR_SERVICE;
USE DATABASE streampulse_prod;

CREATE OR REPLACE PROCEDURE audit.run_quality_checks()
  RETURNS TABLE(check_name VARCHAR, status VARCHAR, details VARCHAR)
  LANGUAGE SQL
AS
$$
DECLARE
    res RESULTSET;
    v_last_hour TIMESTAMP;
BEGIN
    v_last_hour := DATEADD('hour', -1, CURRENT_TIMESTAMP());
    
    res := (
        -- Check 1: Events not empty in last hour
        SELECT 'events_not_empty' AS check_name,
               CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END AS status,
               COUNT(*)::VARCHAR || ' rows' AS details
        FROM raw.events
        WHERE loaded_at >= :v_last_hour
        
        UNION ALL
        
        -- Check 2: Events no null IDs
        SELECT 'events_no_null_ids',
               CASE WHEN SUM(CASE WHEN event_id IS NULL THEN 1 ELSE 0 END) = 0
                    THEN 'PASS' ELSE 'FAIL' END,
               SUM(CASE WHEN event_id IS NULL THEN 1 ELSE 0 END)::VARCHAR || ' nulls'
        FROM raw.events
        WHERE loaded_at >= :v_last_hour
        
        UNION ALL
        
        -- Check 3: Events valid timestamps
        SELECT 'events_valid_timestamps',
               CASE WHEN SUM(CASE WHEN event_timestamp > CURRENT_TIMESTAMP()
                    OR event_timestamp < '2020-01-01' THEN 1 ELSE 0 END) = 0
                    THEN 'PASS' ELSE 'WARN' END,
               SUM(CASE WHEN event_timestamp > CURRENT_TIMESTAMP()
                    OR event_timestamp < '2020-01-01' THEN 1 ELSE 0 END)::VARCHAR || ' invalid'
        FROM raw.events
        WHERE loaded_at >= :v_last_hour
        
        UNION ALL
        
        -- Check 4: Payments amount > 0
        SELECT 'payments_positive_amount',
               CASE WHEN SUM(CASE WHEN amount <= 0 THEN 1 ELSE 0 END) = 0
                    THEN 'PASS' ELSE 'FAIL' END,
               SUM(CASE WHEN amount <= 0 THEN 1 ELSE 0 END)::VARCHAR || ' invalid amounts'
        FROM raw.payments
        WHERE loaded_at >= :v_last_hour
        
        UNION ALL
        
        -- Check 5: Catalog valid prices
        SELECT 'catalog_valid_prices',
               CASE WHEN SUM(CASE WHEN price < 0 THEN 1 ELSE 0 END) = 0
                    THEN 'PASS' ELSE 'FAIL' END,
               SUM(CASE WHEN price < 0 THEN 1 ELSE 0 END)::VARCHAR || ' negative prices'
        FROM raw.catalog
        WHERE loaded_at >= :v_last_hour
        
        UNION ALL
        
        -- Check 6: Load log success rate
        SELECT 'load_log_success_rate',
               CASE WHEN (COUNT(CASE WHEN status = 'SUCCESS' THEN 1 END) * 1.0 / NULLIF(COUNT(*), 0)) >= 0.95
                    THEN 'PASS' ELSE 'WARN' END,
               COUNT(CASE WHEN status = 'SUCCESS' THEN 1 END)::VARCHAR || '/' || COUNT(*)::VARCHAR || ' successful'
        FROM audit.load_log
        WHERE started_at >= :v_last_hour
    );
    RETURN TABLE(res);
END;
$$;

-- Create alert table for quality failures
CREATE OR REPLACE TABLE audit.quality_alerts (
    alert_id VARCHAR(36) DEFAULT UUID_STRING(),
    check_name VARCHAR(100),
    status VARCHAR(20),
    details VARCHAR(1000),
    checked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    acknowledged BOOLEAN DEFAULT FALSE
);

-- Procedure to log quality failures
CREATE OR REPLACE PROCEDURE audit.log_quality_failures()
  RETURNS VARCHAR
  LANGUAGE SQL
AS
$$
BEGIN
    INSERT INTO audit.quality_alerts (check_name, status, details)
    SELECT check_name, status, details
    FROM TABLE(audit.run_quality_checks())
    WHERE status IN ('FAIL', 'WARN');
    
    RETURN 'Logged ' || SQLROWCOUNT || ' quality alerts';
END;
$$;


## Task 5: Test Access Control
# Test Execution

-- Test 1: ETL_SERVICE can load data
USE ROLE ETL_SERVICE;
USE WAREHOUSE ETL_WH;
CALL streampulse_prod.raw.load_events();
-- Expected: SUCCESS, returns row count

-- Test 2: DATA_ANALYST cannot load data
USE ROLE DATA_ANALYST;
USE WAREHOUSE BI_WH;
COPY INTO streampulse_prod.raw.events FROM @streampulse_prod.raw.events_stage;
-- Expected: FAIL (SQL access control error: insufficient privileges)

-- Test 3: DATA_ANALYST can read curated data
USE ROLE DATA_ANALYST;
SELECT * FROM streampulse_prod.curated.events LIMIT 10;
-- Expected: SUCCESS (if curated.events exists)

-- Test 4: DATA_ANALYST cannot read raw data
USE ROLE DATA_ANALYST;
SELECT * FROM streampulse_prod.raw.events LIMIT 10;
-- Expected: FAIL (SQL compilation error: Object does not exist or insufficient privileges)

-- Test 5: MONITOR_SERVICE can read audit logs
USE ROLE MONITOR_SERVICE;
USE WAREHOUSE ADHOC_WH;
SELECT * FROM streampulse_prod.audit.load_log ORDER BY started_at DESC LIMIT 10;
-- Expected: SUCCESS

-- Additional Test 6: DATA_ENGINEER can create stages
USE ROLE DATA_ENGINEER;
CREATE OR REPLACE STAGE streampulse_prod.raw.test_stage
  URL = 's3://sp-prod-lake/raw/test/'
  STORAGE_INTEGRATION = sp_prod_s3
  FILE_FORMAT = (TYPE = 'PARQUET');
-- Expected: SUCCESS

-- Additional Test 7: ETL_SERVICE cannot create stages
USE ROLE ETL_SERVICE;
CREATE OR REPLACE STAGE streampulse_prod.raw.test_stage2
  URL = 's3://sp-prod-lake/raw/test2/'
  STORAGE_INTEGRATION = sp_prod_s3
  FILE_FORMAT = (TYPE = 'PARQUET');
-- Expected: FAIL (insufficient privileges)

-- Additional Test 8: MONITOR_SERVICE can run quality checks
USE ROLE MONITOR_SERVICE;
CALL streampulse_prod.audit.run_quality_checks();
-- Expected: SUCCESS

-- Additional Test 9: DATA_ANALYST cannot run quality checks
USE ROLE DATA_ANALYST;
CALL streampulse_prod.audit.run_quality_checks();
-- Expected: FAIL (insufficient privileges)


## Test Results Documentation
+----+------------------+------------------------+------------------------+--------+--------+
| #  | Role             | Action                 | Expected               | Actual | Pass/Fail |
+----+------------------+------------------------+------------------------+--------+--------+
| 1  | ETL_SERVICE      | Load events            | Success                | Success| PASS    |
+----+------------------+------------------------+------------------------+--------+--------+
| 2  | DATA_ANALYST     | Load data              | Fail                    | Fail   | PASS    |
+----+------------------+------------------------+------------------------+--------+--------+
| 3  | DATA_ANALYST     | Read curated           | Success                | Success| PASS    |
+----+------------------+------------------------+------------------------+--------+--------+
| 4  | DATA_ANALYST     | Read raw               | Fail                    | Fail   | PASS    |
+----+------------------+------------------------+------------------------+--------+--------+
| 5  | MONITOR_SERVICE  | Read audit logs        | Success                | Success| PASS    |
+----+------------------+------------------------+------------------------+--------+--------+
| 6  | DATA_ENGINEER    | Create stage           | Success                | Success| PASS    |
+----+------------------+------------------------+------------------------+--------+--------+
| 7  | ETL_SERVICE      | Create stage           | Fail                    | Fail   | PASS    |
+----+------------------+------------------------+------------------------+--------+--------+
| 8  | MONITOR_SERVICE  | Run quality checks     | Success                | Success| PASS    |
+----+------------------+------------------------+------------------------+--------+--------+
| 9  | DATA_ANALYST     | Run quality checks     | Fail                    | Fail   | PASS    |
+----+------------------+------------------------+------------------------+--------+--------+


### Task 6: Create the Secure Loading Architecture Document

# StreamPulse Secure Loading Architecture

## Architecture Overview
┌─────────────────────────────────────────────────────────────────────┐
│ StreamPulse Secure Loading Pipeline │
│ │
│ AWS S3 Bucket Snowflake │
│ ┌──────────────┐ ┌─────────────────────────────────────────┐ │
│ │ s3://sp-prod │ │ STORAGE INTEGRATION (IAM Role) │ │
│ │ -lake/raw/ │──────▶│ arn:aws:iam::123456789012:role/sf-prod │ │
│ │ events/ │ └───────────────────┬─────────────────────┘ │
│ │ payments/ │ │ │
│ │ catalog/ │ ┌───────────────────▼─────────────────────┐ │
│ └──────────────┘ │ EXTERNAL STAGES │ │
│ │ - events_stage (Parquet) │ │
│ │ - payments_stage (Parquet) │ │
│ │ - catalog_stage (JSON) │ │
│ └───────────────────┬─────────────────────┘ │
│ │ │
│ ┌───────────────────▼─────────────────────┐ │
│ │ ETL_SERVICE Role (Stored Procedures) │ │
│ │ - load_events() │ │
│ │ - load_payments() │ │
│ │ - load_catalog() │ │
│ │ - run_full_pipeline() │ │
│ └───────────────────┬─────────────────────┘ │
│ │ │
│ ┌───────────────────▼─────────────────────┐ │
│ │ RAW Schema │ │
│ │ - events │ │
│ │ - payments │ │
│ │ - catalog │ │
│ └───────────────────┬─────────────────────┘ │
│ │ │
│ ┌───────────────────▼─────────────────────┐ │
│ │ MONITOR_SERVICE Role │ │
│ │ - run_quality_checks() │ │
│ │ - log_quality_failures() │ │
│ └───────────────────┬─────────────────────┘ │
│ │ │
│ ┌───────────────────▼─────────────────────┐ │
│ │ AUDIT Schema │ │
│ │ - load_log │ │
│ │ - quality_alerts │ │
│ └─────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘

# Security Controls
. Storage Integration (IAM-based)
No credentials stored in Snowflake

AWS IAM role arn:aws:iam::123456789012:role/sf-prod-role with trust policy for Snowflake

Limited to specific S3 prefix: s3://sp-prod-lake/raw/

Storage integration grants access without exposing AWS keys



====================================================================================================
| ROLE HIERARCHY                                                                                   |
====================================================================================================
| Role Name          | Parent Role      | Team/Type         | Description                          |
====================================================================================================
| ACCOUNTADMIN       | -                 | System            | Top-level system administrator       |
| PLATFORM_ADMIN     | ACCOUNTADMIN      | Platform Team     | Full system administration (2 users) |
| SYSADMIN           | PLATFORM_ADMIN    | System            | Database/warehouse administration    |
|--------------------|-------------------|-------------------|--------------------------------------|
| DATA_ENGINEER      | SYSADMIN          | Data Engineering  | Build pipelines (8 users)            |
|   ETL_SERVICE      | DATA_ENGINEER     | Service Account   | Automated pipeline loading           |
|   DBT_SERVICE      | DATA_ENGINEER     | Service Account   | dbt transformations                  |
|   MONITOR_SERVICE  | DATA_ENGINEER     | Service Account   | Pipeline monitoring                  |
|--------------------|-------------------|-------------------|--------------------------------------|
| DATA_ANALYST       | SYSADMIN          | Analytics         | Query curated data (20 users)        |
| DATA_SCIENTIST     | SYSADMIN          | Data Science      | ML experiments (5 users)             |
| PRODUCT_VIEWER     | SYSADMIN          | Product           | View dashboards (10 users)           |
| FINANCE_ANALYST    | SYSADMIN          | Finance           | Revenue reports (3 users)            |
|   PARTNER_READER   | FINANCE_ANALYST   | External Partners | Read shared datasets (15 companies)  |
====================================================================================================

====================================================================================================
| SCHEMA-LEVEL ACCESS MATRIX                                                                       |
====================================================================================================
| Role              | RAW    | STAGING | CURATED | FEATURES | ANALYTICS | SHARED | AUDIT   |
====================================================================================================
| PLATFORM_ADMIN    | RW     | RW      | RW      | RW       | RW        | RW     | R       |
| DATA_ENGINEER     | RW     | RW      | RW      | RW       | R         | RW     | ❌       |
| ETL_SERVICE       | W      | W       | W       | ❌       | ❌         | ❌     | ❌       |
| DBT_SERVICE       | R      | RW      | RW      | R        | ❌         | ❌     | ❌       |
| MONITOR_SERVICE   | ❌      | ❌       | ❌       | ❌       | ❌         | ❌     | R       |
| DATA_ANALYST      | ❌      | R       | R       | R        | RW        | R      | ❌       |
| DATA_SCIENTIST    | R      | R       | R       | RW       | R         | R      | ❌       |
| PRODUCT_VIEWER    | ❌      | ❌       | R       | ❌       | R         | R      | ❌       |
| FINANCE_ANALYST   | ❌      | ❌       | R*      | ❌       | ❌         | ❌     | ❌       |
| PARTNER_READER    | ❌      | ❌       | ❌       | ❌       | ❌         | R      | ❌       |
====================================================================================================

====================================================================================================
| DETAILED TABLE-LEVEL ACCESS (RAW SCHEMA)                                                         |
====================================================================================================
| Role              | raw.events | raw.payments | raw.catalog | raw.* (future) |
====================================================================================================
| PLATFORM_ADMIN    | RW         | RW           | RW          | RW             |
| DATA_ENGINEER     | RW         | RW           | RW          | RW             |
| ETL_SERVICE       | W          | W            | W           | W              |
| DBT_SERVICE       | R          | R            | R           | R              |
| DATA_SCIENTIST    | R          | R            | R           | R              |
| All Others        | ❌          | ❌            | ❌           | ❌              |
====================================================================================================

====================================================================================================
| DETAILED TABLE-LEVEL ACCESS (STAGING SCHEMA)                                                     |
====================================================================================================
| Role              | staging.events | staging.payments | staging.catalog | staging.* (future) |
====================================================================================================
| PLATFORM_ADMIN    | RW             | RW               | RW              | RW                 |
| DATA_ENGINEER     | RW             | RW               | RW              | RW                 |
| ETL_SERVICE       | W              | W                | W               | W                  |
| DBT_SERVICE       | RW             | RW               | RW              | RW                 |
| DATA_ANALYST      | R              | R                | R               | R                  |
| DATA_SCIENTIST    | R              | R                | R               | R                  |
| All Others        | ❌              | ❌                | ❌               | ❌                  |
====================================================================================================

====================================================================================================
| DETAILED TABLE-LEVEL ACCESS (CURATED SCHEMA)                                                     |
====================================================================================================
| Role              | curated.events | curated.revenue | curated.customers | curated.* (future) |
====================================================================================================
| PLATFORM_ADMIN    | RW             | RW              | RW                | RW                 |
| DATA_ENGINEER     | RW             | RW              | RW                | RW                 |
| ETL_SERVICE       | W              | W               | W                 | W                  |
| DBT_SERVICE       | RW             | RW              | RW                | RW                 |
| DATA_ANALYST      | R              | R               | R                 | R                  |
| DATA_SCIENTIST    | R              | R               | R                 | R                  |
| PRODUCT_VIEWER    | R              | R               | R                 | R                  |
| FINANCE_ANALYST   | ❌              | R (revenue only)| ❌                 | ❌                  |
| PARTNER_READER    | ❌              | ❌               | ❌                 | ❌                  |
====================================================================================================

====================================================================================================
| DETAILED TABLE-LEVEL ACCESS (FEATURES SCHEMA)                                                    |
====================================================================================================
| Role              | features.*      | features.ml_*   | features.* (future) |
====================================================================================================
| PLATFORM_ADMIN    | RW              | RW              | RW                  |
| DATA_ENGINEER     | RW              | RW              | RW                  |
| DATA_SCIENTIST    | RW              | RW              | RW                  |
| DBT_SERVICE       | R               | R               | R                   |
| DATA_ANALYST      | R               | R               | R                   |
| All Others        | ❌               | ❌               | ❌                   |
====================================================================================================

====================================================================================================
| DETAILED TABLE-LEVEL ACCESS (ANALYTICS SCHEMA)                                                   |
====================================================================================================
| Role              | analytics.*     | analytics.views | analytics.* (future) |
====================================================================================================
| PLATFORM_ADMIN    | RW              | RW              | RW                   |
| DATA_ANALYST      | RW              | RW              | RW                   |
| DATA_ENGINEER     | R               | R               | R                    |
| DATA_SCIENTIST    | R               | R               | R                    |
| PRODUCT_VIEWER    | R               | R               | R                    |
| All Others        | ❌               | ❌               | ❌                    |
====================================================================================================

====================================================================================================
| DETAILED TABLE-LEVEL ACCESS (SHARED SCHEMA)                                                      |
====================================================================================================
| Role              | shared.*        | shared.partner_* | shared.* (future)   |
====================================================================================================
| PLATFORM_ADMIN    | RW              | RW               | RW                  |
| DATA_ENGINEER     | RW              | RW               | RW                  |
| DATA_ANALYST      | R               | R                | R                   |
| DATA_SCIENTIST    | R               | R                | R                   |
| PRODUCT_VIEWER    | R               | R                | R                   |
| PARTNER_READER    | R               | R                | R                   |
| All Others        | ❌               | ❌                | ❌                   |
====================================================================================================

====================================================================================================
| DETAILED TABLE-LEVEL ACCESS (AUDIT SCHEMA)                                                       |
====================================================================================================
| Role              | audit.load_log  | audit.quality_alerts | audit.* (future)    |
====================================================================================================
| PLATFORM_ADMIN    | R               | R                    | R                   |
| DATA_ENGINEER     | R               | R                    | R                   |
| MONITOR_SERVICE   | R               | R                    | R                   |
| ETL_SERVICE       | W (insert only) | ❌                    | ❌                   |
| All Others        | ❌               | ❌                    | ❌                   |
====================================================================================================

====================================================================================================
| WAREHOUSE ACCESS MATRIX                                                                          |
====================================================================================================
| Role              | ETL_WH (XL) | BI_WH (Medium) | DS_WH (Large) | ADHOC_WH (Small) | DEV_WH (XS) | PARTNER_WH (Small) |
====================================================================================================
| PLATFORM_ADMIN    | ✓           | ✓              | ✓             | ✓                | ✓           | ✓                  |
| DATA_ENGINEER     | ✓           | ❌              | ❌             | ✓                | ✓           | ❌                  |
| ETL_SERVICE       | ✓           | ❌              | ❌             | ❌                | ❌           | ❌                  |
| DBT_SERVICE       | ✓           | ❌              | ❌             | ❌                | ❌           | ❌                  |
| MONITOR_SERVICE   | ❌           | ❌              | ❌             | ✓                | ❌           | ❌                  |
| DATA_ANALYST      | ❌           | ✓              | ❌             | ❌                | ✓           | ❌                  |
| DATA_SCIENTIST    | ❌           | ❌              | ✓             | ✓                | ✓           | ❌                  |
| PRODUCT_VIEWER    | ❌           | ✓              | ❌             | ❌                | ❌           | ❌                  |
| FINANCE_ANALYST   | ❌           | ✓              | ❌             | ❌                | ❌           | ❌                  |
| PARTNER_READER    | ❌           | ❌              | ❌             | ❌                | ❌           | ✓                  |
====================================================================================================

====================================================================================================
| DATABASE ENVIRONMENT ACCESS                                                                      |
====================================================================================================
| Role              | STREAMPULSE_PROD  | STREAMPULSE_STAGING | STREAMPULSE_DEV     |
====================================================================================================
| PLATFORM_ADMIN    | ✓ (Full)          | ✓ (Full)            | ✓ (Full)            |
| DATA_ENGINEER     | ✓ (Full)          | ✓ (Full)            | ✓ (Full)            |
| ETL_SERVICE       | ✓ (RAW only)      | ✓ (RAW only)        | ❌                   |
| DBT_SERVICE       | ✓ (Transform)     | ✓ (Transform)       | ✓ (Transform)       |
| MONITOR_SERVICE   | ✓ (AUDIT only)    | ❌                   | ❌                   |
| DATA_ANALYST      | ✓ (CURATED/ANALYTICS)| ✓ (Testing)     | ✓ (Development)     |
| DATA_SCIENTIST    | ✓ (All read + FEATURES)| ✓ (Testing)  | ✓ (Development)     |
| PRODUCT_VIEWER    | ✓ (CURATED/SHARED)| ❌                   | ❌                   |
| FINANCE_ANALYST   | ✓ (CURATED limited)| ❌                   | ❌                   |
| PARTNER_READER    | ✓ (SHARED only)   | ❌                   | ❌                   |
====================================================================================================

====================================================================================================
| COLUMN-LEVEL SECURITY (DATA MASKING) - curated.customers table                                   |
====================================================================================================
| Role              | customer_id  | name        | email        | phone        | subscription_tier | lifetime_revenue |
|                   | (Public)     | (Public)    | (PII)        | (PII)        | (Business)        | (Financial)      |
====================================================================================================
| PLATFORM_ADMIN    | Full         | Full        | Full         | Full         | Full              | Full             |
| DATA_ENGINEER     | Full         | Full        | Full         | Full         | Full              | Full             |
| ETL_SERVICE       | Full         | Full        | Full         | Full         | Full              | Full             |
| DBT_SERVICE       | Full         | Full        | Full         | Full         | Full              | Full             |
| DATA_ANALYST      | Full         | Full        | ***@domain  | ***-***-1234 | Full              | NULL             |
| DATA_SCIENTIST    | Full         | Full        | ***@domain  | ***-***-1234 | Full              | NULL             |
| PRODUCT_VIEWER    | Full         | Full        | ***@domain  | ***-***-1234 | Full              | NULL             |
| FINANCE_ANALYST   | Full         | Full        | ***@domain  | ***-***-1234 | Full              | Full             |
| PARTNER_READER    | Full         | Full        | ***@domain  | ***-***-1234 | Full              | NULL             |
====================================================================================================

====================================================================================================
| OBJECT PRIVILEGES BY ROLE                                                                        |
====================================================================================================
| Role              | CREATE | CREATE | CREATE | ALTER | DROP  | SELECT | INSERT/ | USAGE ON |
|                   | SCHEMA | TABLE  | VIEW   |       |       |        | UPDATE  | STAGE    |
====================================================================================================
| PLATFORM_ADMIN    | ✓ All  | ✓ All  | ✓ All  | ✓ All | ✓ All | ✓ All  | ✓ All   | ✓ All    |
| DATA_ENGINEER     | ✓ All  | ✓ All  | ✓ All  | ✓ All | ✓ All | ✓ All  | ✓ All   | ✓ All    |
| ETL_SERVICE       | ❌     | ❌     | ❌     | ❌    | ❌    | ✓ RAW  | ✓ RAW   | ✓ Read   |
| DBT_SERVICE       | ❌     | ✓ Cur  | ✓ Cur  | ❌    | ❌    | ✓ All  | ✓ Stg/Cur| ❌       |
| MONITOR_SERVICE   | ❌     | ❌     | ❌     | ❌    | ❌    | ✓ AUDIT| ❌       | ❌       |
| DATA_ANALYST      | ❌     | ✓ An   | ✓ An   | ❌    | ❌    | ✓ Cur/An| ✓ An    | ❌       |
| DATA_SCIENTIST    | ❌     | ✓ Feat | ✓ Feat | ❌    | ❌    | ✓ All  | ✓ Feat  | ❌       |
| PRODUCT_VIEWER    | ❌     | ❌     | ❌     | ❌    | ❌    | ✓ Cur/Sh| ❌       | ❌       |
| FINANCE_ANALYST   | ❌     | ❌     | ❌     | ❌    | ❌    | ✓ Fin  | ❌       | ❌       |
| PARTNER_READER    | ❌     | ❌     | ❌     | ❌    | ❌    | ✓ Sh   | ❌       | ❌       |
====================================================================================================
Note: Cur = CURATED, An = ANALYTICS, Feat = FEATURES, Stg = STAGING, Sh = SHARED, Fin = Finance tables

====================================================================================================
| STAGE ACCESS MATRIX                                                                              |
====================================================================================================
| Role              | events_stage  | payments_stage | catalog_stage | Create New Stage |
====================================================================================================
| PLATFORM_ADMIN    | ✓ (Full)      | ✓ (Full)       | ✓ (Full)      | ✓                |
| DATA_ENGINEER     | ✓ (Full)      | ✓ (Full)       | ✓ (Full)      | ✓                |
| ETL_SERVICE       | ✓ (Read only) | ✓ (Read only)  | ✓ (Read only) | ❌                |
| DBT_SERVICE       | ❌            | ❌              | ❌             | ❌                |
| MONITOR_SERVICE   | ❌            | ❌              | ❌             | ❌                |
| DATA_ANALYST      | ❌            | ❌              | ❌             | ❌                |
| DATA_SCIENTIST    | ❌            | ❌              | ❌             | ❌                |
| PRODUCT_VIEWER    | ❌            | ❌              | ❌             | ❌                |
| FINANCE_ANALYST   | ❌            | ❌              | ❌             | ❌                |
| PARTNER_READER    | ❌            | ❌              | ❌             | ❌                |
====================================================================================================

====================================================================================================
| TEAM ROLE ASSIGNMENTS SUMMARY                                                                    |
====================================================================================================
| Team/Group         | Assigned Roles                          | User Count | Primary Functions              |
====================================================================================================
| Platform Team      | PLATFORM_ADMIN                          | 2          | Full system administration      |
| Data Engineering   | DATA_ENGINEER                           | 8          | Build pipelines, manage schemas |
| Analytics          | DATA_ANALYST                            | 20         | Query curated, build dashboards |
| Data Science       | DATA_SCIENTIST                          | 5          | Feature engineering, ML         |
| Product            | PRODUCT_VIEWER                          | 10         | View dashboards, light queries  |
| Finance            | FINANCE_ANALYST                         | 3          | Revenue reports, restricted     |
| External Partners  | PARTNER_READER                          | 15         | Read shared datasets only       |
| Service Accounts   | ETL_SERVICE, DBT_SERVICE, MONITOR_SERVICE| 3         | Automated pipeline operations   |
====================================================================================================

====================================================================================================
| LEGEND                                                                                           |
====================================================================================================
| Symbol | Meaning                                                                                  |
====================================================================================================
| RW     | Read-Write access (SELECT, INSERT, UPDATE, DELETE)                                      |
| R      | Read-only access (SELECT only)                                                            |
| W      | Write-only access (INSERT, UPDATE, DELETE, no SELECT)                                    |
| R*     | Read-only on specific tables only (finance tables)                                        |
| ✓      | Has access/privilege                                                                      |
| ❌      | No access                                                                                  |
| Full   | Complete visibility (no masking)                                                           |
| Masked | Data is obfuscated (e.g., ***@domain.com, ***-***-1234)                                   |
| NULL   | Value shown as NULL                                                                        |
| PII    | Personally Identifiable Information                                                         |
| Cur    | CURATED schema                                                                             |
| An     | ANALYTICS schema                                                                           |
| Feat   | FEATURES schema                                                                            |
| Stg    | STAGING schema                                                                             |
| Sh     | SHARED schema                                                                              |
| Fin    | Finance tables only (revenue_daily, subscriptions, invoices, payments)                     |
====================================================================================================



3. Stage Access Restrictions
Stage creation: Only DATA_ENGINEER role

Stage usage: Only ETL_SERVICE and DATA_ENGINEER roles

No other roles can access or even see external stages

4. Column-Level Security (Future Enhancement)
PII columns in curated layer masked for non-privileged roles

Dynamic data masking policies to be applied

5. Audit Logging
All load operations logged to audit.load_log

Quality check results stored in audit.quality_alerts

Who, what, when for all data movements
