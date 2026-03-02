(Challenge) Warehouse Selection Exercise
Author: Sammy Ndzelen
Date: 02.03.2026

## Multi-Company Data Warehouse Platform Evaluation
## Task 1: Evaluate FreshCart (E-commerce Startup)

# Step 1 & 2: Scoring Matrix and Weighted Scores

FreshCart Evaluation - Scoring Matrix
=============================================================================================================
| Criterion               | Weight | Snowflake | BigQuery | Redshift | Databricks |
|-------------------------|--------|-----------|----------|----------|------------|
| GCP integration         | 25%    | 6         | 10       | 0        | 8          |
| Low admin overhead      | 20%    | 8         | 9        | 5        | 7          |
| Cost within $2K/mo      | 25%    | 5         | 9        | 4        | 6          |
| SQL-first experience    | 20%    | 9         | 9        | 8        | 7          |
| Fast time-to-value      | 10%    | 8         | 10       | 6        | 7          |

Weighted Score Calculation
=============================================================================================================
| Platform    | GCP (25%)   | Admin (20%) | Cost (25%) | SQL (20%)  | Value (10%) | Total  |
|-------------|-------------|-------------|------------|------------|-------------|--------|
| Snowflake   | 6×25=1.5    | 8×20=1.6    | 5×25=1.25  | 9×20=1.8   | 8×10=0.8    | 6.95   |
| BigQuery    | 10×25=2.5   | 9×20=1.8    | 9×25=2.25  | 9×20=1.8   | 10×10=1.0   | 9.35   |
| Redshift    | 0×25=0      | 5×20=1.0    | 4×25=1.0   | 8×20=1.6   | 6×10=0.6    | 4.20   |
| Databricks  | 8×25=2.0    | 7×20=1.4    | 6×25=1.5   | 7×20=1.4   | 7×10=0.7    | 7.00   |


# Step 3: Monthly Cost Estimates
FreshCart - Monthly Cost Estimates (2TB data)
=============================================================================================================
| Platform    | Storage Cost | Compute Cost | Total (Estimated) | Notes |
|-------------|--------------|--------------|-------------------|-------|
| BigQuery    | $10/TB/mo = $20 | $5/TB processed = $50-100 | $70-120 | On-demand pricing, fits budget |
| Snowflake   | $23/TB/mo = $46 | Per second compute = $100-200 | $146-246 | Close to budget limit |
| Databricks  | $30/TB/mo = $60 | DBUs + cloud = $150-250 | $210-310 | Above budget |
| Redshift    | $25/TB/mo = $50 | RA3 instance = $320 fixed | $370 | Way over budget |


Step 4: FreshCart Recommendation
Paragraph 1: Recommended Platform and Why

BigQuery is the clear winner for FreshCart. With a weighted score of 9.35/10 and estimated monthly costs of just $70-120, it perfectly aligns with the company's requirements. FreshCart is already on GCP with some BigQuery usage, so there's zero data egress costs and the team can leverage their existing SQL skills immediately. BigQuery's serverless model means no cluster management—the 3 data engineers can focus on building insights rather than babysitting infrastructure. The on-demand pricing is ideal for their 2TB scale and 50% growth, as they only pay for queries run, not for idle compute.

Paragraph 2: Runner-Up and Why It Wasn't Chosen

Databricks scored second at 7.00/10, but it's overkill for FreshCart's needs. While Databricks offers excellent Python integration, the team has no Spark experience, creating a steep learning curve. The SQL endpoint works well, but the $210-310/month cost pushes past the $2,000 budget once you factor in the cloud infrastructure costs. Snowflake came in at 6.95/10—very close to Databricks—but at $146-246/month, it's also straining the budget. Both platforms are designed for larger teams and more complex workloads than FreshCart currently requires.

Paragraph 3: Risks and Mitigations

The primary risk with BigQuery is query cost unpredictability—a single analyst running a massive unoptimized query could spike the monthly bill. Mitigation: Implement query cost monitoring with BQ billing alerts at 50%, 75%, and 90% of budget. Create a cost governance playbook for analysts. The second risk is vendor lock-in with GCP. Mitigation: Keep raw data in Cloud Storage with open formats (Parquet/CSV) so the data remains portable. The third risk is performance during peak hours. Mitigation: Use BigQuery's reservation slots if needed, and cache common dashboard results in Looker.

FinanceCore Evaluation - Scoring Matrix
=============================================================================================================
| Criterion               | Weight | Snowflake | BigQuery | Redshift | Databricks |
|-------------------------|--------|-----------|----------|----------|------------|
| Multi-cloud support     | 20%    | 10        | 0        | 0        | 10         |
| Spark integration       | 20%    | 6         | 5        | 4        | 10         |
| SQL analytics           | 15%    | 10        | 9        | 8        | 8          |
| Governance & security   | 15%    | 9         | 8        | 8        | 9          |
| Data sharing            | 15%    | 10        | 7        | 5        | 9          |
| ML/AI capabilities      | 15%    | 7         | 8        | 4        | 10         |

Weighted Score Calculation
===============================================================================================================================
| Platform    | Multi (20%) | Spark (20%) | SQL (15%) | Gov (15%) | Share (15%) | ML (15%) | Total  |
|-------------|-------------|-------------|-----------|-----------|-------------|----------|--------|
| Snowflake   | 10×20=2.0   | 6×20=1.2    | 10×15=1.5 | 9×15=1.35 | 10×15=1.5   | 7×15=1.05 | 8.60   |
| BigQuery    | 0×20=0      | 5×20=1.0    | 9×15=1.35 | 8×15=1.2  | 7×15=1.05   | 8×15=1.2  | 5.80   |
| Redshift    | 0×20=0      | 4×20=0.8    | 8×15=1.2  | 8×15=1.2  | 5×15=0.75   | 4×15=0.6  | 4.55   |
| Databricks  | 10×20=2.0   | 10×20=2.0   | 8×15=1.2  | 9×15=1.35 | 9×15=1.35   | 10×15=1.5 | 9.40   |

FinanceCore - Monthly Cost Estimates (500TB, heavy compute, 24/7)
=============================================================================================================
| Platform    | Storage Cost       | Compute Cost          | Total (Estimated) | Notes |
|-------------|--------------------|-----------------------|-------------------|-------|
| Snowflake   | $23/TB × 500 = $11,500 | Enterprise edition + heavy = $40-60K | $51,500-71,500 | Within budget |
| BigQuery    | $10/TB × 500 = $5,000  | Flat rate slots = $40-50K | $45,000-55,000 | GCP-only, can't use |
| Redshift    | $25/TB × 500 = $12,500 | RA3.16xl = $20-30K    | $32,500-42,500 | AWS-only, can't use |
| Databricks  | $30/TB × 500 = $15,000 | Premium + heavy = $80-100K | $95,000-115,000 | Slightly above |


FinanceCore - Hybrid Strategy: Databricks + Snowflake
=============================================================================================================
| Aspect               | Analysis                                                                          |
|----------------------|-----------------------------------------------------------------------------------|
| Architecture         | Databricks for Spark/ML + Snowflake for SQL analytics and regulated data sharing |
| Weighted Score       | Databricks (9.40) + Snowflake (8.60) strengths combined                          |
| Estimated Cost       | $95K-115K (Databricks) + $40K (Snowflake shared data) = $135-155K                |
|                       | Slightly above budget but justified by requirements                               |

Pros of Hybrid Strategy
=============================================================================================================
| Pro                                   | Explanation                                                                        |
|---------------------------------------|------------------------------------------------------------------------------------|
| Best-of-breed for each workload       | Databricks excels at Spark/ML, Snowflake excels at SQL sharing                     |
| Multi-cloud achieved                  | Databricks on AWS + Azure, Snowflake on AWS + Azure                                |
| Regulatory data isolation             | Keep sensitive data in Snowflake with fine-grained access control                  |
| No vendor lock-in                     | Two platforms means you can shift workloads gradually                              |

Cons of Hybrid Strategy
=============================================================================================================
| Con                                   | Explanation                                                                        |
|---------------------------------------|------------------------------------------------------------------------------------|
| Cost premium (30-40%)                 | Two platforms means double the base costs                                          |
| Operational complexity                | Two UIs, two permission systems, two support tickets                              |
| Data movement between platforms       | Latency and potential consistency issues                                           |
| Team must learn both                  | Engineers need expertise in both Databricks and Snowflake                          |


Step 5: FinanceCore Recommendation
Recommendation: Hybrid Databricks + Snowflake Architecture

FinanceCore should adopt a hybrid architecture with Databricks as the primary processing engine and Snowflake for regulated SQL analytics and data sharing. Databricks scores highest at 9.40/10 and is non-negotiable for the 30-strong data engineering team with deep Spark expertise. It handles the 500TB risk modeling workloads natively and provides MLflow for the 20 data scientists. However, Snowflake's Secure Data Sharing at 10/10 is critical for sharing regulatory reports with auditors and external partners—something Databricks Delta Sharing requires recipients to have Delta Lake readers.

The hybrid approach adds 30-40% cost ($135-155K vs $95-115K for Databricks alone), but this premium is justified by FinanceCore's regulatory requirements and multi-cloud mandate. Snowflake operates on both AWS and Azure, matching the company's cloud strategy. The key is to minimize data movement by keeping raw data in S3/ADLS and using each platform's external table capabilities—Databricks queries data for transformations, Snowflake queries the same data for regulated reports. This requires strong Unity Catalog and Snowflake data sharing governance alignment, but delivers the compliance and flexibility investment banking demands.


MediaStream Evaluation - Scoring Matrix
=============================================================================================================
| Criterion               | Weight | Snowflake | BigQuery | Redshift | Databricks |
|-------------------------|--------|-----------|----------|----------|------------|
| AWS integration         | 20%    | 9         | 0        | 10       | 9          |
| Spark integration       | 20%    | 6         | 5        | 4        | 10         |
| Self-service BI         | 20%    | 9         | 8        | 6        | 7          |
| ML capabilities         | 15%    | 7         | 8        | 4        | 10         |
| Migration ease          | 15%    | 7         | 4        | 8        | 6          |
| Cost within $25K/mo     | 10%    | 7         | 8        | 6        | 6          |

Weighted Score Calculation
===============================================================================================================================
| Platform    | AWS (20%) | Spark (20%) | BI (20%) | ML (15%) | Migrate (15%) | Cost (10%) | Total  |
|-------------|-----------|-------------|----------|----------|---------------|------------|--------|
| Snowflake   | 9×20=1.8  | 6×20=1.2    | 9×20=1.8 | 7×15=1.05| 7×15=1.05     | 7×10=0.7   | 7.60   |
| BigQuery    | 0×20=0    | 5×20=1.0    | 8×20=1.6 | 8×15=1.2 | 4×15=0.6      | 8×10=0.8   | 5.20   |
| Redshift    | 10×20=2.0 | 4×20=0.8    | 6×20=1.2 | 4×15=0.6 | 8×15=1.2      | 6×10=0.6   | 6.40   |
| Databricks  | 9×20=1.8  | 10×20=2.0   | 7×20=1.4 | 10×15=1.5| 6×15=0.9      | 6×10=0.6   | 8.20   |

MediaStream - Databricks Migration Plan
=============================================================================================================
| Phase | Timeline | Activities | Success Criteria |
|-------|----------|------------|------------------|
| Phase 1: POC and Assessment | Month 1 | - Set up Databricks workspace in AWS<br>- Connect to existing S3 data lake<br>- Migrate one high-value ETL pipeline<br>- Train 5 engineers on Databricks | - Successful pipeline run in <3 hours<br>- 5 engineers certified<br>- Cost baseline established |
| Phase 2: Parallel Run | Months 2-3 | - Migrate all ETL workloads to Databricks<br>- Set up Unity Catalog for governance<br>- Configure SQL Warehouse for BI team<br>- Run Redshift and Databricks in parallel | - All 15 data engineers operational<br>- BI dashboards migrated to new platform<br>- Data validation complete |
| Phase 3: Cutover and Decommission | Month 4 | - Redirect all BI tools to Databricks SQL<br>- Decommission Redshift clusters<br>- Archive old Redshift data<br>- Post-migration review | - Zero Redshift queries in production<br>- All 40 analysts using new platform<br>- $25K/month budget achieved |


Step 4: MediaStream Recommendation
Recommendation: Databricks

Databricks is the optimal choice for MediaStream with a weighted score of 8.20/10. The company is already on AWS with S3 and Spark on EMR, making Databricks a natural evolution rather than a revolution. The 15 data engineers have moderate Spark skills that will rapidly accelerate with Databricks' optimized Spark engine and Photon acceleration. The ML capabilities score of 10/10 directly supports the content recommendation engine requirements, and Unity Catalog provides the governance needed for user behavior analytics.

The migration plan above prioritizes de-risking the transition from struggling Redshift. Phase 1 proves the platform works with actual MediaStream data and trains the team. Phase 2 runs both platforms in parallel—critical for a media company where downtime means lost revenue. Phase 3 cuts over when validation is complete. The key challenge is the self-service BI score of 7/10—analysts used to Redshift may need training on Databricks SQL Warehouse. However, the improvement in Spark integration (4/10 → 10/10) and ML capabilities (4/10 → 10/10) far outweighs this learning curve.


Cross-Company Comparison
=====================================================================================================================================
| Dimension               | FreshCart                              | FinanceCore                              | MediaStream                              |
|-------------------------|----------------------------------------|-----------------------------------------|------------------------------------------|
| Recommended platform    | BigQuery                               | Hybrid: Databricks + Snowflake          | Databricks                               |
| Runner-up               | Databricks                             | Databricks alone                        | Snowflake                                |
| Monthly cost estimate   | $70-120                                | $135,000-155,000                        | $22,000-25,000                           |
| Primary decision factor | Cost + GCP-native + simplicity         | Multi-cloud + Spark + data sharing      | Spark integration + ML + AWS              |
| Biggest risk            | Query cost spikes                      | Hybrid complexity and cost               | Analyst adoption curve                    |


Reflection Questions
Did the same platform win for all three? Why or why not?

No. BigQuery won for FreshCart, hybrid Databricks+Snowflake for FinanceCore, and Databricks for MediaStream. This demonstrates that there is no one-size-fits-all data warehouse. Each company's cloud strategy, team skills, budget, and workloads dictated different optimal choices. FreshCart needed cost-effective GCP-native simplicity; FinanceCore required multi-cloud Spark power with regulated sharing; MediaStream needed AWS-based Spark acceleration with ML capabilities.

What was the single most important factor in each decision?

FreshCart: Cost within $2K/month (tied with GCP integration) – a startup can't overspend on infrastructure

FinanceCore: Multi-cloud support and Spark integration – non-negotiable for investment banking compliance and existing team skills

MediaStream: Spark integration – because they're already struggling with Redshift and need better Spark support

Would your recommendation change if each company's budget doubled? Halved?

FreshCart (budget doubled to $4K): Still BigQuery – the simplicity and GCP-native advantage remains. At $4K they could add Looker for better BI.

FreshCart (budget halved to $1K): Still BigQuery – on-demand pricing scales down perfectly. They'd just run fewer queries.

FinanceCore (budget doubled to $300K): Still hybrid – they'd add more slots and enterprise features. Budget isn't the constraint.

FinanceCore (budget halved to $75K): Would have to choose one platform – probably Databricks for Spark, and use Delta Sharing instead of Snowflake (scoring drops to 7.5-8.0)

MediaStream (budget doubled to $50K): Still Databricks – they'd add more ML capabilities and Photon acceleration

MediaStream (budget halved to $12.5K): Would struggle – might need to keep some workloads in Redshift and migrate gradually

Which company has the most complex decision? Why?

FinanceCore has the most complex decision. The multi-cloud requirement (AWS + Azure), massive 500TB scale, strong Spark team, and regulatory data sharing needs create competing priorities that no single platform fully satisfies. The hybrid solution adds significant cost and complexity but may be unavoidable. FinanceCore must balance technical excellence, regulatory compliance, and budget—a much harder problem than FreshCart's simple cost-driven choice or MediaStream's straightforward Spark migration.


# Task 5: Reusable Decision Framework

# Cloud Data Warehouse Selection Framework

## Step 1: Profile Your Organization
- Cloud provider(s): ___________
- Data volume: _____ TB, growth rate: _____%/year
- Team skills: SQL _____, Spark _____, Python _____ (rate 1-10)
- Budget: $______/month
- Key workloads: _______________________________________________

## Step 2: Identify Your Top 5 Criteria
1. _________________________________ (weight: ___%)
2. _________________________________ (weight: ___%)
3. _________________________________ (weight: ___%)
4. _________________________________ (weight: ___%)
5. _________________________________ (weight: ___%)

## Step 3: Score Platforms (1-10)
=============================================================================================================
| Criterion               | Weight | Snowflake | BigQuery | Redshift | Databricks |
|-------------------------|--------|-----------|----------|----------|------------|
| _______________________ | ___%   |           |          |          |            |
| _______________________ | ___%   |           |          |          |            |
| _______________________ | ___%   |           |          |          |            |
| _______________________ | ___%   |           |          |          |            |
| _______________________ | ___%   |           |          |          |            |

## Step 4: Calculate Weighted Scores
=============================================================================================================
| Platform    | C1 (__%) | C2 (__%) | C3 (__%) | C4 (__%) | C5 (__%) | Total  |
|-------------|----------|----------|----------|----------|----------|--------|
| Snowflake   |          |          |          |          |          |        |
| BigQuery    |          |          |          |          |          |        |
| Redshift    |          |          |          |          |          |        |
| Databricks  |          |          |          |          |          |        |

## Step 5: Estimate Costs
=============================================================================================================
| Platform    | Storage (__TB × rate) | Compute Estimate | Total Monthly | Notes |
|-------------|----------------------|-------------------|---------------|-------|
| Snowflake   | $___                  | $___              | $___          |       |
| BigQuery    | $___                  | $___              | $___          |       |
| Redshift    | $___                  | $___              | $___          |       |
| Databricks  | $___                  | $___              | $___          |       |

## Step 6: Assess Risks
=============================================================================================================
| Platform    | Risk 1              | Risk 2              | Risk 3              | Mitigation Strategy |
|-------------|---------------------|---------------------|---------------------|---------------------|
| Snowflake   |                     |                     |                     |                     |
| BigQuery    |                     |                     |                     |                     |
| Redshift    |                     |                     |                     |                     |
| Databricks  |                     |                     |                     |                     |

## Step 7: Consider Hybrid Options
=============================================================================================================
| Option                      | Pros                                  | Cons                                 | Viability (1-10) |
|-----------------------------|---------------------------------------|--------------------------------------|------------------|
| Single platform (winner)    |                                       |                                      |                  |
| Databricks + Snowflake      |                                       |                                      |                  |
| Databricks + BigQuery       |                                       |                                      |                  |
| Snowflake + Redshift        |                                       |                                      |                  |

## Step 8: Final Recommendation

### Recommended Platform: _________________

**Executive Summary**
_________________________________________________________________
_________________________________________________________________

**Key Strengths**
1. _________________________________________________________________
2. _________________________________________________________________
3. _________________________________________________________________

**Key Risks and Mitigations**
1. Risk: _________________ → Mitigation: _________________
2. Risk: _________________ → Mitigation: _________________

**Estimated Monthly Cost: $______**

## Step 9: 30-Day POC Plan
=============================================================================================================
| Week | Activities | Success Criteria |
|------|------------|------------------|
| 1    |            |                  |
| 2    |            |                  |
| 3    |            |                  |
| 4    |            |                  |




