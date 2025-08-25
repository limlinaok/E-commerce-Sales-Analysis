CREATE TABLE sales_transactions (
TransactionNo VARCHAR (50), Date DATE, ProductNo VARCHAR(50), ProductName VARCHAR (100), Price DECIMAL (10,2), 
Quantity VARCHAR(20) , CustomerNo VARCHAR (20), Country VARCHAR (50)
);
--To understand overall dataset--
SELECT*FROM sales_transactions LIMIT 10;

--Clean, convert the data type, save the table--
CREATE TABLE clean_transactions AS
SELECT date, productname AS product_name, price, country,
    COALESCE(CAST(NULLIF(REGEXP_REPLACE(transactionno, '[^0-9]', '', 'g'), '') AS INT), 0) AS transaction_no,
    COALESCE(CAST(NULLIF(REGEXP_REPLACE(productno, '[^0-9]', '', 'g'), '') AS INT), 0) AS product_no,
    COALESCE(CAST(NULLIF(REGEXP_REPLACE(quantity, '[^0-9]', '', 'g'), '') AS INT), 0) AS clean_quantity,
    COALESCE(CAST(NULLIF(REGEXP_REPLACE(customerno, '[^0-9]', '', 'g'), '') AS INT), 0) AS customer_no
FROM sales_transactions;
--Check the new table--
SELECT*FROM clean_transactions LIMIT 10;

--How was the sales trend over the months?
SELECT 
TO_CHAR(date,'Month') AS monthly_sales,
SUM(price*clean_quantity) AS total_revenue
FROM clean_transactions
GROUP BY monthly_sales;

--What are the most frequently purchased products? 
SELECT SUM(clean_quantity) AS total_purchases, product_name
FROM clean_transactions
GROUP BY product_name
ORDER BY total_purchases DESC;

--How many products does the customer purchase in each transaction?
SELECT customer_no, product_name, COUNT(transaction_no) AS purchase_times
FROM clean_transactions
GROUP BY customer_no, product_name
ORDER BY purchase_times DESC;

--What are the most profitable segment customers? (10 customers)
SELECT customer_no, country, SUM(price*clean_quantity) AS total_spent
FROM clean_transactions
GROUP BY customer_no, country
ORDER BY total_spent DESC
LIMIT 10;

--Loyalty classification (platinum, gold,silver, not yet) 
SELECT customer_no, COUNT(transaction_no) AS purchase_times,
CASE WHEN COUNT(transaction_no) >= 50 THEN 'platinum'
WHEN COUNT(transaction_no) >= 25 AND COUNT(transaction_no) < 49 THEN 'gold'
WHEN COUNT(transaction_no) < 24 AND COUNT(transaction_no) >= 10 THEN 'silver'
ELSE 'not yet' END AS loyalty_tier
FROM clean_transactions
GROUP BY customer_no
ORDER BY purchase_times DESC;

--Loyaly tier distribution
WITH tier_classify AS (
SELECT customer_no,COUNT(transaction_no) AS purchase_times,
CASE WHEN COUNT(transaction_no) >= 50 THEN 'platinum'
WHEN COUNT(transaction_no) >= 25 AND COUNT(transaction_no) < 49 THEN 'gold'
WHEN COUNT(transaction_no) < 24 AND COUNT(transaction_no) >= 10 THEN 'silver'
ELSE 'not yet' END AS loyalty_tier FROM clean_transactions GROUP BY customer_no)
SELECT loyalty_tier, ROUND(COUNT(DISTINCT customer_no) * 100.0 / (SELECT COUNT(DISTINCT customer_no) FROM tier_classify),1) 
AS pct_distribution
FROM tier_classify
GROUP BY loyalty_tier
ORDER BY pct_distribution DESC;

--Which country generates the highest sales with the highest sales volumn? Show top 3 
SELECT country, COUNT(*) AS no_of_sales, ROUND(SUM(price*clean_quantity),1) AS total_revenue
FROM clean_transactions
GROUP BY country
ORDER BY total_revenue DESC
LIMIT 3;

-- Average purchasing power in each country 
WITH avg_spending AS (
SELECT customer_no,country, SUM(clean_quantity) AS total_quantity, SUM(clean_quantity*price) AS total_spent 
FROM clean_transactions GROUP BY customer_no, country
)
SELECT country, SUM(total_quantity) AS total_quantity, ROUND(AVG(total_spent),1) AS avg_spending
FROM avg_spending
GROUP BY country
ORDER BY avg_spending DESC;

--How many unique transactions did each customer make?
SELECT COUNT(DISTINCT(transaction_no)) AS total_purchases, customer_no
FROM clean_transactions
GROUP BY customer_no
ORDER BY total_purchases DESC;

--RFM Segmentation (Recency, Frequency, Monetary) and churn flag
SELECT*FROM clean_transactions LIMIT 100;
WITH rfm_segmentation AS (
SELECT 
customer_no, (CURRENT_DATE - MAX(date)) AS recency_days, 
COUNT(transaction_no) AS no_of_transactions, SUM(price*clean_quantity) AS total_spent
FROM clean_transactions
GROUP BY customer_no)
SELECT customer_no, recency_days, total_spent, 
CASE WHEN recency_days > 100 THEN 'churned'
WHEN recency_days < 100 AND recency_days > 30 THEN 'at risk'
ELSE 'normal' END AS churn_status
FROM rfm_segmentation
ORDER BY total_spent DESC;

--Rolling 30 days sales
SELECT date,
SUM(clean_quantity*price) AS daily_sales,
SUM(SUM(price* clean_quantity)) OVER (ORDER BY date RANGE BETWEEN INTERVAL '30 days' PRECEDING AND CURRENT ROW) AS rolling_30d_sales
FROM clean_transactions
GROUP BY date
ORDER BY date;

--Market Basket analysis: find pairs of products that are most often bought together in the same transactions
SELECT a.product_name AS product_a,
b.product_name AS product_b,
COUNT(*) AS times_bought_together
FROM clean_transactions a
JOIN clean_transactions b
ON a.transaction_no = b.transaction_no AND a.product_name < b.product_name
GROUP BY a.product_name, b.product_name ORDER BY times_bought_together DESC 
LIMIT 10;

--For each country, calculate % contribution to global revenue.
WITH country_revenue AS (
SELECT country, SUM(price*clean_quantity) AS country_revenue FROM clean_transactions GROUP BY country
),
global_revenue_total AS (SELECT SUM(clean_quantity*price) AS global_revenue FROM clean_transactions)
SELECT cv.country, ROUND((cv.country_revenue / gr.global_revenue)*100,1) AS distribution_pct
FROM country_revenue cv
CROSS JOIN global_revenue_total gr
ORDER BY distribution_pct DESC;

--Assign customers to their first purchase month and calculate how many return in subsequent months.
WITH lagged AS (
    SELECT 
        customer_no, date,
        LAG(date) OVER (PARTITION BY customer_no ORDER BY date) AS prev_purchase_date
    FROM clean_transactions
)
SELECT 
    customer_no,
    MIN(date) AS first_purchase_date,
    COUNT(prev_purchase_date) AS repeated_times
FROM lagged
GROUP BY customer_no
ORDER BY repeated_times DESC;


