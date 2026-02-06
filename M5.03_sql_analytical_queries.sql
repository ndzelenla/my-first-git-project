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
  (1008, '2024-01-08', 'C003', 'South', 'Monitor', 1, 12000),
  (1009, '2024-01-09', 'C001', 'East', 'Keyboard', 2, 1500),
  (1010, '2024-01-10', 'C002', 'West', 'Mouse', 1, 500);

-- verify data
SELECT * FROM sales ORDER BY order_date;

WITH order_revenue AS (
  SELECT 
    order_id,
    order_date,
    customer_id,
    region,
    product,
    quantity,
    price,
    quantity * price AS revenue
  FROM sales
)
SELECT * FROM order_revenue;

WITH order_revenue AS (
  SELECT 
    order_id,
    order_date,
    customer_id,
    region,
    product,
    quantity * price AS revenue
  FROM sales
)
SELECT 
  region,
  SUM(revenue) AS total_revenue,
  COUNT(*) AS order_count
FROM order_revenue
GROUP BY region
ORDER BY total_revenue DESC;

WITH order_revenue AS (
  SELECT 
    order_id,
    order_date,
    customer_id,
    region,
    product,
    quantity * price AS revenue
  FROM sales
),
region_summary AS (
  SELECT 
    region,
    SUM(revenue) AS total_revenue,
    COUNT(*) AS order_count
  FROM order_revenue
  GROUP BY region
)
SELECT 
  region,
  total_revenue,
  order_count,
  total_revenue / order_count AS avg_order_value
FROM region_summary
ORDER BY total_revenue DESC;

WITH product_revenue AS (
  SELECT 
    product,
    SUM(quantity * price) AS total_revenue
  FROM sales
  GROUP BY product
)
SELECT 
  product,
  total_revenue,
  RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank,
  ROW_NUMBER() OVER (ORDER BY total_revenue DESC) AS row_number_rank
FROM product_revenue;

WITH customer_revenue AS (
  SELECT 
    customer_id,
    region,
    SUM(quantity * price) AS total_revenue
  FROM sales
  GROUP BY customer_id, region
)
SELECT 
  customer_id,
  region,
  total_revenue,
  RANK() OVER (
    PARTITION BY region 
    ORDER BY total_revenue DESC
  ) AS rank_in_region
FROM customer_revenue
ORDER BY region, rank_in_region;

-- compare rank vs row number vs dense rank
WITH product_revenue AS (
  SELECT 
    product,
    SUM(quantity * price) AS total_revenue
  FROM sales
  GROUP BY product
)
SELECT 
  product,
  total_revenue,
  RANK() OVER (ORDER BY total_revenue DESC) AS rank_value,
  DENSE_RANK() OVER (ORDER BY total_revenue DESC) AS dense_rank_value,
  ROW_NUMBER() OVER (ORDER BY total_revenue DESC) AS row_number_value
FROM product_revenue;


-- calculate daily revenue
WITH daily_revenue AS (
  SELECT 
    order_date,
    SUM(quantity * price) AS daily_revenue
  FROM sales
  GROUP BY order_date
)
SELECT * FROM daily_revenue ORDER BY order_date;

-- use lag for day over day comparison
WITH daily_revenue AS (
  SELECT 
    order_date,
    SUM(quantity * price) AS daily_revenue
  FROM sales
  GROUP BY order_date
)
SELECT 
  order_date,
  daily_revenue,
  LAG(daily_revenue, 1) OVER (ORDER BY order_date) AS previous_day_revenue,
  daily_revenue - LAG(daily_revenue, 1) OVER (ORDER BY order_date) AS day_over_day_change,
  CASE 
    WHEN daily_revenue > LAG(daily_revenue, 1) OVER (ORDER BY order_date) THEN 'GROWTH'
    WHEN daily_revenue < LAG(daily_revenue, 1) OVER (ORDER BY order_date) THEN 'DECLINE'
    ELSE 'STABLE'
  END AS trend
FROM daily_revenue
ORDER BY order_date;

-- calculate percentage change
WITH daily_revenue AS (
  SELECT 
    order_date,
    SUM(quantity * price) AS daily_revenue
  FROM sales
  GROUP BY order_date
),
daily_comparison AS (
  SELECT 
    order_date,
    daily_revenue,
    LAG(daily_revenue, 1) OVER (ORDER BY order_date) AS previous_day_revenue
  FROM daily_revenue
)
SELECT 
  order_date,
  daily_revenue,
  previous_day_revenue,
  ROUND(
    ((daily_revenue - previous_day_revenue) / previous_day_revenue * 100), 
    2
  ) AS percent_change
FROM daily_comparison
WHERE previous_day_revenue IS NOT NULL
ORDER BY order_date;

-- use CTEs for the same queries for readability
-- Complex query refactored with CTEs
WITH order_revenue AS (
  -- Step 1: Calculate revenue per order
  SELECT 
    order_id,
    order_date,
    customer_id,
    region,
    product,
    quantity * price AS revenue
  FROM sales
),
customer_totals AS (
  -- Step 2: Aggregate by customer
  SELECT 
    customer_id,
    region,
    SUM(revenue) AS total_revenue,
    COUNT(*) AS order_count
  FROM order_revenue
  GROUP BY customer_id, region
),
customer_rankings AS (
  -- Step 3: Rank customers within regions
  SELECT 
    customer_id,
    region,
    total_revenue,
    order_count,
    RANK() OVER (
      PARTITION BY region 
      ORDER BY total_revenue DESC
    ) AS rank_in_region
  FROM customer_totals
)
-- Step 4: Final output
SELECT 
  customer_id,
  region,
  total_revenue,
  order_count,
  rank_in_region
FROM customer_rankings
WHERE rank_in_region <= 2  -- Top 2 customers per region
ORDER BY region, rank_in_region;

/*
ANALYTICAL QUERY BREAKDOWN:
===========================

Step 1 (order_revenue CTE):
- Calculate revenue for each order line
- Base calculation: quantity * price

Step 2 (customer_totals CTE):
- Aggregate revenue by customer and region
- Count orders per customer

Step 3 (customer_rankings CTE):
- Rank customers within each region
- Uses window function with PARTITION BY

Step 4 (Final SELECT):
- Filter to top 2 customers per region
- Order results for readability
*/


-- Comprehensive analytical query using CTEs and window functions
WITH order_revenue AS (
  SELECT 
    order_id,
    order_date,
    customer_id,
    region,
    product,
    quantity * price AS revenue
  FROM sales
),
daily_summary AS (
  SELECT 
    order_date,
    SUM(revenue) AS daily_revenue,
    COUNT(DISTINCT customer_id) AS unique_customers
  FROM order_revenue
  GROUP BY order_date
),
daily_trends AS (
  SELECT 
    order_date,
    daily_revenue,
    unique_customers,
    LAG(daily_revenue, 1) OVER (ORDER BY order_date) AS prev_day_revenue,
    daily_revenue - LAG(daily_revenue, 1) OVER (ORDER BY order_date) AS day_over_day_change
  FROM daily_summary
)
SELECT 
  order_date,
  daily_revenue,
  unique_customers,
  prev_day_revenue,
  day_over_day_change,
  CASE 
    WHEN day_over_day_change > 0 THEN 'GROWTH'
    WHEN day_over_day_change < 0 THEN 'DECLINE'
    ELSE 'STABLE'
  END AS trend
FROM daily_trends
ORDER BY order_date;




