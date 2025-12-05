/*
=============================================================
Database and Schema Setup Script
=============================================================

Purpose:
    This script creates a new SQL Server database called 'DataWarehouseAnalytics'.
    If the database already exists, it will be dropped and recreated. 
    A schema named 'gold' is also created, along with dimension and fact tables for analytics.

Important Notes:
    ⚠️ Running this script will permanently delete all data in the existing 'DataWarehouseAnalytics' database.
    Ensure you have backups before executing.

Tables Created:
    - gold.dim_customers   : Customer dimension table
    - gold.dim_products    : Product dimension table
    - gold.fact_sales      : Sales fact table

Data Loading:
    The script uses BULK INSERT to populate tables from CSV files. 
    CSV files must match the schema of the tables and start from the second row.

=============================================================
*/

-- Switch context to the master database to perform database-level operations
USE master;
GO

-- Check if the 'DataWarehouseAnalytics' database exists, and if so, drop it
-- SET SINGLE_USER ensures no other connections are active before dropping
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'DataWarehouseAnalytics')
BEGIN
    ALTER DATABASE DataWarehouseAnalytics SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DataWarehouseAnalytics;
END;
GO

-- Create a fresh 'DataWarehouseAnalytics' database
CREATE DATABASE DataWarehouseAnalytics;
GO

-- Switch context to the newly created database
USE DataWarehouseAnalytics;
GO

-- Create the 'gold' schema for organizing analytic tables
CREATE SCHEMA gold;
GO

-- ============================================================
-- Create Dimension Tables
-- ============================================================

-- Customer dimension table storing personal and demographic information
CREATE TABLE gold.dim_customers(
    customer_key int,
    customer_id int,
    customer_number nvarchar(50),
    first_name nvarchar(50),
    last_name nvarchar(50),
    country nvarchar(50),
    marital_status nvarchar(50),
    gender nvarchar(50),
    birthdate date,
    create_date date
);
GO

-- Product dimension table storing product and category details
CREATE TABLE gold.dim_products(
    product_key int,
    product_id int,
    product_number nvarchar(50),
    product_name nvarchar(50),
    category_id nvarchar(50),
    category nvarchar(50),
    subcategory nvarchar(50),
    maintenance nvarchar(50),
    cost int,
    product_line nvarchar(50),
    start_date date
);
GO

-- Sales fact table storing transactional sales data
CREATE TABLE gold.fact_sales(
    order_number nvarchar(50),
    product_key int,
    customer_key int,
    order_date date,
    shipping_date date,
    due_date date,
    sales_amount int,
    quantity tinyint,
    price int
);
GO

-- ============================================================
-- Load Data from CSV Files
-- ============================================================

-- Remove any existing data in the customers table before loading
TRUNCATE TABLE gold.dim_customers;
GO

-- Load data into dim_customers from a CSV file
BULK INSERT gold.dim_customers
FROM 'E:\Courses\Portfolio\SQL\Data with Baraa resources\sql-data-analytics-project\datasets\csv-files\gold.dim_customers.csv'
WITH (
    FIRSTROW = 2,          -- Skip header row
    FIELDTERMINATOR = ',', -- CSV field delimiter
    TABLOCK               -- Optimize for bulk loading
);
GO

-- Remove any existing data in the products table before loading
TRUNCATE TABLE gold.dim_products;
GO

-- Load data into dim_products from a CSV file
BULK INSERT gold.dim_products
FROM 'E:\Courses\Portfolio\SQL\Data with Baraa resources\sql-data-analytics-project\datasets\csv-files\gold.dim_products.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    TABLOCK
);
GO

-- Remove any existing data in the sales fact table before loading
TRUNCATE TABLE gold.fact_sales;
GO

-- Load data into fact_sales from a CSV file
BULK INSERT gold.fact_sales
FROM 'E:\Courses\Portfolio\SQL\Data with Baraa resources\sql-data-analytics-project\datasets\csv-files\gold.fact_sales.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    TABLOCK
);
GO
