/*
===============================================================================
Measures, Magnitude, Ranking, and Time Analysis
===============================================================================

Purpose:
    This script performs exploratory data analysis on the DataWarehouseAnalytics database.
    Key objectives include:
        1. Calculating aggregated metrics for quick insights
        2. Understanding data distribution across dimensions
        3. Ranking products and customers based on performance
        4. Tracking trends and changes over time

Warnings:
    - This script only reads and aggregates data; it does not modify or delete tables.
    - Ensure you are connected to the correct database before running.

Tables Used:
    - gold.dim_customers
    - gold.dim_products
    - gold.fact_sales
===============================================================================
*/


-- ============================================================
-- 01: Measures Exploration (Key Metrics)
-- ============================================================
/*
Purpose:
    - Aggregate key metrics to get a high-level overview of the business
    - Identify trends, totals, averages, and anomalies
SQL Functions Used:
    - COUNT(), SUM(), AVG()
*/

-- Total sales in the fact_sales table
SELECT SUM(sales_amount) AS total_sales FROM gold.fact_sales;

-- Total number of items sold
SELECT SUM(quantity) AS total_quantity FROM gold.fact_sales;

-- Average selling price
SELECT AVG(price) AS avg_price FROM gold.fact_sales;

-- Total number of orders (all vs distinct)
SELECT COUNT(order_number) AS total_orders FROM gold.fact_sales;
SELECT COUNT(DISTINCT order_number) AS total_orders FROM gold.fact_sales;

-- Total number of products
SELECT COUNT(product_name) AS total_products FROM gold.dim_products;

-- Total number of customers
SELECT COUNT(customer_key) AS total_customers FROM gold.dim_customers;

-- Number of customers who have placed at least one order
SELECT COUNT(DISTINCT customer_key) AS total_customers FROM gold.fact_sales;

-- Combined report showing all key metrics in one table
SELECT 'Total Sales' AS measure_name, SUM(sales_amount) AS measure_value FROM gold.fact_sales
UNION ALL
SELECT 'Total Quantity', SUM(quantity) FROM gold.fact_sales
UNION ALL
SELECT 'Average Price', AVG(price) FROM gold.fact_sales
UNION ALL
SELECT 'Total Orders', COUNT(DISTINCT order_number) FROM gold.fact_sales
UNION ALL
SELECT 'Total Products', COUNT(DISTINCT product_name) FROM gold.dim_products
UNION ALL
SELECT 'Total Customers', COUNT(customer_key) FROM gold.dim_customers;




-- ============================================================
-- 02: Magnitude Analysis
-- ============================================================
/*
Purpose:
    - Quantify data and group results by dimensions
    - Understand data distribution across countries, genders, and categories
SQL Functions Used:
    - Aggregate: SUM(), COUNT(), AVG()
    - GROUP BY, ORDER BY
*/

-- Total customers per country
SELECT
    country,
    COUNT(customer_key) AS total_customers
FROM gold.dim_customers
GROUP BY country
ORDER BY total_customers DESC;

-- Total customers by gender
SELECT
    gender,
    COUNT(customer_key) AS total_customers
FROM gold.dim_customers
GROUP BY gender
ORDER BY total_customers DESC;

-- Total products per category
SELECT
    category,
    COUNT(product_key) AS total_products
FROM gold.dim_products
GROUP BY category
ORDER BY total_products DESC;

-- Average cost per product category
SELECT
    category,
    AVG(cost) AS avg_cost
FROM gold.dim_products
GROUP BY category
ORDER BY avg_cost DESC;

-- Total revenue per product category
SELECT
    p.category,
    SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p ON p.product_key = f.product_key
GROUP BY p.category
ORDER BY total_revenue DESC;

-- Total revenue per customer
SELECT
    c.customer_key,
    c.first_name,
    c.last_name,
    SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c ON c.customer_key = f.customer_key
GROUP BY c.customer_key, c.first_name, c.last_name
ORDER BY total_revenue DESC;

-- Distribution of sold items across countries
SELECT
    c.country,
    SUM(f.quantity) AS total_sold_items
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c ON c.customer_key = f.customer_key
GROUP BY c.country
ORDER BY total_sold_items DESC;




-- ============================================================
-- 03: Ranking Analysis
-- ============================================================
/*
Purpose:
    - Rank products and customers based on sales performance
    - Identify top and bottom performers
SQL Functions Used:
    - RANK(), ROW_NUMBER(), DENSE_RANK(), TOP
    - GROUP BY, ORDER BY
*/

-- Top 5 products generating the highest revenue
SELECT TOP 5
    p.product_name,
    SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p ON p.product_key = f.product_key
GROUP BY p.product_name
ORDER BY total_revenue DESC;

-- Flexible ranking using window functions
SELECT *
FROM (
    SELECT
        p.product_name,
        SUM(f.sales_amount) AS total_revenue,
        RANK() OVER (ORDER BY SUM(f.sales_amount) DESC) AS rank_products
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p ON p.product_key = f.product_key
    GROUP BY p.product_name
) AS ranked_products
WHERE rank_products <= 5;

-- Bottom 5 products by sales revenue
SELECT TOP 5
    p.product_name,
    SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p ON p.product_key = f.product_key
GROUP BY p.product_name
ORDER BY total_revenue;

-- Top 10 customers generating the highest revenue
SELECT TOP 10
    c.customer_key,
    c.first_name,
    c.last_name,
    SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c ON c.customer_key = f.customer_key
GROUP BY c.customer_key, c.first_name, c.last_name
ORDER BY total_revenue DESC;

-- 3 customers with the fewest orders
SELECT TOP 3
    c.customer_key,
    c.first_name,
    c.last_name,
    COUNT(DISTINCT order_number) AS total_orders
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c ON c.customer_key = f.customer_key
GROUP BY c.customer_key, c.first_name, c.last_name
ORDER BY total_orders;




-- ============================================================
-- 04: Change Over Time Analysis
-- ============================================================
/*
Purpose:
    - Track trends, growth, and changes in key metrics over time
    - Support time-series analysis and seasonal trend identification
SQL Functions Used:
    - DATEPART(), DATETRUNC(), FORMAT()
    - Aggregate: SUM(), COUNT()
*/

-- Sales performance by year and month
SELECT
    YEAR(order_date) AS order_year,
    MONTH(order_date) AS order_month,
    SUM(sales_amount) AS total_sales,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date), MONTH(order_date)
ORDER BY YEAR(order_date), MONTH(order_date);

-- Sales performance using DATETRUNC (month-level aggregation)
SELECT
    DATETRUNC(month, order_date) AS order_date,
    SUM(sales_amount) AS total_sales,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(month, order_date)
ORDER BY DATETRUNC(month, order_date);

-- Sales performance using FORMAT for readable labels
SELECT
    FORMAT(order_date, 'yyyy-MMM') AS order_date,
    SUM(sales_amount) AS total_sales,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY FORMAT(order_date, 'yyyy-MMM')
ORDER BY FORMAT(order_date, 'yyyy-MMM');
