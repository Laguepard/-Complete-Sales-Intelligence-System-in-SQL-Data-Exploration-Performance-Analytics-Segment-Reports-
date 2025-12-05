/*
===============================================================================
Database Exploration Script
===============================================================================

Purpose:
    This script is designed to explore and understand the structure, 
    content, and temporal characteristics of the DataWarehouseAnalytics database. 
    It includes steps to:
        1. List all tables and their schemas
        2. Inspect column metadata for specific tables
        3. Explore dimension tables and unique attribute values
        4. Examine date ranges and age distributions for analysis readiness

Warnings:
    - This script only reads metadata and table data; it does not modify or delete data.
    - Ensure you are connected to the correct database before running.

Tables Used:
    - INFORMATION_SCHEMA.TABLES       : For listing all tables
    - INFORMATION_SCHEMA.COLUMNS      : For inspecting column metadata
    - gold.dim_customers              : Customer dimension table
    - gold.dim_products               : Product dimension table
    - gold.fact_sales                 : Sales fact table

===============================================================================
*/

-- ============================================================
-- 01: Database Structure Exploration
-- ============================================================
-- Purpose: Retrieve a list of all tables and their types in the current database
-- Notes: Useful for confirming the existence of expected schemas and tables
SELECT 
    TABLE_CATALOG,    -- Database name
    TABLE_SCHEMA,     -- Schema name
    TABLE_NAME,       -- Table name
    TABLE_TYPE        -- Table type (BASE TABLE or VIEW)
FROM INFORMATION_SCHEMA.TABLES;

-- Inspect all columns and metadata for the 'dim_customers' table
-- Notes: Provides data types, nullability, and max character length
SELECT 
    COLUMN_NAME, 
    DATA_TYPE, 
    IS_NULLABLE, 
    CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'dim_customers';




-- ============================================================
-- 02: Dimensions Exploration
-- ============================================================
/*
Purpose:
    - Explore the content of dimension tables to understand distinct attribute values
    - Useful for validation, quality checks, and identifying unique categories for analysis
SQL Functions Used:
    - DISTINCT   : Removes duplicates
    - ORDER BY   : Sorts output for readability
*/

-- Retrieve all unique countries represented in the customer dimension table
SELECT DISTINCT 
    country 
FROM gold.dim_customers
ORDER BY country;

-- Retrieve all unique product categories, subcategories, and product names
SELECT DISTINCT 
    category, 
    subcategory, 
    product_name 
FROM gold.dim_products
ORDER BY category, subcategory, product_name;




-- ============================================================
-- 03: Date Range Exploration
-- ============================================================
/*
Purpose:
    - Determine the temporal boundaries of key transactional and demographic data
    - Identify the first and last order dates, overall order duration, and customer age range
SQL Functions Used:
    - MIN(), MAX() : Identify earliest and latest dates
    - DATEDIFF()   : Compute the time difference between dates
*/

-- Determine the first and last order date and the total duration in months
SELECT 
    MIN(order_date) AS first_order_date,           -- Earliest order
    MAX(order_date) AS last_order_date,            -- Most recent order
    DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS order_range_months -- Total duration
FROM gold.fact_sales;

-- Identify the youngest and oldest customers based on birthdate
SELECT
    MIN(birthdate) AS oldest_birthdate,           -- Earliest birthdate
    DATEDIFF(YEAR, MIN(birthdate), GETDATE()) AS oldest_age, -- Age of oldest customer
    MAX(birthdate) AS youngest_birthdate,         -- Latest birthdate
    DATEDIFF(YEAR, MAX(birthdate), GETDATE()) AS youngest_age -- Age of youngest customer
FROM gold.dim_customers;
