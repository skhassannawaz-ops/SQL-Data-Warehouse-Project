/*
===============================================================================
Quality Checks: Gold Layer
===============================================================================
Script Purpose:
    Validates the integrity, consistency, and business rules of the Gold
    layer views. Run after each refresh — every query below should return
    NO ROWS. Any result indicates a data quality issue to investigate.
===============================================================================
*/

-- ============================================================================
-- Checking 'gold.dim_customers'
-- ============================================================================

-- Check for Uniqueness of Customer Key in gold.dim_customers
-- Expectation: No results
SELECT 
    customer_key,
    COUNT(*) AS duplicate_count
FROM gold.dim_customers
GROUP BY customer_key
HAVING COUNT(*) > 1;

-- Check for Uniqueness/NULLs on the natural key (customer_id)
-- Surrogate key uniqueness alone doesn't guarantee the business key is clean —
-- a duplicate here means the same real-world customer produced two dimension rows.
-- Expectation: No results
SELECT 
    customer_id,
    COUNT(*) AS duplicate_count
FROM gold.dim_customers
WHERE customer_id IS NULL
GROUP BY customer_id
HAVING COUNT(*) > 1 OR customer_id IS NULL;

-- Check standardization of gender and marital_status
-- Catches any stray/unmapped value that slipped through from source systems.
-- Expectation: Only ('Male','Female','n/a') for gender, ('Married','Single','n/a') for marital_status
SELECT DISTINCT gender FROM gold.dim_customers
WHERE gender NOT IN ('Male', 'Female', 'n/a');

SELECT DISTINCT marital_status FROM gold.dim_customers
WHERE marital_status NOT IN ('Married', 'Single', 'n/a');

-- Check for unwanted leading/trailing spaces in text fields
-- Expectation: No results
SELECT customer_number FROM gold.dim_customers
WHERE customer_number != TRIM(customer_number);

SELECT first_name FROM gold.dim_customers
WHERE first_name != TRIM(first_name);

SELECT last_name FROM gold.dim_customers
WHERE last_name != TRIM(last_name);

-- Check for implausible birth dates
-- Expectation: No results
SELECT customer_id, birth_date
FROM gold.dim_customers
WHERE birth_date > GETDATE() OR birth_date < '1924-01-01';

-- ============================================================================
-- Checking 'gold.dim_products'
-- ============================================================================

-- Check for Uniqueness of Product Key in gold.dim_products
-- Expectation: No results
SELECT 
    product_key,
    COUNT(*) AS duplicate_count
FROM gold.dim_products
GROUP BY product_key
HAVING COUNT(*) > 1;

-- Check for Uniqueness of the natural key (product_number)
-- product_key is a ROW_NUMBER(), so it is always unique by construction —
-- this check actually tests whether the underlying business key is clean.
-- Expectation: No results
SELECT 
    product_number,
    COUNT(*) AS duplicate_count
FROM gold.dim_products
GROUP BY product_number
HAVING COUNT(*) > 1;

-- Check for negative cost
-- Expectation: No results
SELECT product_number, cost
FROM gold.dim_products
WHERE cost < 0;

-- Check standardization of maintenance flag
-- Expectation: Only ('Yes','No')
SELECT DISTINCT maintenance FROM gold.dim_products
WHERE maintenance NOT IN ('Yes', 'No');

-- ============================================================================
-- Checking 'gold.fact_sales'
-- ============================================================================

-- Check Referential Integrity between gold.fact_sales and Dimensions
-- Expectation: No results (Foreign Keys should exist in Dimension tables)
SELECT *
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c ON f.customer_key = c.customer_key
LEFT JOIN gold.dim_products p ON f.product_key = p.product_key
WHERE c.customer_key IS NULL OR p.product_key IS NULL;

-- Check business rule: sales_amount = quantity * price
-- Validates the calculation documented in the data catalog rather than assuming
-- the source system always computed it correctly.
-- Expectation: No results
SELECT 
    order_number,
    quantity,
    price,
    sales_amount
FROM gold.fact_sales
WHERE sales_amount != quantity * price;

-- Check for non-positive quantity, price, or sales_amount
-- Expectation: No results
SELECT *
FROM gold.fact_sales
WHERE quantity <= 0 OR price <= 0 OR sales_amount <= 0;

-- Check date logic: order_date should never be later than shipping_date or due_date
-- Expectation: No results
SELECT 
    order_number,
    order_date,
    shipping_date,
    due_date
FROM gold.fact_sales
WHERE order_date > shipping_date OR order_date > due_date;

-- Check for future-dated orders
-- Expectation: No results
SELECT order_number, order_date
FROM gold.fact_sales
WHERE order_date > GETDATE();
