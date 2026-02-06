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
  (1010, '2024-01-10', 'C002', 'West', 'Mouse', 1, 500),
  (1011, '2024-01-11', 'C005', 'East', 'Monitor', 1, 12000),
  (1012, '2024-01-12', 'C002', 'West', 'Keyboard', 3, 1500),
  (1013, '2024-01-13', 'C001', 'East', 'Mouse', 2, 500),
  (1014, '2024-01-14', 'C003', 'South', 'Keyboard', 1, 1500);


-- verify data 
SELECT COUNT(*) AS total_records FROM sales;

-- identify top 3 products
WITH product_revenue AS (
  SELECT 
    product,
    SUM(quantity * price) AS total_revenue
  FROM sales
  GROUP BY product
),
ranked_products AS (
  SELECT 
    product,
    total_revenue,
    RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank
  FROM product_revenue
)
SELECT 
  product,
  total_revenue,
  revenue_rank
FROM ranked_products
WHERE revenue_rank <= 3
ORDER BY revenue_rank;

-- top customers per region
WITH customer_revenue AS (
  SELECT 
    customer_id,
    region,
    SUM(quantity * price) AS total_revenue,
    COUNT(*) AS order_count
  FROM sales
  GROUP BY customer_id, region
),
ranked_customers AS (
  SELECT 
    customer_id,
    region,
    total_revenue,
    order_count,
    ROW_NUMBER() OVER (
      PARTITION BY region 
      ORDER BY total_revenue DESC
    ) AS rank_in_region
  FROM customer_revenue
)
SELECT 
  region,
  customer_id AS top_customer,
  total_revenue,
  order_count,
  CASE 
    WHEN total_revenue >= 20000 THEN 'HIGH_VALUE'
    WHEN total_revenue >= 10000 THEN 'MEDIUM_VALUE'
    ELSE 'LOW_VALUE'
  END AS customer_segment
FROM ranked_customers
WHERE rank_in_region = 1
ORDER BY region;

-- rolling 7 day average revenue
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
  AVG(daily_revenue) OVER (
    ORDER BY order_date 
    ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
  ) AS rolling_7day_avg
FROM daily_revenue
ORDER BY order_date;

-- revenue day over day with indicators
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
    LAG(daily_revenue, 1) OVER (ORDER BY order_date) AS previous_day_revenue,
    daily_revenue - LAG(daily_revenue, 1) OVER (ORDER BY order_date) AS day_over_day_change,
    ROUND(
      ((daily_revenue - LAG(daily_revenue, 1) OVER (ORDER BY order_date)) / 
       LAG(daily_revenue, 1) OVER (ORDER BY order_date) * 100), 
      2
    ) AS percent_change
  FROM daily_revenue
)
SELECT 
  order_date,
  daily_revenue,
  previous_day_revenue,
  day_over_day_change,
  percent_change,
  CASE 
    WHEN day_over_day_change > 0 THEN '↑ GROWTH'
    WHEN day_over_day_change < 0 THEN '↓ DECLINE'
    WHEN day_over_day_change = 0 THEN '→ STABLE'
    ELSE 'N/A'
  END AS trend
FROM daily_comparison
ORDER BY order_date;


-- ============================================
-- SQL Analytics Mini-Challenge
-- ============================================

-- Query 1: Top 3 Products by Total Revenue
WITH product_revenue AS (
  SELECT 
    product,
    SUM(quantity * price) AS total_revenue
  FROM sales
  GROUP BY product
),
ranked_products AS (
  SELECT 
    product,
    total_revenue,
    RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank
  FROM product_revenue
)
SELECT 
  product,
  total_revenue,
  revenue_rank
FROM ranked_products
WHERE revenue_rank <= 3
ORDER BY revenue_rank;

-- Query 2: Top Customer per Region
WITH customer_revenue AS (
  SELECT 
    customer_id,
    region,
    SUM(quantity * price) AS total_revenue,
    COUNT(*) AS order_count
  FROM sales
  GROUP BY customer_id, region
),
ranked_customers AS (
  SELECT 
    customer_id,
    region,
    total_revenue,
    order_count,
    ROW_NUMBER() OVER (
      PARTITION BY region 
      ORDER BY total_revenue DESC
    ) AS rank_in_region
  FROM customer_revenue
)
SELECT 
  region,
  customer_id AS top_customer,
  total_revenue,
  order_count,
  CASE 
    WHEN total_revenue >= 20000 THEN 'HIGH_VALUE'
    WHEN total_revenue >= 10000 THEN 'MEDIUM_VALUE'
    ELSE 'LOW_VALUE'
  END AS customer_segment
FROM ranked_customers
WHERE rank_in_region = 1
ORDER BY region;

-- Query 3: Rolling 7-Day Average Revenue
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
  AVG(daily_revenue) OVER (
    ORDER BY order_date 
    ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
  ) AS rolling_7day_avg
FROM daily_revenue
ORDER BY order_date;

-- Query 4: Revenue Trend Comparison Day-over-Day
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
    LAG(daily_revenue, 1) OVER (ORDER BY order_date) AS previous_day_revenue,
    daily_revenue - LAG(daily_revenue, 1) OVER (ORDER BY order_date) AS day_over_day_change,
    ROUND(
      ((daily_revenue - LAG(daily_revenue, 1) OVER (ORDER BY order_date)) / 
       LAG(daily_revenue, 1) OVER (ORDER BY order_date) * 100), 
      2
    ) AS percent_change
  FROM daily_revenue
)
SELECT 
  order_date,
  daily_revenue,
  previous_day_revenue,
  day_over_day_change,
  percent_change,
  CASE 
    WHEN day_over_day_change > 0 THEN '↑ GROWTH'
    WHEN day_over_day_change < 0 THEN '↓ DECLINE'
    WHEN day_over_day_change = 0 THEN '→ STABLE'
    ELSE 'N/A'
  END AS trend
FROM daily_comparison
ORDER BY order_date;
