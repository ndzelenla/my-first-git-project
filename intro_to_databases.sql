
-- PRIMARY KEY 
-- uniquely identifies each row in table
-- no two rows can have same primary key
-- unique and not null 
-- rach table should exactly primary key 
-- auto creates a clustured index - for faster lookups

-- foreign key 
-- sytax : FOREIGN KEY(column_name) REFERENCES parent_table(parent_column)
-- column that creates relationship between 2 table by referencing the primary key of another table
-- pointer that says : this row is connected to that row in the table
-- references a primary key in another table
-- can contain NULL values 
-- enforces referential integrity - you cannot insert invalid references
-- multiple foreign keys can exist in a single table

-- references clause : used when creating foreign key 
-- which table are you linking to 
-- enforces only valid values (the ones existing ones in parent table) 



-- ============================================
-- STEP 1: Create the Database
-- ============================================
DROP DATABASE IF EXISTS banking_system;
CREATE DATABASE banking_system_x;
USE banking_system_x;
USE banking_system_x;

-- ============================================
-- STEP 2: Create CUSTOMERS Table (Parent Table)
-- ============================================
CREATE TABLE customers (
    customer_id INT PRIMARY KEY AUTO_INCREMENT,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(15),
    account_type ENUM('Savings', 'Current', 'Premium') NOT NULL,  -- enum : enumerated : string data type : restrict a column to only choose from a pre defined list of values
    account_balance DECIMAL(12, 2) DEFAULT 0.00,
    date_opened DATE NOT NULL,
    credit_score INT,  -- Removed CHECK constraint
    is_active BOOLEAN DEFAULT TRUE
);

-- --------------
-- enum
 -- data integrity : case senstive : data validation : 
 -- storage efficient : 1 or 2 bytes
 -- query performance : WHERE status="completed" 

-- --------------

-- ============================================
-- STEP 3: Create TRANSACTIONS Table (Child Table)
-- ============================================
CREATE TABLE transactions (
    transaction_id INT PRIMARY KEY AUTO_INCREMENT,
    customer_id INT NOT NULL,
    transaction_type ENUM('Deposit', 'Withdrawal', 'Transfer', 'Payment') NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    transaction_date DATETIME NOT NULL,
    merchant_name VARCHAR(100),
    category VARCHAR(50),
    status ENUM('Completed', 'Pending', 'Failed') DEFAULT 'Completed',
    
    -- Foreign Key Constraint with REFERENCES
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id) -- DELETE FROM customers WHERE customer_id = 1;
        ON DELETE RESTRICT  -- prevents from deleting the row in the parent table, even if there are related rows in the child table
        ON UPDATE CASCADE -- auto updating child rows in the foregin key when primary key parent row changes
);

-- ============================================
-- STEP 4: Insert 25 Customer Records
-- ============================================
INSERT INTO customers (first_name, last_name, email, phone, account_type, account_balance, date_opened, credit_score, is_active) VALUES
('Rajesh', 'Kumar', 'rajesh.kumar@email.com', '9876543210', 'Savings', 125000.50, '2020-01-15', 720, TRUE),
('Priya', 'Sharma', 'priya.sharma@email.com', '9876543211', 'Current', 350000.00, '2019-06-22', 780, TRUE),
('Amit', 'Patel', 'amit.patel@email.com', '9876543212', 'Premium', 1250000.75, '2018-03-10', 810, TRUE),
('Sneha', 'Reddy', 'sneha.reddy@email.com', '9876543213', 'Savings', 87500.25, '2021-07-18', 690, TRUE),
('Vikram', 'Singh', 'vikram.singh@email.com', '9876543214', 'Current', 425000.00, '2020-11-05', 750, TRUE),
('Ananya', 'Iyer', 'ananya.iyer@email.com', '9876543215', 'Savings', 65000.00, '2022-02-14', 670, TRUE),
('Rohan', 'Mehta', 'rohan.mehta@email.com', '9876543216', 'Premium', 2100000.50, '2017-09-30', 825, TRUE),
('Kavya', 'Nair', 'kavya.nair@email.com', '9876543217', 'Savings', 95000.75, '2021-04-12', 710, TRUE),
('Arjun', 'Desai', 'arjun.desai@email.com', '9876543218', 'Current', 180000.00, '2020-08-25', 730, TRUE),
('Meera', 'Chopra', 'meera.chopra@email.com', '9876543219', 'Savings', 110000.50, '2019-12-08', 695, TRUE),
('Karan', 'Malhotra', 'karan.malhotra@email.com', '9876543220', 'Premium', 875000.00, '2021-01-20', 795, TRUE),
('Divya', 'Gupta', 'divya.gupta@email.com', '9876543221', 'Current', 265000.25, '2020-05-17', 760, TRUE),
('Sahil', 'Verma', 'sahil.verma@email.com', '9876543222', 'Savings', 72000.00, '2022-06-30', 655, TRUE),
('Ishita', 'Bose', 'ishita.bose@email.com', '9876543223', 'Premium', 1650000.75, '2018-11-11', 815, TRUE),
('Aditya', 'Joshi', 'aditya.joshi@email.com', '9876543224', 'Savings', 98000.50, '2021-09-03', 705, TRUE),
('Riya', 'Kapoor', 'riya.kapoor@email.com', '9876543225', 'Current', 310000.00, '2019-07-28', 745, TRUE),
('Varun', 'Saxena', 'varun.saxena@email.com', '9876543226', 'Savings', 81000.25, '2022-03-15', 680, TRUE),
('Pooja', 'Rao', 'pooja.rao@email.com', '9876543227', 'Premium', 950000.50, '2020-10-22', 800, TRUE),
('Nikhil', 'Pandey', 'nikhil.pandey@email.com', '9876543228', 'Current', 195000.75, '2021-05-09', 725, TRUE),
('Tanvi', 'Agarwal', 'tanvi.agarwal@email.com', '9876543229', 'Savings', 68000.00, '2022-08-14', 665, TRUE),
('Siddharth', 'Bhatt', 'siddharth.bhatt@email.com', '9876543230', 'Premium', 1825000.25, '2017-04-19', 835, TRUE),
('Nisha', 'Pillai', 'nisha.pillai@email.com', '9876543231', 'Current', 275000.50, '2020-02-11', 755, TRUE),
('Rahul', 'Sinha', 'rahul.sinha@email.com', '9876543232', 'Savings', 91000.75, '2021-11-27', 700, TRUE),
('Anjali', 'Mishra', 'anjali.mishra@email.com', '9876543233', 'Premium', 1150000.00, '2019-08-06', 790, TRUE),
('Harsh', 'Thakur', 'harsh.thakur@email.com', '9876543234', 'Savings', 77000.50, '2022-01-09', 675, TRUE);

-- ============================================
-- STEP 5: Insert 25 Transaction Records
-- ============================================
INSERT INTO transactions (customer_id, transaction_type, amount, transaction_date, merchant_name, category, status) VALUES
(1, 'Deposit', 25000.00, '2024-01-15 10:30:00', 'Bank Branch', 'Income', 'Completed'),
(1, 'Withdrawal', 5000.00, '2024-01-20 14:15:00', 'ATM Withdrawal', 'Cash', 'Completed'),
(2, 'Payment', 15000.00, '2024-01-18 09:45:00', 'Amazon India', 'Shopping', 'Completed'),
(3, 'Transfer', 100000.00, '2024-01-22 11:20:00', 'Investment Account', 'Investment', 'Completed'),
(4, 'Deposit', 12000.00, '2024-01-25 16:00:00', 'Salary Credit', 'Income', 'Completed'),
(5, 'Payment', 8500.00, '2024-01-17 13:30:00', 'Flipkart', 'Shopping', 'Completed'),
(6, 'Withdrawal', 3000.00, '2024-01-19 10:00:00', 'ATM Withdrawal', 'Cash', 'Completed'),
(7, 'Transfer', 250000.00, '2024-01-21 15:45:00', 'Real Estate Payment', 'Property', 'Completed'),
(8, 'Deposit', 18000.00, '2024-01-23 09:15:00', 'Freelance Payment', 'Income', 'Completed'),
(9, 'Payment', 6500.00, '2024-01-24 12:00:00', 'Swiggy', 'Food', 'Completed'),
(10, 'Withdrawal', 4500.00, '2024-01-16 11:30:00', 'ATM Withdrawal', 'Cash', 'Completed'),
(11, 'Transfer', 75000.00, '2024-01-26 14:20:00', 'Mutual Fund', 'Investment', 'Completed'),
(12, 'Payment', 12000.00, '2024-01-27 10:45:00', 'Myntra', 'Shopping', 'Completed'),
(13, 'Deposit', 8000.00, '2024-01-28 16:30:00', 'Bank Branch', 'Income', 'Completed'),
(14, 'Transfer', 150000.00, '2024-01-29 09:00:00', 'Fixed Deposit', 'Investment', 'Completed'),
(15, 'Payment', 3500.00, '2024-01-30 13:15:00', 'BookMyShow', 'Entertainment', 'Completed'),
(16, 'Withdrawal', 7000.00, '2024-01-31 11:00:00', 'ATM Withdrawal', 'Cash', 'Completed'),
(17, 'Deposit', 9500.00, '2024-02-01 15:30:00', 'Part-time Income', 'Income', 'Completed'),
(18, 'Payment', 22000.00, '2024-02-02 10:20:00', 'Apple Store', 'Electronics', 'Completed'),
(19, 'Transfer', 45000.00, '2024-02-03 14:00:00', 'Education Loan', 'Education', 'Completed'),
(20, 'Withdrawal', 2500.00, '2024-02-04 09:30:00', 'ATM Withdrawal', 'Cash', 'Completed'),
(3, 'Payment', 85000.00, '2024-02-05 12:45:00', 'Car Insurance', 'Insurance', 'Completed'),
(7, 'Deposit', 300000.00, '2024-02-06 16:15:00', 'Business Income', 'Income', 'Completed'),
(11, 'Payment', 15500.00, '2024-02-01 11:30:00', 'MakeMyTrip', 'Travel', 'Pending'),
(14, 'Transfer', 125000.00, '2024-02-02 10:00:00', 'Gold Purchase', 'Investment', 'Failed');

SELECT * FROM customers;
SELECT * FROM transactions;

-- ---------- questions for practice --------------

-- find the total number of customers who has savings account

SELECT COUNT(*) AS saving_customers 
FROM customers
WHERE account_type = "Savings";

-- calculate the total transaction amount for each transaction type

SELECT transaction_type, SUM(amount) as total_amount, COUNT(*) AS transaction_count, ROUND(AVG(amount),2) as avg_amount
FROM transactions
GROUP BY transaction_type
ORDER BY total_amount DESC;

-- find the account types where the avg balance > 2,00,000

SELECT account_type, ROUND(AVG(account_balance),2) as avg_balance , count(*) as customer_count
FROM customers
GROUP BY account_type
HAVING AVG(account_balance) > 200000
ORDER BY avg_balance DESC;


-- For completed transactions only, find the minimum, maximum, and average transaction amount.
SELECT MIN(amount) as min_amt, max(amount) as max_amt, avg(amount) as avg_amt 
FROM transactions
where status = "Completed";


-- show the # of transactions and total amount for each customer and transaction type combination 

SELECT customer_id,transaction_type, COUNT(*) AS transaction_count,
ROUND(SUM(amount),2) as total_amt , ROUND(AVG(amount),2) as avg_amt
FROM transactions
GROUP BY customer_id,transaction_type
ORDER BY customer_id, total_amt DESC;


-- find customers who have made more than 1 transaction and whose total transaction amount > 50,000

SELECT customer_id, COUNT(*) AS transaction_count , SUM(amount) AS total_amt
FROM transactions
GROUP by customer_id
HAVING transaction_count > 1 AND total_amt > 50000
ORDER BY total_amt DESC;


-- for savings account holders , find those whos account balance > 80,000 and show the count per credit score range
-- case when (if-else condition in python)


SELECT
CASE 
WHEN credit_score < 680 THEN "Fair (300-679)"
WHEN credit_score BETWEEN 680 AND 739 THEN "Good (680-739)"
ELSE "Excellent (740+)"
END AS credit_range,
COUNT(*) as customer_count, AVG(account_balance) AS avg_balance, MIN(account_balance) AS min_balance,MAX(account_balance) AS max_balance
FROM customers
WHERE account_type = "Savings" AND account_balance > 80000
GROUP BY credit_range
HAVING customer_count >=2
ORDER BY avg_balance DESC;

-- Find transaction categories where the average transaction amount is higher than the overall average transaction amount across all categories.

SELECT category , count(*) as transaction_count, avg(amount) as avg_category_amt , 
ROUND((SELECT AVG(amount) FROM transactions),2) AS overall_avg,
ROUND(avg(amount) - (SELECT AVG(amount) FROM transactions),2) AS difference_from_avg
FROM transactions
WHERE category IS NOT NULL
GROUP BY category
HAVING avg(amount) > (SELECT AVG(amount) FROM transactions)
ORDER BY avg_category_amt desc;


-- JOINS
-- inner join, left join, right join, full outer join - union (mysql)

-- inner join : returns only those records where there is a match in both the tables

/*
Syntax  : 

SELECT columns
FROM table1
INNER JOIN table2
ON table1.column = table2.column
*/


SELECT * FROM customers;
SELECT * FROM transactions;

-- Show all the transactions along with customer's name and account type

SELECT t.transaction_id, t.transaction_date , 
c.customer_id, c.first_name , c.last_name, c.account_type,
t.transaction_type, t.amount, t.status
FROM customers c
INNER JOIN transactions t 
ON c.customer_id = t.customer_id;


-- Show all Premium account holders who made transactions above 50,000
-- filtering with where and inner join

SELECT c.customer_id , CONCAT(c.first_name, ' ', c.last_name) as full_name, c.account_type
FROM customers c
INNER JOIN transactions t 
ON c.customer_id = t.customer_id
WHERE c.account_type = "Premium" and t.amount>50000 AND t.status="Completed" 
ORDER BY t.amount DESC;


-- For each customer who has made transactions , show their total spending, transaction count, average transaction amount

SELECT c.customer_id, c.first_name, c.last_name, c.account_type, c.account_balance,
COUNT(t.transaction_id) as total_transactions,
SUM(t.amount) AS total_transactions_amount,
MIN(t.amount) AS min_transactions_amount,
MAX(t.amount) AS max_transactions_amount,
AVG(t.amount) AS avg_transactions_amount
FROM customers c
INNER JOIN transactions t 
ON c.customer_id = t.customer_id
where t.status ="Completed"
GROUP BY c.customer_id, c.first_name, c.last_name, c.account_type, c.account_balance
ORDER BY total_transactions_amount DESC;



-- Show all the savings account customers who made transactions in january 2024 , along with their credit scores

SELECT c.customer_id , CONCAT(c.first_name, ' ', c.last_name) as full_name, c.credit_score,c.account_balance,t.transaction_date, t.transaction_type,t.amount, t.merchant_name,
CASE
WHEN c.credit_score >= 750 THEN "excellent"
WHEN c.credit_score >= 700 THEN "good"
WHEN c.credit_score >= 650 THEN "fair"
ELSE "poor"
END AS credit_rating
FROM customers c
INNER JOIN transactions t 
ON c.customer_id = t.customer_id
WHERE c.account_type = "Savings" AND t.transaction_date >= "2024-01-01" AND t.transaction_date < "2024-02-01"
ORDER BY t.transaction_date;

-- --------LEFT JOIN -------------------
-- In left join, it takes all the records from the left table and matching records from the right table
-- if there's no match , the result will return NULL values for right table's columns

-- LETF JOIN : finding missing data
-- questions like ? Which customers have NO transactions ? 
-- Whcih accounts are inactive ? 
-- What;s missing from our data ? 


-- show all the customers and how many transactions each has made, including customers with zero transactions

SELECT c.customer_id , CONCAT(c.first_name, ' ', c.last_name) as full_name, c.account_type, c.account_balance, c.credit_score,
COUNT(t.transaction_id) as transaction_count, SUM(t.amount) as total_transactions_amount,
CASE
WHEN COUNT(t.transaction_id) = 0 THEN "Inactive"
WHEN COUNT(t.transaction_id) <=2  THEN "Low Activity"
ELSE "Active"
END AS activity_status
FROM customers c
LEFT JOIN transactions t
ON c.customer_id = t.customer_id
GROUP BY c.customer_id,full_name, c.account_type, c.account_balance, c.credit_score
ORDER BY transaction_count desc, c.account_balance DESC;


-- Show all the premium customers with their latest transaction details, include the customers who have not transacted yet

SELECT c.customer_id , CONCAT(c.first_name, ' ', c.last_name) as full_name, c.account_type, c.account_balance, c.credit_score,
t.transaction_id,c.date_opened,t.transaction_date,t.amount,t.status,
CASE
WHEN t.transaction_id IS NULL THEN "Never Transacted"
WHEN t.status ="Completed" THEN "Active"
WHEN t.status ="Pending" THEN "Pending Transaction"
WHEN t.status ="Failed" THEN "Failed Transaction"
END AS customer_status
FROM customers c
LEFT JOIN transactions t
ON c.customer_id = t.customer_id
WHERE c.account_type ="Premium"
ORDER BY c.account_balance DESC,t.transaction_date DESC;


-- Common Table Expressions - CTE
-- temporary result / temporary view , it remains only for runtime or duration of the query

/*
WITH cte_name AS (SELECT columns FROM table WHERE condition)

SELECT * FROM cte_name;

-- hard to read / difficult to break their logic
-- maintaining difficult

CTE are more readable as compared to sq

when to prefer CTE
-- complex multi step logic
-- nesting
-- hierarchical data

*/

-- Use a CTE to find all Premium account customers, then display their names and account balances

WITH premium_customers AS (SELECT customer_id,first_name,last_name,account_balance,credit_score FROM customers WHERE account_type ="Premium")

-- use the cte
SELECT customer_id, CONCAT(first_name, ' ', last_name) as full_name , account_balance,credit_score
FROM premium_customers
order by account_balance DESC;

-- Use a CTE to calculate how many transactions each customer has made, then show only customers with more than 1 transaction

WITH customer_transaction_count AS (SELECT customer_id, COUNT(*) AS transaction_count, SUM(amount) as total_amount FROM transactions WHERE status ='Completed' GROUP BY customer_id) 

-- Filtering for customers with multiple transactions
SELECT c.customer_id, CONCAT(c.first_name, ' ', c.last_name) as full_name, c.account_type,ctc.transaction_count,
ROUND(ctc.total_amount,2) as total_spent
FROM customers c
INNER JOIN customer_transaction_count ctc ON c.customer_id = ctc.customer_id
WHERE ctc.transaction_count > 1
ORDER BY ctc.transaction_count DESC , ctc.total_amount DESC;


-- Concept of Resubale CTEs
-- Find customers who have spent, more than average customer spending and show their details
-- First CTE calculate ther per customer totals, 2nd CTE that calculates the average , then compare

WITH customer_totals AS (SELECT customer_id, COUNT(*) AS transaction_count, SUM(amount) AS total_spent,AVG(amount) AS avg_transaction FROM transactions WHERE status ="Completed" GROUP BY customer_id),
spending_average AS (SELECT avg(total_spent) AS avg_customer_spending FROM customer_totals)

-- main query -- find customers above average
SELECT c.customer_id, CONCAT(c.first_name, ' ', c.last_name), c.account_type ,c.account_balance,ROUND(ct.total_spent,2) AS total_spent,
ROUND(ct.avg_transaction,2) AS avg_transaction, ROUND(ct.avg_transaction,2) AS avg_transaction,
ROUND(sa.avg_customer_spending,2) AS bank_average,
ROUND(ct.total_spent - sa.avg_customer_spending,2) AS above_average_by
FROM customers c
INNER JOIN customer_totals ct ON c.customer_id = ct.customer_id
CROSS JOIN spending_average sa
where ct.total_spent > sa.avg_customer_spending
order by ct.total_spent desc;

/*
### **Simple CROSS JOIN Example**

**Table A (Colors):**
```
color
Red
Blue
```

**Table B (Sizes):**
```
size
Small
Large

CROSS JOIN Result:

sql:
SELECT * 
FROM Colors 
CROSS JOIN Sizes;
```

**Output:**
```
color | size
Red   | Small
Red   | Large
Blue  | Small
Blue  | Large
```

**Every color matched with every size** = 2 colors × 2 sizes = **4 rows**

---

### **Why CROSS JOIN Works Here**

In our query:

**Left Side (after INNER JOIN):**
```
customer_id | customer_name   | total_spent | transaction_count
3          | Amit Patel      | 185000.00   | 2
7          | Rohan Mehta     | 550000.00   | 2
11         | Karan Malhotra  | 75000.00    | 1
14         | Ishita Bose     | 150000.00   | 1
... (20 customers with transactions)
```

**Right Side (spending_average CTE):**
```
avg_customer_spending
68575.00
```

**After CROSS JOIN:**
```
customer_id | customer_name   | total_spent | avg_customer_spending
3          | Amit Patel      | 185000.00   | 68575.00
7          | Rohan Mehta     | 550000.00   | 68575.00
11         | Karan Malhotra  | 75000.00    | 68575.00
14         | Ishita Bose     | 150000.00   | 68575.00
... (every customer now has the average value attached)
```

**Why This Works:**
- `spending_average` has only **ONE row** (one value: 68575.00)
- CROSS JOIN adds this same value to **every customer row**
- Now we can compare each customer's spending to the average!

*/

-- ---------------- WINDOW ANALYTIC FUNCTIONS --------------------------

-- Window functions performs calculations across a set of rows that are related to current row, without collapsing rows like groupby does
/*
function_name(COLUMN) OVER(parition by column1,column2,...  ORDER BY )

-- PARTITION BY - OPTIONAL
-- divides rows into groups like group by 
-- window functions calculates seperately for each partition

-- aggregate window functions

- SUM() OVER()

-- ranking functions
-- ROW_NUMBER() -- provides unique sequential number to the record
-- RANK() -- ranking with the gaps for ties
-- DENSE_RANK() -- ranking without gaps for ties

*/


-- with grouby 

SELECT account_type,AVG(account_balance) AS avg_balance
FROM customers
GROUP BY account_type;
-- we lose indiviual details

-- with window function 

SELECT customer_id,first_name, last_name, account_type,account_balance, 
AVG(account_balance) OVER(PARTITION BY account_type) as avg_for_acc_type
FROM customers;

-- we keep all customer details and add the group average


-- Rank all customers by their account balance within each account type. Show the top 3 from each type
-- CONCEPT : ROW_NUMBER() assigns unique sequential number to each row within the partition


WITH ranked_customers AS (
SELECT customer_id, CONCAT(first_name, ' ', last_name) AS customer_name, account_type, account_balance,credit_score,
ROW_NUMBER() OVER(PARTITION BY account_type ORDER BY account_balance DESC) AS balance_rank
FROM customers
)

SELECT customer_name,account_type,ROUND(account_balance,2) AS account_balance,credit_score,balance_rank
FROM ranked_customers
WHERE balance_rank <= 3
ORDER BY account_type, balance_rank;

-- RANK() v/s DENSE_RANK()
-- Rank customers by transaction count. Show how RANK() and DENSE_RANK() handle ties differently.
-- RANK() - Leaves gaps after ties
-- DENSE_RANK() - No gaps after ties


WITH customer_transaction_count AS (
SELECT c.customer_id, CONCAT(c.first_name, ' ', c.last_name) AS customer_name, c.account_type,
COUNT(t.transaction_id) AS transaction_count
FROM customers c
LEFT JOIN transactions t ON c.customer_id = t.customer_id
GROUP BY c.customer_id, customer_name,c.account_type
)

SELECT customer_name,account_type,transaction_count,
RANK() OVER (ORDER BY transaction_count DESC) AS rank_with_gaps,
DENSE_RANK() OVER (ORDER BY transaction_count DESC) AS rank_with_no_gaps,
ROW_NUMBER() OVER (ORDER BY transaction_count DESC) AS row_number_unique
FROM customer_transaction_count
ORDER BY transaction_count DESC;


/*
Practice Exercises: 

Exercise 1:
"Rank customers by credit score within each account type. Show top 2 from each type."


Exercise 2:
"Calculate running total of deposits for each customer, ordered by date."


Exercise 3:
"For each transaction, show how it compares to the customer's average transaction (above/below/equal)."


Exercise 4:
"Find each customer's largest transaction and calculate what percentage of their total spending it represents."


*/

/*
List all Premium account customers with account balance greater than ₹1,000,000. 
Show their name, email, account balance, and credit score. Order by account balance in descending order.
*/

SELECT * FROM customers;

SELECT * FROM transactions;


SELECT
customer_id, concat(first_name,' ',last_name) as full_name, email , ROUND(account_balance,2) as account_balance,credit_score
FROM customers
WHERE account_type = "Premium" and account_balance > 1000000
ORDER BY account_balance DESC;


/*
Calculate the total number of customers, average account balance, minimum balance, and maximum balance for each account type."
*/

select account_type, count(*) as total_customers,avg(account_balance) as avg_bal, min(account_balance) as min_bal, max(account_balance) as max_bal
from customers 
group by account_type
order by avg_bal desc;


/*
Show transaction types where the total transaction amount exceeds ₹100,000. Display the transaction type, count of transactions, and total amount.
*/

select transaction_type, count(*) as transaction_count, sum(amount) as total_amount, avg(amount) as avg_amt
from transactions
where status="Completed"
group by transaction_type
having sum(amount) > 100000
order by total_amount desc;



/*
Find all completed transactions that occurred in January 2024. Show transaction date, customer ID, transaction type, amount, and merchant name. Order by transaction date.
*/

select 
customer_id, transaction_id, transaction_date, 
date_format(transaction_date, '%W %M %d %Y') as formatted_date,ROUND(amount,2) as amount, merchant_name
from transactions
where status="Completed" and transaction_date >= "2024-01-01" and transaction_date < "2024-02-01"
order by transaction_date;


/*
Show all completed transactions with customer details. Display customer name, account type, 
transaction type, amount, and transaction date. Order by amount descending."
*/

select t.transaction_id, concat(c.first_name, " ",c.last_name) as full_name, c.account_type,t.transaction_type,t.transaction_date,t.amount,t.merchant_name
from customers c
inner join transactions t 
on c.customer_id = t.customer_id
where t.status-"Completed"
order by t.amount desc
limit 10;

/*
List ALL customers and count how many transactions each has made. Include customers with zero transactions. 
Show customer name, account type, account balance, and transaction count. Order by transaction count descending
*/

select c.customer_id, concat(c.first_name, " ",c.last_name) as full_name,c.account_type,count(t.transaction_id) as transaction_count,
case 
when count(t.transaction_id) = 0 then "Inactive"
when count(t.transaction_id) = 1 then "Low Activity"
when count(t.transaction_id) = 2 then "Medium Acitivity"
else "Highly Active"
end as activity_status
from customers c
left join transactions t
on c.customer_id = t.customer_id and t.status="Completed"
group by c.customer_id,c.account_type
order by transaction_count desc , c.account_balance desc;


/*
Using a CTE, find customers whose average transaction amount is above ₹50,000. 
Show customer name, account type, number of transactions, average transaction amount, and total spent
*/

WITH customer_transaction_stats AS (
select c.customer_id, c.account_type, count(t.transaction_id) as transaction_count, c.account_balance, avg(t.amount) as avg_transaction, sum(t.amount) as total_spent
from customers c
inner join transactions t 
on c.customer_id = t.customer_id
where status="Completed"
group by c.customer_id, c.account_type
)
select account_type, account_balance,transaction_count,avg_transaction, total_spent
from customer_transaction_stats
where avg_transaction > 50000
order by avg_transaction desc;


/*
Create a query using TWO CTEs: First CTE calculates the overall average transaction amount. 
Second CTE calculates each customer's average. Then show only customers whose average exceeds the overall average.
*/
WITH overall_average AS (
    -- CTE 1: Calculate overall average across all transactions
    SELECT 
        AVG(amount) AS overall_avg_amount
    FROM transactions
    WHERE status = 'Completed'
),
customer_averages AS (
    -- CTE 2: Calculate average per customer
    SELECT 
        c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        c.account_type,
        COUNT(t.transaction_id) AS transaction_count,
        AVG(t.amount) AS customer_avg_amount,
        SUM(t.amount) AS total_spent
    FROM customers c
    INNER JOIN transactions t ON c.customer_id = t.customer_id
    WHERE t.status = 'Completed'
    GROUP BY c.customer_id, c.first_name, c.last_name, c.account_type
)
-- Main query: Compare customer averages to overall average
SELECT 
    ca.customer_name,
    ca.account_type,
    ca.transaction_count,
    ROUND(ca.customer_avg_amount, 2) AS customer_avg,
    ROUND(oa.overall_avg_amount, 2) AS bank_avg,
    ROUND(ca.customer_avg_amount - oa.overall_avg_amount, 2) AS above_avg_by,
    ROUND(((ca.customer_avg_amount - oa.overall_avg_amount) / oa.overall_avg_amount) * 100, 2) AS pct_above_avg,
    ROUND(ca.total_spent, 2) AS total_spent
FROM customer_averages ca
CROSS JOIN overall_average oa
WHERE ca.customer_avg_amount > oa.overall_avg_amount
ORDER BY ca.customer_avg_amount DESC;


/*
Rank customers by account balance within each account type. Show only the top 3 customers from each account type.
*/

WITH ranked_customers AS (
    SELECT 
        customer_id,
        CONCAT(first_name, ' ', last_name) AS customer_name,
        email,
        account_type,
        account_balance,
        credit_score,
        date_opened,
        ROW_NUMBER() OVER (
            PARTITION BY account_type 
            ORDER BY account_balance DESC
        ) AS balance_rank
    FROM customers
)
SELECT 
    customer_name,
    email,
    account_type,
    ROUND(account_balance, 2) AS account_balance,
    credit_score,
    date_opened,
    balance_rank
FROM ranked_customers
WHERE balance_rank <= 3
ORDER BY account_type, balance_rank;




/*
Rank all customers by their credit score using RANK(), DENSE_RANK(), and ROW_NUMBER(). Show how these three functions handle ties differently. Display top 10 only.
*/

SELECT 
    customer_id,
    CONCAT(first_name, ' ', last_name) AS customer_name,
    account_type,
    ROUND(account_balance, 2) AS account_balance,
    credit_score,
    RANK() OVER (ORDER BY credit_score DESC) AS rank_with_gaps,
    DENSE_RANK() OVER (ORDER BY credit_score DESC) AS dense_rank_no_gaps,
    ROW_NUMBER() OVER (ORDER BY credit_score DESC, customer_id) AS row_number_unique
FROM customers
ORDER BY credit_score DESC, customer_id
LIMIT 10;


/*
Create a report showing each customer's transaction behavior: total transactions, total amount, average amount per transaction, 
and rank customers by total amount within their account type. Show top 5 overall.
*/



WITH customer_transaction_summary AS (
    -- Step 1: Aggregate transactions per customer
    SELECT 
        c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        c.account_type,
        c.account_balance,
        c.credit_score,
        COUNT(t.transaction_id) AS transaction_count,
        SUM(t.amount) AS total_spent,
        AVG(t.amount) AS avg_transaction,
        MIN(t.amount) AS min_transaction,
        MAX(t.amount) AS max_transaction
    FROM customers c
    INNER JOIN transactions t ON c.customer_id = t.customer_id
    WHERE t.status = 'Completed'
    GROUP BY c.customer_id, c.first_name, c.last_name, c.account_type, c.account_balance, c.credit_score
),
ranked_customers AS (
    -- Step 2: Add rankings
    SELECT 
        customer_id,
        customer_name,
        account_type,
        account_balance,
        credit_score,
        transaction_count,
        total_spent,
        avg_transaction,
        min_transaction,
        max_transaction,
        RANK() OVER (PARTITION BY account_type ORDER BY total_spent DESC) AS rank_in_type,
        RANK() OVER (ORDER BY total_spent DESC) AS overall_rank,
        ROUND((total_spent / SUM(total_spent) OVER ()) * 100, 2) AS pct_of_bank_total
    FROM customer_transaction_summary
)
-- Step 3: Final output
SELECT 
    customer_name,
    account_type,
    ROUND(account_balance, 2) AS account_balance,
    credit_score,
    transaction_count,
    ROUND(total_spent, 2) AS total_spent,
    ROUND(avg_transaction, 2) AS avg_transaction,
    ROUND(min_transaction, 2) AS min_transaction,
    ROUND(max_transaction, 2) AS max_transaction,
    rank_in_type,
    overall_rank,
    pct_of_bank_total
FROM ranked_customers
ORDER BY overall_rank
LIMIT 5;


/*
Find all customers who have made transactions but have NEVER made a 'Payment' transaction. Show customer details and their transaction types.
*/

WITH customers_with_payments AS (
    -- CTE 1: Find customers who HAVE made payments
    SELECT DISTINCT customer_id
    FROM transactions
    WHERE transaction_type = 'Payment' 
      AND status = 'Completed'
),
customers_with_transactions AS (
    -- CTE 2: Find all customers who have ANY transaction
    SELECT DISTINCT c.customer_id
    FROM customers c
    INNER JOIN transactions t ON c.customer_id = t.customer_id
    WHERE t.status = 'Completed'
),
customers_without_payments AS (
    -- CTE 3: Find customers with transactions but NO payments
    SELECT cwt.customer_id
    FROM customers_with_transactions cwt
    WHERE cwt.customer_id NOT IN (SELECT customer_id FROM customers_with_payments)
)
-- Main query: Show details of these customers
SELECT 
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    c.account_type,
    ROUND(c.account_balance, 2) AS account_balance,
    COUNT(t.transaction_id) AS transaction_count,
    GROUP_CONCAT(DISTINCT t.transaction_type ORDER BY t.transaction_type SEPARATOR ', ') AS transaction_types_used,
    ROUND(SUM(t.amount), 2) AS total_amount
FROM customers c
INNER JOIN customers_without_payments cwp ON c.customer_id = cwp.customer_id
INNER JOIN transactions t ON c.customer_id = t.customer_id
WHERE t.status = 'Completed'
GROUP BY c.customer_id, c.first_name, c.last_name, c.account_type, c.account_balance
ORDER BY total_amount DESC;



/*
For each transaction, calculate what percentage it represents of: (1) the customer's total spending, (2) the account type's total spending, and (3) the bank's total spending."
*/

SELECT 
    t.transaction_id,
    t.transaction_date,
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    c.account_type,
    t.transaction_type,
    ROUND(t.amount, 2) AS amount,
    -- Customer total
    ROUND(SUM(t.amount) OVER (PARTITION BY c.customer_id), 2) AS customer_total,
    ROUND((t.amount / SUM(t.amount) OVER (PARTITION BY c.customer_id)) * 100, 2) AS pct_of_customer,
    -- Account type total
    ROUND(SUM(t.amount) OVER (PARTITION BY c.account_type), 2) AS account_type_total,
    ROUND((t.amount / SUM(t.amount) OVER (PARTITION BY c.account_type)) * 100, 2) AS pct_of_account_type,
    -- Bank total
    ROUND(SUM(t.amount) OVER (), 2) AS bank_total,
    ROUND((t.amount / SUM(t.amount) OVER ()) * 100, 2) AS pct_of_bank
FROM transactions t
INNER JOIN customers c ON t.customer_id = c.customer_id
WHERE t.status = 'Completed'
ORDER BY t.amount DESC
LIMIT 10;




