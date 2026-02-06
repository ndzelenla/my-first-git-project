CREATE TABLE customers (
  customer_id VARCHAR(10) PRIMARY KEY,
  customer_name VARCHAR(50),
  region VARCHAR(20)
);

CREATE TABLE orders (
  order_id INT PRIMARY KEY,
  customer_id VARCHAR(10),
  order_date DATE,
  FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

-- create order table
CREATE TABLE order_items (
  order_id INT,
  product VARCHAR(50),
  quantity INT,
  price INT,
  FOREIGN KEY (order_id) REFERENCES orders(order_id)
);

-- insert sample data
-- Insert customers
INSERT INTO customers VALUES
  ('C001', 'Alex', 'East'),
  ('C002', 'Bob', 'West'),
  ('C003', 'Charlie', 'South'),
  ('C004', 'Diana', 'East');

-- Insert orders
INSERT INTO orders VALUES
  (1001, 'C001', '2024-01-01'),
  (1002, 'C002', '2024-01-02'),
  (1003, 'C001', '2024-01-03'),
  (1004, 'C003', '2024-01-04'),
  (1005, 'C002', '2024-01-05');

-- Insert order items
INSERT INTO order_items VALUES
  (1001, 'Keyboard', 2, 1500),
  (1001, 'Mouse', 1, 500),
  (1002, 'Monitor', 1, 12000),
  (1003, 'Keyboard', 1, 1500),
  (1004, 'Mouse', 3, 500),
  (1005, 'Monitor', 2, 12000);

SELECT 'Customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL
SELECT 'Orders', COUNT(*) FROM orders
UNION ALL
SELECT 'Order Items', COUNT(*) FROM order_items;

SELECT 
  o.order_id,
  o.order_date,
  c.customer_id,
  c.customer_name,
  c.region
FROM orders o
INNER JOIN customers c ON o.customer_id = c.customer_id;

-- Count before join
SELECT 
  (SELECT COUNT(*) FROM orders) AS orders_count,
  (SELECT COUNT(*) FROM customers) AS customers_count;

-- Count after join
SELECT COUNT(*) AS joined_rows_count
FROM orders o
INNER JOIN customers c ON o.customer_id = c.customer_id;

-- Orders without matching customers (should be 0)
SELECT o.*
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- Customers without orders
SELECT c.*
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
WHERE o.order_id IS NULL;

SELECT 
  o.order_id,
  o.order_date,
  c.customer_name,
  c.region,
  oi.product,
  oi.quantity,
  oi.price,
  oi.quantity * oi.price AS revenue
FROM orders o
INNER JOIN customers c ON o.customer_id = c.customer_id
INNER JOIN order_items oi ON o.order_id = oi.order_id
ORDER BY o.order_id, oi.product;

-- Expected: Should match number of order_items (6 rows)
SELECT COUNT(*) AS joined_rows
FROM orders o
INNER JOIN customers c ON o.customer_id = c.customer_id
INNER JOIN order_items oi ON o.order_id = oi.order_id;

SELECT 
  SUM(oi.quantity * oi.price) AS total_revenue
FROM orders o
INNER JOIN customers c ON o.customer_id = c.customer_id
INNER JOIN order_items oi ON o.order_id = oi.order_id;

-- INCORRECT: Missing join condition creates cartesian product
SELECT 
  o.order_id,
  c.customer_name,
  oi.product
FROM orders o, customers c, order_items oi
-- Missing: WHERE or ON clauses
LIMIT 20;  -- Limit to see the explosion

-- This will show the cartesian product
SELECT COUNT(*) AS cartesian_product_rows
FROM orders o, customers c, order_items oi;
-- Result: 5 orders × 4 customers × 6 order_items = 120 rows (WRONG!)

-- CORRECT: Proper join conditions
SELECT 
  o.order_id,
  c.customer_name,
  oi.product
FROM orders o
INNER JOIN customers c ON o.customer_id = c.customer_id
INNER JOIN order_items oi ON o.order_id = oi.order_id;
-- Result: 6 rows (CORRECT - matches order_items count)

/*
CARTESIAN PRODUCT ANALYSIS:
---------------------------
Incorrect join (missing conditions):
- Orders: 5 rows
- Customers: 4 rows  
- Order Items: 6 rows
- Result: 5 × 4 × 6 = 120 rows (WRONG!)

Correct join (with proper conditions):
- Result: 6 rows (CORRECT - matches order_items)

LESSON: Always specify join conditions!
*/

-- Validation: Row counts should make sense
SELECT 
  'Order Items (source)' AS source,
  COUNT(*) AS row_count
FROM order_items
UNION ALL
SELECT 
  'After 3-table join' AS source,
  COUNT(*)
FROM orders o
INNER JOIN customers c ON o.customer_id = c.customer_id
INNER JOIN order_items oi ON o.order_id = oi.order_id;

-- Revenue from order_items directly
SELECT 
  'Direct from order_items' AS source,
  SUM(quantity * price) AS total_revenue
FROM order_items
UNION ALL
-- Revenue from joined tables
SELECT 
  'From joined tables' AS source,
  SUM(oi.quantity * oi.price) AS total_revenue
FROM orders o
INNER JOIN customers c ON o.customer_id = c.customer_id
INNER JOIN order_items oi ON o.order_id = oi.order_id;
-- These should match!

-- Verify no order is counted multiple times
SELECT 
  o.order_id,
  COUNT(*) AS item_count,
  SUM(oi.quantity * oi.price) AS order_revenue
FROM orders o
INNER JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY o.order_id
ORDER BY o.order_id;

-- Check one-to-many relationships are correct
SELECT 
  'Orders to Order Items' AS relationship,
  COUNT(DISTINCT o.order_id) AS orders,
  COUNT(oi.order_id) AS order_items,
  COUNT(oi.order_id) / COUNT(DISTINCT o.order_id) AS avg_items_per_order
FROM orders o
INNER JOIN order_items oi ON o.order_id = oi.order_id;

-- ============================================
-- SQL Joins: Correctness and Validation
-- ============================================

-- Step 1: Base Join (Orders + Customers)
SELECT 
  o.order_id,
  o.order_date,
  c.customer_name,
  c.region
FROM orders o
INNER JOIN customers c ON o.customer_id = c.customer_id;

-- Step 2: Multi-table Join (All three tables)
SELECT 
  o.order_id,
  o.order_date,
  c.customer_name,
  c.region,
  oi.product,
  oi.quantity,
  oi.price,
  oi.quantity * oi.price AS revenue
FROM orders o
INNER JOIN customers c ON o.customer_id = c.customer_id
INNER JOIN order_items oi ON o.order_id = oi.order_id;

-- Step 3: Revenue Aggregation
SELECT 
  c.region,
  SUM(oi.quantity * oi.price) AS total_revenue
FROM orders o
INNER JOIN customers c ON o.customer_id = c.customer_id
INNER JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY c.region;

-- Step 4: Validation Queries
-- Check row counts
SELECT COUNT(*) AS joined_rows
FROM orders o
INNER JOIN customers c ON o.customer_id = c.customer_id
INNER JOIN order_items oi ON o.order_id = oi.order_id;

-- Validate revenue consistency
SELECT 
  SUM(oi.quantity * oi.price) AS total_revenue
FROM orders o
INNER JOIN customers c ON o.customer_id = c.customer_id
INNER JOIN order_items oi ON o.order_id = oi.order_id;

