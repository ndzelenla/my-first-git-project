-- Create orders table
CREATE TABLE orders (
  order_id INT PRIMARY KEY,
  customer_id INT,
  order_date DATE,
  region VARCHAR(50),
  amount DECIMAL(10,2)
);

-- Set recursion depth limit
SET SESSION cte_max_recursion_depth = 1000000;

-- Get the maximum order_id currently in the table
SELECT @max_id := COALESCE(MAX(order_id), 0) FROM orders;

-- Insert 100,000 new records with unique IDs
INSERT INTO orders (order_id, customer_id, order_date, region, amount)
WITH RECURSIVE numbers AS (
  SELECT 1 AS n
  UNION ALL
  SELECT n + 1 FROM numbers WHERE n < 100000
)
SELECT 
  @max_id + n AS order_id,
  FLOOR(RAND() * 1001) AS customer_id,
  CURDATE() - INTERVAL FLOOR(RAND() * 365) DAY AS order_date,
  ELT(FLOOR(RAND() * 4) + 1, 'North', 'South', 'East', 'West') AS region,
  ROUND(RAND() * 1000 + 10, 2) AS amount
FROM numbers;
## check data
select * from orders;

## Filter by order_date:
SELECT * FROM orders 
WHERE order_date >= '2024-01-01';
## 0.000 sec/0.016sec

## Filter by region:
SELECT * FROM orders 
WHERE region = 'North';
## 0.000 sec/0.000sec

## Filter by customer_id:
SELECT * FROM orders 
WHERE customer_id = 42;
## 0.032 sec/0.000sec

## Step 2: Add Indexes (15 mins)
## Create indexes on:

# Index on order_date:
CREATE INDEX idx_orders_order_date ON orders(order_date);
## 0.828sec

# Index on region:
CREATE INDEX idx_orders_region ON orders(region);
# 0.719sec

# Index on customer_id:
CREATE INDEX idx_orders_customer_id ON orders(customer_id);
# 0.562sec

# Verify indexes are created:
SHOW INDEXES FROM orders;

#### run the code with indexes applied
## Filter by order_date:
SELECT * FROM orders 
WHERE order_date >= '2024-01-01';
## 0.016 sec/0.000sec

## Filter by region:
SELECT * FROM orders 
WHERE region = 'North';
## 0.016 sec/0.000sec

## Filter by customer_id:
SELECT * FROM orders 
WHERE customer_id = 42;
## 0.000 sec/0.000sec

#Query                      | Before Index | After Index | Improvement | Notes
#---------------------------|--------------|-------------|-------------|----------------------
#Filter by order_date       | 0.000 sec    | 0.016 sec   | 16x slower  | indexing not needed here
#Filter by region           | 0.000 sec    | 0.016 sec   | 16x slower  | indexing not needed here
#Filter by customer_id      | 0.032 sec    | 0.000 sec   | 32x faster  | indexing helped in this case

## Measure write performance:

## Test INSERT performance without indexes:
-- Drop indexes temporarily
DROP INDEX idx_orders_order_date ON orders;
DROP INDEX idx_orders_region ON orders;
DROP INDEX idx_orders_customer_id ON orders;

-- Time an INSERT
INSERT INTO orders (order_id, customer_id, order_date, region, amount)
VALUES (100001, 500, CURRENT_DATE, 'North', 250.00);
## 0.015sec

## Recreate indexes and test INSERT again:
CREATE INDEX idx_orders_order_date ON orders(order_date);
CREATE INDEX idx_orders_region ON orders(region);
CREATE INDEX idx_orders_customer_id ON orders(customer_id);

-- Time the same INSERT
INSERT INTO orders (order_id, customer_id, order_date, region, amount)
VALUES (100002, 501, CURRENT_DATE, 'South', 300.00);
# 0.047sec

#Question                                            | Answer
#----------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
#Why do indexes speed up reads?                      |                                                                                                                                                                                                                                                                                                                                                                                               
#- How indexes reduce the number of rows scanned     | Without an index, MySQL performs a full table scan (reads every row). With an index, MySQL navigates directly to the relevant rows using the index structure, scanning only a tiny fraction of the table. Example: Finding a row in a 1M row table might scan 1M rows without index vs. 3-4 index traversals + 1 row read with index.
#- How B-tree indexes enable fast lookups           | B-trees maintain a balanced, sorted tree structure where each node contains key values and pointers. The tree height remains low (typically 3-4 levels for millions of rows). Each traversal step eliminates ~50% of remaining data, enabling O(log n) search complexity vs. O(n) full table scans.
#----------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
#Why do indexes slow down writes?                   |                                                                                                                                                                                                                                                                                                                                                                                               
#- What happens during INSERT/UPDATE/DELETE          | Every data modification must also update ALL indexes on that table. An INSERT adds one row to the table + one entry to each index. An UPDATE may require removing old key values and inserting new ones. A DELETE removes the row + one entry from each index.
#- Maintenance overhead                             | Indexes must stay balanced. When index pages fill up, they split into two pages (costly). Updates may cause page reorganizations. The more indexes, the more I/O operations and CPU time per write.
#----------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
#Why are too many indexes harmful?                  |                                                                                                                                                                                                                                                                                                                                                                                               
#- Cumulative effect on write performance           | Write slowdown is multiplicative: 5 indexes = ~5x more work for writes. Each INSERT now requires updating the table + 5 index structures. In high-write environments, this can cause severe bottlenecks and lock contention.
#- Storage overhead                                 | Each index is a separate data structure stored on disk. A table with 10 indexes uses ~10x more storage space than the table itself. This increases backup time, recovery time, and memory usage for index caching.
#- Maintenance complexity                          | More indexes = more careful planning needed for schema changes. Query optimizer has more execution plans to evaluate (harder to predict which index will be used). DBA must analyze index usage patterns and identify unused indexes that still incur write penalties.

