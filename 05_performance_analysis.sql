
/*
===============================================================================
Cumulative Analysis (Running Totals & Moving Averages)
===============================================================================

Purpose:
    - Calculate running totals for key metrics to observe cumulative growth.
    - Compute moving averages to identify trends in pricing over time.
    - Support long-term performance analysis and growth tracking.

Warnings:
    - This script only reads and aggregates data; no tables are modified.
    - Ensure the database context is set to DataWarehouseAnalytics before running.

Tables Used:
    - gold.fact_sales

SQL Functions Used:
    - Window Functions: SUM() OVER(), AVG() OVER()
    - DATETRUNC(): To group data by year (or other time periods)
===============================================================================
*/


-- ============================================================
-- 01: Yearly Cumulative Sales and Moving Average Price
-- ============================================================
/*
Explanation:
    - Inner query aggregates yearly sales and average price for each year.
    - Outer query calculates:
        1) Running total of sales over the years (SUM() OVER ORDER BY)
        2) Moving average of price over the years (AVG() OVER ORDER BY)
    - This provides insight into cumulative performance and pricing trends.
*/

SELECT
    order_date,                              -- Year (truncated from order_date)
    total_sales,                             -- Total sales in that year
    SUM(total_sales) OVER (ORDER BY order_date) AS running_total_sales, -- Cumulative sales
    AVG(avg_price) OVER (ORDER BY order_date) AS moving_average_price   -- Moving average price
FROM
(
    SELECT 
        DATETRUNC(year, order_date) AS order_date,  -- Aggregate by year
        SUM(sales_amount) AS total_sales,          -- Total sales for the year
        AVG(price) AS avg_price                     -- Average product price for the year
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY DATETRUNC(year, order_date)
) t
ORDER BY order_date;  -- Ensure chronological order for cumulative calculations


/*
===============================================================================
Performance Analysis & Data Segmentation
===============================================================================

Purpose:
    - Evaluate product, customer, and regional performance over time.
    - Benchmark performance, identify trends, and highlight high-performing entities.
    - Group data into meaningful segments for targeted insights.

Warnings:
    - This script performs read-only analysis; no tables are modified.
    - Ensure you are connected to the correct database (DataWarehouseAnalytics) before executing.

Tables Used:
    - gold.fact_sales
    - gold.dim_products
    - gold.dim_customers
SQL Functions Highlighted:
    - LAG(), AVG() OVER(), CASE, DATEDIFF(), GROUP BY
===============================================================================
*/


-- ============================================================
-- 01: Performance Analysis (Year-over-Year & Month-over-Month)
-- ============================================================
/*
Purpose:
    - Measure yearly product performance by comparing sales to:
        a) Average sales of the product
        b) Previous year's sales
    - Identify products performing above or below average
    - Detect increases or decreases year-over-year

Key SQL Concepts:
    - CTE (WITH clause) to calculate yearly product sales
    - Window functions: LAG() and AVG() OVER() for trend analysis
    - CASE statements for conditional labeling
*/

WITH yearly_product_sales AS (
    SELECT
        YEAR(f.order_date) AS order_year,
        p.product_name,
        SUM(f.sales_amount) AS current_sales
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p
        ON f.product_key = p.product_key
    WHERE f.order_date IS NOT NULL
    GROUP BY YEAR(f.order_date), p.product_name
)
SELECT
    order_year,
    product_name,
    current_sales,
    -- Average sales of the product across all years
    AVG(current_sales) OVER (PARTITION BY product_name) AS avg_sales,
    current_sales - AVG(current_sales) OVER (PARTITION BY product_name) AS diff_avg,
    CASE 
        WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) > 0 THEN 'Above Avg'
        WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) < 0 THEN 'Below Avg'
        ELSE 'Avg'
    END AS avg_change,
    -- Previous year sales
    LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS py_sales,
    current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS diff_py,
    CASE 
        WHEN current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) > 0 THEN 'Increase'
        WHEN current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) < 0 THEN 'Decrease'
        ELSE 'No Change'
    END AS py_change
FROM yearly_product_sales
ORDER BY product_name, order_year;




-- ============================================================
-- 02: Data Segmentation Analysis
-- ============================================================
/*
Purpose:
    - Group products and customers into meaningful categories
    - Facilitate targeted insights for business decisions
    - Analyze distribution across segments

SQL Concepts:
    - CASE statements to define custom segments
    - GROUP BY to aggregate within segments
    - CTEs to simplify complex calculations
*/


-- 2a: Product Segmentation by Cost Range
WITH product_segments AS (
    SELECT
        product_key,
        product_name,
        cost,
        CASE 
            WHEN cost < 100 THEN 'Below 100'
            WHEN cost BETWEEN 100 AND 500 THEN '100-500'
            WHEN cost BETWEEN 500 AND 1000 THEN '500-1000'
            ELSE 'Above 1000'
        END AS cost_range
    FROM gold.dim_products
)
SELECT 
    cost_range,
    COUNT(product_key) AS total_products
FROM product_segments
GROUP BY cost_range
ORDER BY total_products DESC;


-- 2b: Customer Segmentation by Spending Behavior and Lifespan
WITH customer_spending AS (
    SELECT
        c.customer_key,
        SUM(f.sales_amount) AS total_spending,
        MIN(order_date) AS first_order,
        MAX(order_date) AS last_order,
        DATEDIFF(month, MIN(order_date), MAX(order_date)) AS lifespan
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_customers c
        ON f.customer_key = c.customer_key
    GROUP BY c.customer_key
)
SELECT 
    customer_segment,
    COUNT(customer_key) AS total_customers
FROM (
    SELECT 
        customer_key,
        CASE 
            WHEN lifespan >= 12 AND total_spending > 5000 THEN 'VIP'
            WHEN lifespan >= 12 AND total_spending <= 5000 THEN 'Regular'
            ELSE 'New'
        END AS customer_segment
    FROM customer_spending
) AS segmented_customers
GROUP BY customer_segment
ORDER BY total_customers DESC;
