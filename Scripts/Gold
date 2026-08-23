/*
===============================================================================
DDL Script: Create Gold Views
===============================================================================
Script Purpose:
    This script creates views for the Gold layer in the data warehouse.
    The Gold layer represents the final dimension and fact tables (Star Schema).

    Each view performs transformations and combines data from the Silver layer
    to produce clean, enriched, and business-ready datasets.

Usage Notes:
    - These views can be queried directly by BI tools, analysts, or reporting applications.
===============================================================================
*/

-- ============================================================================
-- Create Dimension: gold.dim_customers
-- ============================================================================
IF OBJECT_ID('gold.dim_customers', 'V') IS NOT NULL
    DROP VIEW gold.dim_customers;
GO

CREATE VIEW gold.dim_customers AS
SELECT
    -- Surrogate key generated at query time rather than stored/identity-based.
    -- This means customer_key is NOT stable across refreshes if new customers
    -- are inserted upstream with a lower cst_id than existing rows — downstream
    -- consumers (e.g. fact_sales joins, BI bookmarks) should not persist this
    -- value outside the warehouse.
    ROW_NUMBER() OVER (ORDER BY cst_id) AS customer_key,
    ci.cst_id                          AS customer_id,
    ci.cst_key                         AS customer_number,
    ci.cst_firstname                   AS first_name,
    ci.cst_lastname                    AS last_name,
    la.cntry                           AS country,
    ci.cst_marital_status              AS marital_status,
    -- Gender has two competing sources (CRM and ERP) that can disagree or be
    -- incomplete. CRM is treated as the system of record for this attribute,
    -- so its value wins whenever it's populated; ERP only fills the gap when
    -- CRM explicitly has no answer ('n/a'), and if both are unknown we default
    -- to 'n/a' rather than leaving NULL so downstream aggregations don't drop rows.
    CASE 
        WHEN ci.cst_gndr != 'n/a' THEN ci.cst_gndr -- CRM is Primary Source
        ELSE COALESCE(ca.gen, 'n/a')
    END                                AS gender,
    ca.bdate                           AS birth_date,
    ci.cst_create_date                 AS create_date
FROM silver.crm_cust_info ci
-- Both lookups are LEFT JOINs by design: a customer must still appear in this
-- dimension even if their ERP demographic or location record hasn't landed
-- yet (e.g. late-arriving dimension), rather than being silently dropped.
LEFT JOIN silver.erp_cust_az12 ca
    ON ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 la
    ON ci.cst_key = la.cid;
GO

-- ============================================================================
-- Create Dimension: gold.dim_products
-- ============================================================================
IF OBJECT_ID('gold.dim_products', 'V') IS NOT NULL
    DROP VIEW gold.dim_products;
GO

CREATE VIEW gold.dim_products AS
SELECT
    -- Ordered by start date first, then product key, so that when a product
    -- is re-versioned (new prd_key for the same logical product) the surrogate
    -- keys stay grouped in the order products were introduced — keeps key
    -- assignment reproducible and roughly aligned with product history.
    ROW_NUMBER() OVER (ORDER BY pn.prd_start_dt, pn.prd_key) AS product_key,
    pn.prd_id                                                AS product_id,
    pn.prd_key                                               AS product_number,
    pn.prd_nm                                                AS product_name,
    pn.cat_id                                                AS category_id,
    pc.cat                                                   AS category,
    pc.subcat                                                AS subcategory,
    pc.maintenance                                           AS maintenance,
    pn.prd_cost                                              AS cost,
    pn.prd_line                                              AS product_line,
    pn.prd_start_dt                                          AS start_date
FROM silver.crm_prd_info pn
LEFT JOIN silver.erp_px_cat_g1v2 pc
    ON pn.cat_id = pc.id
-- silver.crm_prd_info holds full version history per product (type-2 style),
-- so without this filter the same logical product would appear multiple
-- times with different cost/line values. Keeping only the row with a NULL
-- end date isolates the current, active version.
WHERE pn.prd_end_dt IS NULL;
GO

-- ============================================================================
-- Create Fact Table: gold.fact_sales
-- ============================================================================
IF OBJECT_ID('gold.fact_sales', 'V') IS NOT NULL
    DROP VIEW gold.fact_sales;
GO

CREATE VIEW gold.fact_sales AS
SELECT
    sd.sls_ord_num  AS order_number,
    pr.product_key  AS product_key,
    cu.customer_key AS customer_key,
    sd.sls_order_dt AS order_date,
    sd.sls_ship_dt  AS shipping_date,
    sd.sls_due_dt   AS due_date,
    sd.sls_sales    AS sales_amount,
    sd.sls_quantity AS quantity,
    sd.sls_price    AS price
FROM silver.crm_sales_details sd
-- Joined on the natural/business key (product_number), not the surrogate
-- product_key, because the source sales detail rows only carry the original
-- CRM product key — the surrogate is resolved here by looking it up in the
-- already-built dim_products view.
LEFT JOIN gold.dim_products pr
    ON sd.sls_prd_key = pr.product_number
-- Same reasoning for customers: sales rows reference the source-system
-- customer id, so the surrogate customer_key is resolved via dim_customers.
-- LEFT JOINs here (rather than INNER) mean a sales row survives even if its
-- customer or product hasn't made it into the dimension yet — it will just
-- carry a NULL key until the dimension catches up on a later refresh.
LEFT JOIN gold.dim_customers cu
    ON sd.sls_cust_id = cu.customer_id;
GO
