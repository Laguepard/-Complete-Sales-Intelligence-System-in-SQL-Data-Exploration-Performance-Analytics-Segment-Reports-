/*
===============================================================================
Part-to-Whole Analysis, Customer & Product Reports
===============================================================================

Purpose:
    - Compare performance across dimensions (e.g., categories, products, customers).
    - Evaluate contributions of categories, products, and customers to overall sales.
    - Create reusable customer and product reports with detailed KPIs.

Warnings:
    - These scripts only read and aggregate data; no tables are modified except for creating views.
    - Ensure the database context is set to DataWarehouseAnalytics before running.

Tables Used:
    - gold.fact_sales
    - gold.dim_customers
    - gold.dim_products

SQL Functions Used:
    - Aggregate Functions: SUM(), AVG(), COUNT(), DATEDIFF()
    - Window Functions: SUM() OVER()
    - Conditional Logic: CASE
===============================================================================
*/

-- ============================================================
-- 01: Part-to-Whole Analysis (Category Contribution to Sales)
-- ============================================================
/*
Purpose:
    - Calculate the contribution of each product category to total sales.
    - Useful for identifying key revenue drivers and prioritizing business focus.
SQL Functions:
    - SUM() for total sales per category
    - SUM() OVER() for overall sales
    - CAST and ROUND for percentage calculations
*/
WITH category_sales AS (
    SELECT
        p.category,
        SUM(f.sales_amount) AS total_sales
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p
        ON p.product_key = f.product_key
    GROUP BY p.category
)
SELECT
    category,
    total_sales,
    SUM(total_sales) OVER () AS overall_sales,  -- Total sales across all categories
    ROUND((CAST(total_sales AS FLOAT) / SUM(total_sales) OVER ()) * 100, 2) AS percentage_of_total
FROM category_sales
ORDER BY total_sales DESC;



-- ============================================================
-- 02: Customer Report (gold.report_customers)
-- ============================================================
/*
Purpose:
    - Consolidate key customer metrics and behaviors
    - Segment customers by age and spending behavior
    - Aggregate KPIs for strategic analysis
Steps:
    1. Base Query: Extract raw customer transaction data
    2. Customer Aggregation: Summarize orders, sales, quantity, products, lifespan
    3. Final Output: Add segments, recency, average order value, and average monthly spend
Warnings:
    - Drops existing view if it exists
*/
IF OBJECT_ID('gold.report_customers', 'V') IS NOT NULL
    DROP VIEW gold.report_customers;
GO

CREATE VIEW gold.report_customers AS

WITH base_query AS (
    -- 1) Extract core customer transaction data
    SELECT
        f.order_number,
        f.product_key,
        f.order_date,
        f.sales_amount,
        f.quantity,
        c.customer_key,
        c.customer_number,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        DATEDIFF(year, c.birthdate, GETDATE()) AS age
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_customers c
        ON f.customer_key = c.customer_key
    WHERE f.order_date IS NOT NULL
),

customer_aggregation AS (
    -- 2) Aggregate metrics per customer
    SELECT 
        customer_key,
        customer_number,
        customer_name,
        age,
        COUNT(DISTINCT order_number) AS total_orders,
        SUM(sales_amount) AS total_sales,
        SUM(quantity) AS total_quantity,
        COUNT(DISTINCT product_key) AS total_products,
        MAX(order_date) AS last_order_date,
        DATEDIFF(month, MIN(order_date), MAX(order_date)) AS lifespan
    FROM base_query
    GROUP BY customer_key, customer_number, customer_name, age
)

-- 3) Final report: segments, recency, averages
SELECT
    customer_key,
    customer_number,
    customer_name,
    age,
    CASE 
        WHEN age < 20 THEN 'Under 20'
        WHEN age BETWEEN 20 AND 29 THEN '20-29'
        WHEN age BETWEEN 30 AND 39 THEN '30-39'
        WHEN age BETWEEN 40 AND 49 THEN '40-49'
        ELSE '50 and above'
    END AS age_group,
    CASE 
        WHEN lifespan >= 12 AND total_sales > 5000 THEN 'VIP'
        WHEN lifespan >= 12 AND total_sales <= 5000 THEN 'Regular'
        ELSE 'New'
    END AS customer_segment,
    last_order_date,
    DATEDIFF(month, last_order_date, GETDATE()) AS recency,
    total_orders,
    total_sales,
    total_quantity,
    total_products,
    lifespan,
    -- Average Order Value
    CASE WHEN total_orders = 0 THEN 0 ELSE total_sales / total_orders END AS avg_order_value,
    -- Average Monthly Spend
    CASE WHEN lifespan = 0 THEN total_sales ELSE total_sales / lifespan END AS avg_monthly_spend
FROM customer_aggregation;



-- ============================================================
-- 03: Product Report (gold.report_products)
-- ============================================================
/*
Purpose:
    - Consolidate key product metrics and behaviors
    - Segment products by revenue to identify High, Mid, or Low performers
    - Aggregate product-level KPIs such as total sales, quantity, customers, lifespan
Steps:
    1. Base Query: Extract product transaction data
    2. Product Aggregations: Summarize metrics per product
    3. Final Output: Add recency, segments, averages
Warnings:
    - Drops existing view if it exists
*/
IF OBJECT_ID('gold.report_products', 'V') IS NOT NULL
    DROP VIEW gold.report_products;
GO

CREATE VIEW gold.report_products AS

WITH base_query AS (
    -- 1) Extract core product transaction data
    SELECT
        f.order_number,
        f.order_date,
        f.customer_key,
        f.sales_amount,
        f.quantity,
        p.product_key,
        p.product_name,
        p.category,
        p.subcategory,
        p.cost
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p
        ON f.product_key = p.product_key
    WHERE f.order_date IS NOT NULL
),

product_aggregations AS (
    -- 2) Aggregate metrics per product
    SELECT
        product_key,
        product_name,
        category,
        subcategory,
        cost,
        DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan,
        MAX(order_date) AS last_sale_date,
        COUNT(DISTINCT order_number) AS total_orders,
        COUNT(DISTINCT customer_key) AS total_customers,
        SUM(sales_amount) AS total_sales,
        SUM(quantity) AS total_quantity,
        ROUND(AVG(CAST(sales_amount AS FLOAT) / NULLIF(quantity, 0)), 1) AS avg_selling_price
    FROM base_query
    GROUP BY product_key, product_name, category, subcategory, cost
)

-- 3) Final report: segments, recency, averages
SELECT
    product_key,
    product_name,
    category,
    subcategory,
    cost,
    last_sale_date,
    DATEDIFF(MONTH, last_sale_date, GETDATE()) AS recency_in_months,
    CASE
        WHEN total_sales > 50000 THEN 'High-Performer'
        WHEN total_sales >= 10000 THEN 'Mid-Range'
        ELSE 'Low-Performer'
    END AS product_segment,
    lifespan,
    total_orders,
    total_sales,
    total_quantity,
    total_customers,
    avg_selling_price,
    -- Average Order Revenue
    CASE WHEN total_orders = 0 THEN 0 ELSE total_sales / total_orders END AS avg_order_revenue,
    -- Average Monthly Revenue
    CASE WHEN lifespan = 0 THEN total_sales ELSE total_sales / lifespan END AS avg_monthly_revenue
FROM product_aggregations;
