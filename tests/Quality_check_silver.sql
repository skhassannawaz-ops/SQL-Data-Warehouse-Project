/*
===============================================================================
Quality Checks
===============================================================================
Script Purpose:
    This script performs quality checks for data consistency, accuracy, 
    and standardization across the 'silver' schema. It includes checks for:
    - Null or duplicate primary keys.
    - Unwanted spaces in string fields.
    - Data standardization and consistency.
    - Invalid date ranges and orders.
    - Data consistency between related fields.

Usage Notes:
    - Run these checks after loading the Silver Layer.
    - Investigate and resolve any discrepancies found during the checks.
===============================================================================
*/

-- ====================================================================
-- Checking 'silver.crm_cust_info'
-- ====================================================================
-- Check for NULLs or Duplicates in Primary Key
-- Expectation: No Results
SELECT 
    cst_id,
    COUNT(*) 
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL;

-- Check for unwanted spaces in string fields
-- Expectation: No Results
SELECT cst_key 
FROM silver.crm_cust_info
WHERE cst_key != TRIM(cst_key);

SELECT cst_firstname 
FROM silver.crm_cust_info
WHERE cst_firstname != TRIM(cst_firstname);

SELECT cst_lastname 
FROM silver.crm_cust_info
WHERE cst_lastname != TRIM(cst_lastname);

-- Data standardization & consistency
-- Review the distinct values to check consistency of mapped labels
SELECT DISTINCT cst_marital_status 
FROM silver.crm_cust_info;

SELECT DISTINCT cst_gndr 
FROM silver.crm_cust_info;

-- Check for NULLs in create date (used for dedup ordering)
SELECT * 
FROM silver.crm_cust_info
WHERE cst_create_date IS NULL;


-- ====================================================================
-- Checking 'silver.crm_prd_info'
-- ====================================================================
-- Check for NULLs or Duplicates in Primary Key
-- Expectation: No Results
SELECT 
    prd_id,
    COUNT(*) 
FROM silver.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 OR prd_id IS NULL;

-- Check for unwanted spaces
-- Expectation: No Results
SELECT prd_name 
FROM silver.crm_prd_info
WHERE prd_name != TRIM(prd_name);

-- Check for NULLs or Negative Values in Cost
-- Expectation: No Results
SELECT prd_cost 
FROM silver.crm_prd_info
WHERE prd_cost < 0 OR prd_cost IS NULL;

-- Data standardization & consistency
SELECT DISTINCT prd_line 
FROM silver.crm_prd_info;

-- Check for Invalid Date Orders (Start Date > End Date)
-- Expectation: No Results
SELECT * 
FROM silver.crm_prd_info
WHERE prd_end_date < prd_start_date;

-- Check for NULLs in start date
SELECT * 
FROM silver.crm_prd_info
WHERE prd_start_date IS NULL;

-- Check that cat_id exists in the ERP category table (referential check)
-- Expectation: No Results
SELECT prd_key, cat_id 
FROM silver.crm_prd_info
WHERE cat_id NOT IN (SELECT id FROM silver.erp_px_cat_g1v2);

-- Check that prd_key exists in sales info (referential check)
-- Expectation: No Results
SELECT prd_key 
FROM silver.crm_prd_info
WHERE prd_key NOT IN (SELECT sls_prd_key FROM silver.crm_sales_info);


-- ====================================================================
-- Checking 'silver.crm_sales_info'
-- ====================================================================
-- Check for unwanted spaces
-- Expectation: No Results
SELECT sls_ord_num 
FROM silver.crm_sales_info
WHERE sls_ord_num != TRIM(sls_ord_num);

-- Check that prd_key / cst_id exist in the related dimension tables
-- Expectation: No Results
SELECT * 
FROM silver.crm_sales_info
WHERE sls_prd_key NOT IN (SELECT prd_key FROM silver.crm_prd_info);

SELECT * 
FROM silver.crm_sales_info
WHERE sls_cst_id NOT IN (SELECT cst_id FROM silver.crm_cust_info);

-- Check for Invalid Dates (out-of-range or zero-length values)
-- Expectation: No Invalid Dates
SELECT 
    NULLIF(sls_order_dt, 0) AS sls_order_dt
FROM bronze.crm_sales_info
WHERE sls_order_dt <= 0 
   OR LEN(sls_order_dt) != 8 
   OR sls_order_dt > 20500101 
   OR sls_order_dt < 19000101;

-- Check for Invalid Date Orders (Order Date > Shipping/Due Date)
-- Expectation: No Results
SELECT * 
FROM silver.crm_sales_info
WHERE sls_order_dt > sls_ship_dt 
   OR sls_order_dt > sls_due_dt;

-- Check Data Consistency: Sales = Quantity * Price
-- Sales must equal Quantity * Price, and none may be negative, zero, or NULL
-- Expectation: No Results
SELECT DISTINCT 
    sls_sales,
    sls_quantity,
    sls_price 
FROM silver.crm_sales_info
WHERE sls_sales != sls_quantity * sls_price
   OR sls_sales IS NULL 
   OR sls_quantity IS NULL 
   OR sls_price IS NULL
   OR sls_sales <= 0 
   OR sls_quantity <= 0 
   OR sls_price <= 0
ORDER BY sls_sales, sls_quantity, sls_price;


-- ====================================================================
-- Checking 'silver.erp_cust_az12'
-- ====================================================================
-- Check for Out-of-Range Dates of Birth
-- Expectation: Birthdates between 1926-01-01 and Today
SELECT DISTINCT 
    bdate 
FROM silver.erp_cust_az12
WHERE bdate < '1926-01-01' 
   OR bdate > GETDATE();

-- Data standardization & consistency
SELECT DISTINCT gen 
FROM silver.erp_cust_az12;

-- Check that cid (after prefix strip) matches customer key in crm_cust_info
-- Expectation: No Results
SELECT * 
FROM silver.erp_cust_az12
WHERE cid NOT IN (SELECT cst_key FROM silver.crm_cust_info);


-- ====================================================================
-- Checking 'silver.erp_loc_a101'
-- ====================================================================
-- Check that cid matches customer key in crm_cust_info
-- Expectation: No Results
SELECT * 
FROM silver.erp_loc_a101
WHERE cid NOT IN (SELECT cst_key FROM silver.crm_cust_info);

-- Data standardization & consistency
SELECT DISTINCT cntry 
FROM silver.erp_loc_a101
ORDER BY cntry;


-- ====================================================================
-- Checking 'silver.erp_px_cat_g1v2'
-- ====================================================================
-- Check for unwanted spaces
-- Expectation: No Results
SELECT * 
FROM silver.erp_px_cat_g1v2
WHERE cat != TRIM(cat) 
   OR subcat != TRIM(subcat) 
   OR maintenance != TRIM(maintenance);

-- Data standardization & consistency
SELECT DISTINCT cat 
FROM silver.erp_px_cat_g1v2;

SELECT DISTINCT subcat 
FROM silver.erp_px_cat_g1v2;

SELECT DISTINCT maintenance 
FROM silver.erp_px_cat_g1v2;

-- Check for NULLs or empty strings in key columns
-- Expectation: No Results
SELECT * 
FROM silver.erp_px_cat_g1v2
WHERE id IS NULL 
   OR cat IS NULL OR cat = ''
   OR subcat IS NULL OR subcat = ''
   OR maintenance IS NULL OR maintenance = '';
