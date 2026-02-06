CREATE TABLE sales (
  order_id INT,
  order_date DATE,
  customer_id VARCHAR(10),
  region VARCHAR(20),
  product VARCHAR(50),
  quantity INT,
  price INT
);


INSERT INTO sales VALUES
  (1001, '2024-01-01', 'C001', 'East', 'Keyboard', 2, 1500),
  (1002, '2024-01-02', 'C002', 'West', 'Mouse', 5, 500),
  (1003, '2024-01-03', 'C001', 'East', 'Monitor', 1, 12000),
  (1004, '2024-01-04', 'C003', 'South', 'Keyboard', 1, 1500),
  (1005, '2024-01-05', 'C002', 'West', 'Monitor', 2, 12000),
  (1006, '2024-01-06', 'C001', 'East', 'Mouse', 3, 500),
  (1007, '2024-01-07', 'C004', 'North', 'Keyboard', 4, 1500),
  (1008, '2024-01-08', 'C003', 'South', 'Monitor', 1, 12000);

SELECT * FROM sales;

SELECT 
  order_id,
  order_date,
  customer_id,
  region,
  product,
  quantity,
  price,
  quantity * price AS revenue
FROM sales;

-- Check total revenue
SELECT 
  SUM(quantity * price) AS total_revenue,
  COUNT(*) AS total_orders
FROM sales;

-- Manual verification for first few orders
SELECT 
  order_id,
  quantity,
  price,
  quantity * price AS calculated_revenue,
  (quantity * price) = (quantity * price) AS validation_check
FROM sales
LIMIT 5;

SELECT 
  region,
  SUM(quantity * price) AS total_revenue,
  COUNT(*) AS order_count
FROM sales
GROUP BY region
ORDER BY total_revenue DESC;

### Total revenue per product
SELECT 
  product,
  SUM(quantity * price) AS total_revenue,
  SUM(quantity) AS total_quantity_sold,
  COUNT(*) AS order_count
FROM sales
GROUP BY product
ORDER BY total_revenue DESC;

###average order values
SELECT 
  AVG(quantity * price) AS avg_order_value,
  SUM(quantity * price) / COUNT(*) AS avg_order_value_manual
FROM sales;

##Daily revenue trend
SELECT 
  order_date,
  SUM(quantity * price) AS daily_revenue,
  COUNT(*) AS daily_orders
FROM sales
GROUP BY order_date
ORDER BY order_date;

-- Revenue per region (East only)
SELECT 
  region,
  SUM(quantity * price) AS total_revenue
FROM sales
WHERE region = 'East'
GROUP BY region;

-- Verify no data loss in aggregations
SELECT 
  (SELECT COUNT(*) FROM sales) AS total_rows,
  (SELECT SUM(order_count) FROM (
    SELECT COUNT(*) AS order_count 
    FROM sales 
    GROUP BY region
  ) AS region_counts) AS aggregated_rows;

-- Check for duplicate order_ids
SELECT 
  order_id,
  COUNT(*) AS occurrence_count
FROM sales
GROUP BY order_id
HAVING COUNT(*) > 1;

-- Add comments documenting validation
/*
VALIDATION OBSERVATIONS:
1. Total revenue from individual rows matches aggregated totals
2. No duplicate order_ids found
3. All regions and products properly grouped
4. Date-based aggregations are accurate
*/

/*
SQL vs PYTHON RESPONSIBILITY ANALYSIS
=====================================

WHAT MUST STAY IN SQL:
-----------------------
1. Data filtering (WHERE clauses)
   - Reduces data transfer from database
   - Leverages database indexes
   - More efficient than Python filtering

2. Aggregations (GROUP BY, SUM, AVG, COUNT)
   - Database engines are optimized for aggregations
   - Reduces memory usage in Python
   - Faster than Python groupby operations

3. Joins between tables
   - Database join algorithms are highly optimized
   - Avoids loading entire tables into memory
   - Maintains referential integrity

4. Date/time operations
   - Database date functions are efficient
   - Timezone handling is built-in
   - Date arithmetic is optimized

5. Window functions (RANK, ROW_NUMBER, LAG)
   - Complex analytical operations
   - Database-optimized implementations
   - Reduces data transfer

WHAT CAN SAFELY MOVE TO PYTHON:
--------------------------------
1. Complex string manipulations
   - Regex operations
   - Custom text processing
   - Multi-step transformations

2. API integrations
   - External data fetching
   - Web scraping
   - Third-party service calls

3. Machine learning operations
   - Model training
   - Feature engineering for ML
   - Model predictions

4. Custom business logic
   - Complex conditional rules
   - Multi-step calculations
   - Custom algorithms

5. Data visualization
   - Chart generation
   - Report formatting
   - Dashboard creation

RECOMMENDATION:
--------------
Use SQL for:
- Data extraction and filtering
- Aggregations and summaries
- Joins and data combination
- Analytical queries

Use Python for:
- Complex transformations
- External integrations
- ML/AI operations
- Visualization and reporting
*/

-- ============================================
-- SQL Analytics: Python vs SQL Responsibilities
-- ============================================

-- Step 1: Revenue Calculation
SELECT 
  order_id,
  order_date,
  customer_id,
  region,
  product,
  quantity,
  price,
  quantity * price AS revenue
FROM sales;

-- Step 2: Total Revenue per Region
SELECT 
  region,
  SUM(quantity * price) AS total_revenue,
  COUNT(*) AS order_count
FROM sales
GROUP BY region
ORDER BY total_revenue DESC;

-- Step 3: Total Revenue per Product
SELECT 
  product,
  SUM(quantity * price) AS total_revenue,
  SUM(quantity) AS total_quantity_sold,
  COUNT(*) AS order_count
FROM sales
GROUP BY product
ORDER BY total_revenue DESC;

-- Step 4: Average Order Value
SELECT 
  AVG(quantity * price) AS avg_order_value
FROM sales;

-- Step 5: Daily Revenue Trend
SELECT 
  order_date,
  SUM(quantity * price) AS daily_revenue,
  COUNT(*) AS daily_orders
FROM sales
GROUP BY order_date
ORDER BY order_date;

-- Step 6: Validation Queries
-- Check total revenue consistency
SELECT 
  SUM(quantity * price) AS total_revenue
FROM sales;

-- Verify no duplicates
SELECT 
  order_id,
  COUNT(*) AS occurrence_count
FROM sales
GROUP BY order_id
HAVING COUNT(*) > 1;
