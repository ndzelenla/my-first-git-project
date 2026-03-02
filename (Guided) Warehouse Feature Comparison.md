(Guided) Warehouse Feature Comparison
Author: Sammy Ndzelen
Date: 02.03.2026

Architecture Features
=====================================================================================================================
| Feature                    | Snowflake                | BigQuery                 | Redshift                 | Databricks               |
|----------------------------|--------------------------|--------------------------|--------------------------|--------------------------|
| Storage/compute separation | ✅                       | ✅                       | ⚠️ (RA3 nodes)           | ✅                       |
| Serverless option          | ✅                       | ✅                       | ✅ (Serverless)          | ✅                       |
| Multi-cloud deployment     | ✅ (AWS, Azure, GCP)     | ❌ (GCP only)            | ❌ (AWS only)            | ✅ (AWS, Azure, GCP)     |
| Auto-scaling compute       | ✅                       | ✅                       | ⚠️ (requires config)     | ✅                       |
| Auto-suspend/pause         | ✅                       | ✅                       | ❌                       | ✅                       |
| Storage format             | Proprietary              | Colossus/Capacitor       | Proprietary              | Delta Lake               |
| Query engine               | Proprietary              | Dremel                   | ParAccel                 | Photon                   |



Data Management Features
=====================================================================================================================
| Feature                    | Snowflake                | BigQuery                 | Redshift                 | Databricks               |
|----------------------------|--------------------------|--------------------------|--------------------------|--------------------------|
| Time Travel (historical queries) | ✅ (90 days)      | ✅ (7 days)              | ✅ (2 days)              | ✅ (Delta time travel)   |
| Data cloning (zero-copy)   | ✅                       | ✅                       | ❌                       | ✅                       |
| Native data sharing        | ✅ (Secure Data Sharing) | ✅ (Analytics Hub)       | ⚠️ (Redshift Datashare)  | ✅ (Delta Sharing)       |
| Semi-structured data (JSON)| ✅ (VARIANT)             | ✅                       | ⚠️ (JSON functions)      | ✅ (Spark structs)       |
| Streaming ingestion        | ✅ (Snowpipe)            | ✅                       | ⚠️ (Kinesis Firehose)    | ✅ (Auto Loader)         |
| External tables            | ✅                       | ✅                       | ✅                       | ✅                       |
| Schema evolution           | ⚠️ (limited)             | ✅                       | ❌                       | ✅                       |



Ecosystem & Integration
=====================================================================================================================
| Feature                    | Snowflake                | BigQuery                 | Redshift                 | Databricks               |
|----------------------------|--------------------------|--------------------------|--------------------------|--------------------------|
| Native Spark engine        | ❌ (Spark connector)     | ❌ (Dataproc)            | ❌ (Spark on EMR)        | ✅ (built-in)            |
| dbt integration            | ✅                       | ✅                       | ✅                       | ✅                       |
| Tableau/BI connectivity    | ✅                       | ✅                       | ✅                       | ✅                       |
| Python/Pandas support      | ✅                       | ✅                       | ✅                       | ✅                       |
| ML capabilities            | ⚠️ (Snowpark ML)         | ✅ (BigQuery ML)         | ❌ (Redshift ML limited) | ✅ (Databricks ML)       |
| CI/CD & version control    | ✅ (Git integration)     | ⚠️ (limited)             | ❌                       | ✅ (Repos)               |
| REST API                   | ✅                       | ✅                       | ⚠️ (limited)             | ✅                       |


### Task 2: Scenario-Based Evaluation
# Evaluate each platform against 5 specific StreamPulse use cases. Score each 1-10:

Use Case 1: Nightly ETL Pipeline
=====================================================================================================================
| Platform    | Score | Justification                                                                          |
|-------------|-------|----------------------------------------------------------------------------------------|
| Snowflake   | 7/10  | Snowpark for Python supports Spark-like transforms, but extra data movement required   |
| BigQuery    | 6/10  | Requires Dataproc for Spark, adds operational overhead                                 |
| Redshift    | 5/10  | No native Spark; EMR integration adds complexity and latency                           |
| Databricks  | 10/10 | Built-in Spark engine, Delta Lake optimizations, Auto Loader for streaming             |


Use Case 2: Self-Service BI Dashboards
=====================================================================================================================
| Platform    | Score | Justification                                                                          |
|-------------|-------|----------------------------------------------------------------------------------------|
| Snowflake   | 9/10  | Auto-suspend saves costs, result caching delivers sub-second queries                   |
| BigQuery    | 8/10  | Fast but slot contention during peak hours possible                                    |
| Redshift    | 7/10  | RA3 helps but needs workload management tuning                                         |
| Databricks  | 7/10  | SQL Warehouse and Photon fast, but cluster startup time can delay                      |


Use Case 3: Data Sharing with Partners
=====================================================================================================================
| Platform    | Score | Justification                                                                          |
|-------------|-------|----------------------------------------------------------------------------------------|
| Snowflake   | 10/10 | Secure Data Sharing works across clouds, no data copying                               |
| BigQuery    | 7/10  | Analytics Hub sharing, but limited to GCP recipients                                   |
| Redshift    | 5/10  | Datashare works but AWS-only and requires careful VPC setup                            |
| Databricks  | 9/10  | Delta Sharing open standard, but partners need Delta Lake readers                      |


Use Case 4: Ad-Hoc Data Exploration
=====================================================================================================================
| Platform    | Score | Justification                                                                          |
|-------------|-------|----------------------------------------------------------------------------------------|
| Snowflake   | 8/10  | Snowpark Python, worksheets, but notebooks feel bolted-on                              |
| BigQuery    | 8/10  | BigQuery Studio, Colab integration, good Python support                                |
| Redshift    | 5/10  | Limited notebook support, Python via UDFs only                                         |
| Databricks  | 10/10 | First-class notebooks, Python/Pandas/Spark, collaborative workspaces                   |



Use Case 5: ML Feature Engineering
=====================================================================================================================
| Platform    | Score | Justification                                                                          |
|-------------|-------|----------------------------------------------------------------------------------------|
| Snowflake   | 7/10  | Snowpark ML features, but Feature Store is immature                                    |
| BigQuery    | 7/10  | BigQuery ML and Vertex AI integration, but less flexible                               |
| Redshift    | 4/10  | Redshift ML is limited to simple models                                                |
| Databricks  | 10/10 | Feature Store, MLflow, AutoML, full MLOps lifecycle                                    |



## Task 3: Weighted Evaluation

Weight Assignment
=====================================================================================================================
| Use Case                      | Weight (%) | Rationale                                            |
|-------------------------------|------------|------------------------------------------------------|
| Nightly ETL Pipeline          | 30%        | Core data foundation, must be reliable               |
| Self-Service BI Dashboards    | 25%        | Analyst productivity critical                         |
| Data Sharing with Partners    | 20%        | Revenue-generating capability                         |
| Ad-Hoc Data Exploration       | 15%        | Data science innovation                               |
| ML Feature Engineering        | 10%        | Future ML initiatives                                 |
| Total                         | 100%       |                                                      |


Weighted Score Calculation
=====================================================================================================================================
| Platform    | ETL (30%)          | BI (25%)           | Sharing (20%)      | Ad-Hoc (15%)       | ML (10%)           | Total  |
|-------------|--------------------|--------------------|--------------------|--------------------|--------------------|--------|
| Snowflake   | 7 × 30 = 2.1       | 9 × 25 = 2.25      | 10 × 20 = 2.0      | 8 × 15 = 1.2       | 7 × 10 = 0.7       | 8.25   |
| BigQuery    | 6 × 30 = 1.8       | 8 × 25 = 2.0       | 7 × 20 = 1.4       | 8 × 15 = 1.2       | 7 × 10 = 0.7       | 7.1    |
| Redshift    | 5 × 30 = 1.5       | 7 × 25 = 1.75      | 5 × 20 = 1.0       | 5 × 15 = 0.75      | 4 × 10 = 0.4       | 5.4    |
| Databricks  | 10 × 30 = 3.0      | 7 × 25 = 1.75      | 9 × 20 = 1.8       | 10 × 15 = 1.5      | 10 × 10 = 1.0      | 9.05   |


## Task 4: Risk Analysis

Risk Analysis
=====================================================================================================================
| Platform    | Risk 1                                      | Risk 2                                      | Risk 3                                      |
|-------------|---------------------------------------------|---------------------------------------------|---------------------------------------------|
| Snowflake   | Cost unpredictability with complex queries  | Vendor lock-in with proprietary storage     | Time-travel storage costs for large tables  |
| BigQuery    | GCP-only deployment (no multi-cloud)        | Slot contention during peak periods         | Limited Spark native integration            |
| Redshift    | AWS lock-in                                  | Manual tuning required for performance      | Poor semi-structured data support           |
| Databricks  | Complex cost management (DBUs + cloud)      | Team must learn Spark (Python ok)           | Unity Catalog migration complexity          |


Task 5: Executive Summary
StreamPulse Warehouse Platform Evaluation
Recommendation: Databricks

Executive Summary
Based on a comprehensive evaluation across five key use cases with weighted scoring, Databricks is the recommended platform for StreamPulse. It uniquely combines native Spark processing for our 2TB nightly ETL workloads with an exceptional data science environment, while offering multi-cloud data sharing capabilities that align with our partner strategy.

Evaluation Methodology
Compared 4 leading platforms across 21 architecture, data management, and ecosystem features

Evaluated against 5 key use cases with weighted scoring (ETL 30%, BI 25%, Data Sharing 20%, Ad-Hoc 15%, ML 10%)

Assessed risks including vendor lock-in, cost predictability, and team skill alignment


Scoring Results
Platform	Weighted Score	Rank
Databricks	9.05/10	1st
Snowflake	8.25/10	2nd
BigQuery	7.10/10	3rd
Redshift	5.40/10	4th


Key Strengths of Databricks
Unified Spark Engine: Eliminates EMR management overhead, directly supports our Python/Spark team's existing skills

Multi-Cloud Data Sharing: Delta Sharing enables secure partner access regardless of their cloud provider

End-to-End ML Lifecycle: Integrated Feature Store, MLflow, and notebooks accelerate data science innovation

Key Risks and Mitigations
Risk: Complex cost management → Mitigation: Implement Databricks cost monitoring dashboards and workload-specific cluster policies from day one

Risk: Unity Catalog migration → Mitigation: Phased migration approach starting with new workloads, parallel run during transition



Estimated Monthly Cost: $13,000–15,000
Based on current 15TB volume, nightly Spark ETL, and BI workloads, within StreamPulse's budget range. Cost optimization possible through Databricks' auto-scaling and spot instance usage.





