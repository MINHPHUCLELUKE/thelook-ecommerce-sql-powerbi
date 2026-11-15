/* =====================================================================
   TheLook E-commerce | 03 Star schema (schema dw)
   Source: clean.*   Run after 01_clean_layer.sql. Safe to re-run.
   Facts: fact_order_items, fact_inventory, fact_web_sessions
   Dims : dim_date, dim_users, dim_products, dim_distribution_centers, dim_status
   Revenue definitions:
     gross_revenue = all statuses except Cancelled (returns still counted)
     net_revenue   = all statuses except Cancelled and Returned
   ===================================================================== */

IF SCHEMA_ID('dw') IS NULL EXEC('CREATE SCHEMA dw');
GO

/* ---------- reset (facts first, then dimensions) ---------- */
DROP TABLE IF EXISTS dw.fact_web_sessions;
DROP TABLE IF EXISTS dw.fact_inventory;
DROP TABLE IF EXISTS dw.fact_order_items;
DROP TABLE IF EXISTS dw.dim_status;
DROP TABLE IF EXISTS dw.dim_products;
DROP TABLE IF EXISTS dw.dim_distribution_centers;
DROP TABLE IF EXISTS dw.dim_users;
DROP TABLE IF EXISTS dw.dim_date;
GO

/* ---------- dim_date (2018-01-01 to 2024-12-31) ---------- */
WITH d AS (
  SELECT CAST('2018-01-01' AS date) AS dt
  UNION ALL
  SELECT DATEADD(DAY, 1, dt) FROM d WHERE dt < '2024-12-31'
)
SELECT CAST(CONVERT(char(8), dt, 112) AS int)           AS date_key,
       dt                                               AS full_date,
       YEAR(dt)                                         AS year_no,
       DATEPART(QUARTER, dt)                            AS quarter_no,
       MONTH(dt)                                        AS month_no,
       DATENAME(MONTH, dt)                              AS month_name,
       CONVERT(char(7), dt, 126)                        AS year_month,
       DAY(dt)                                          AS day_of_month,
       (DATEDIFF(DAY, '2018-01-01', dt) % 7) + 1        AS weekday_no,      -- Monday = 1
       DATENAME(WEEKDAY, dt)                            AS weekday_name,
       CASE WHEN DATEDIFF(DAY, '2018-01-01', dt) % 7 >= 5 THEN 1 ELSE 0 END AS is_weekend,
       /* 1 for Jan 1 to May 13 of any year: the window that exists in every year including partial 2024 */
       CASE WHEN MONTH(dt) < 5 OR (MONTH(dt) = 5 AND DAY(dt) <= 13) THEN 1 ELSE 0 END AS is_ytd_window
INTO dw.dim_date
FROM d
OPTION (MAXRECURSION 0);
ALTER TABLE dw.dim_date ALTER COLUMN date_key int NOT NULL;
ALTER TABLE dw.dim_date ADD CONSTRAINT PK_dim_date PRIMARY KEY (date_key);
GO

/* ---------- dim_status (revenue rules in one place) ---------- */
CREATE TABLE dw.dim_status (
  status           nvarchar(20) NOT NULL PRIMARY KEY,
  status_sort      int NOT NULL,
  is_cancelled     int NOT NULL,
  is_returned      int NOT NULL,
  is_gross_revenue int NOT NULL,
  is_net_revenue   int NOT NULL
);
INSERT INTO dw.dim_status VALUES
 ('Processing',1,0,0,1,1),
 ('Shipped',   2,0,0,1,1),
 ('Complete',  3,0,0,1,1),
 ('Returned',  4,0,1,1,0),
 ('Cancelled', 5,1,0,0,0);
GO

/* ---------- dim_distribution_centers ---------- */
SELECT distribution_center_id AS distribution_center_key,
       name AS distribution_center_name, latitude, longitude
INTO dw.dim_distribution_centers
FROM clean.distribution_centers;
ALTER TABLE dw.dim_distribution_centers ADD CONSTRAINT PK_dim_dc PRIMARY KEY (distribution_center_key);
GO

/* ---------- dim_users (no email or street address: not needed for analysis) ---------- */
SELECT u.user_id AS user_key,
       CONCAT(u.first_name, ' ', u.last_name) AS full_name,
       u.age,
       CASE WHEN u.age < 18 THEN '12-17' WHEN u.age < 25 THEN '18-24' WHEN u.age < 35 THEN '25-34'
            WHEN u.age < 45 THEN '35-44' WHEN u.age < 55 THEN '45-54' WHEN u.age < 65 THEN '55-64'
            ELSE '65+' END AS age_group,
       u.gender, u.country, u.state, u.city, u.latitude, u.longitude,
       u.traffic_source AS acquisition_channel,
       u.created_at AS signup_at,
       CAST(CONVERT(char(8), u.created_at, 112) AS int) AS signup_date_key
INTO dw.dim_users
FROM clean.users u;
ALTER TABLE dw.dim_users ADD CONSTRAINT PK_dim_users PRIMARY KEY (user_key);
GO

/* ---------- dim_products ---------- */
SELECT p.product_id AS product_key, p.name AS product_name,
       CASE WHEN p.brand IS NULL OR LTRIM(RTRIM(p.brand)) = '' THEN 'Unknown' ELSE p.brand END AS brand,
       p.category, p.department, p.sku, p.cost, p.retail_price, p.unit_margin,
       CASE WHEN p.retail_price < 25  THEN 'Under $25'
            WHEN p.retail_price < 50  THEN '$25-49'
            WHEN p.retail_price < 100 THEN '$50-99'
            WHEN p.retail_price < 200 THEN '$100-199'
            ELSE '$200+' END AS price_band,
       p.distribution_center_id AS distribution_center_key
INTO dw.dim_products
FROM clean.products p;
ALTER TABLE dw.dim_products ADD CONSTRAINT PK_dim_products PRIMARY KEY (product_key);
ALTER TABLE dw.dim_products ADD CONSTRAINT FK_dim_products_dc
  FOREIGN KEY (distribution_center_key) REFERENCES dw.dim_distribution_centers(distribution_center_key);
GO

/* helper index: order_items.inventory_item_id points at the wrong inventory row,
   so the sold row is found by product and sale time (see data_quality_report finding 13) */
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_inv_prod_sold' AND object_id = OBJECT_ID('clean.inventory'))
  DROP INDEX IX_inv_prod_sold ON clean.inventory;
CREATE INDEX IX_inv_prod_sold ON clean.inventory(product_id, sold_at);
GO

/* ---------- fact_order_items ---------- */
SELECT oi.order_item_id,
       oi.order_id,
       oi.user_id    AS user_key,
       oi.product_id AS product_key,
       p.distribution_center_id AS distribution_center_key,
       oi.status,
       CAST(CONVERT(char(8), oi.created_at,   112) AS int) AS created_date_key,
       CAST(CONVERT(char(8), oi.shipped_at,   112) AS int) AS shipped_date_key,
       CAST(CONVERT(char(8), oi.delivered_at, 112) AS int) AS delivered_date_key,
       CAST(CONVERT(char(8), oi.returned_at,  112) AS int) AS returned_date_key,
       oi.created_at, oi.shipped_at, oi.delivered_at, oi.returned_at,
       oi.sale_price,
       p.cost AS unit_cost,
       oi.sale_price - p.cost AS unit_margin,
       CASE WHEN s.is_gross_revenue = 1 THEN oi.sale_price ELSE 0 END          AS gross_revenue,
       CASE WHEN s.is_net_revenue   = 1 THEN oi.sale_price ELSE 0 END          AS net_revenue,
       CASE WHEN s.is_gross_revenue = 1 THEN oi.sale_price - p.cost ELSE 0 END AS gross_profit,
       CASE WHEN s.is_net_revenue   = 1 THEN oi.sale_price - p.cost ELSE 0 END AS net_profit,
       CASE WHEN s.is_returned  = 1 THEN oi.sale_price ELSE 0 END              AS returned_revenue,
       CASE WHEN s.is_cancelled = 1 THEN oi.sale_price ELSE 0 END              AS cancelled_value,
       s.is_returned, s.is_cancelled,
       oi.is_timeline_invalid,
       /* durations only for rows with a valid timeline */
       CASE WHEN oi.is_timeline_invalid = 0 AND oi.shipped_at IS NOT NULL
            THEN DATEDIFF(HOUR, oi.created_at, oi.shipped_at) / 24.0 END       AS days_to_ship,
       CASE WHEN oi.is_timeline_invalid = 0 AND oi.delivered_at IS NOT NULL
            THEN DATEDIFF(HOUR, oi.shipped_at, oi.delivered_at) / 24.0 END     AS days_in_transit,
       CASE WHEN oi.is_timeline_invalid = 0 AND oi.delivered_at IS NOT NULL
            THEN DATEDIFF(HOUR, oi.created_at, oi.delivered_at) / 24.0 END     AS days_to_deliver,
       inv.inventory_item_id AS sold_inventory_item_key
INTO dw.fact_order_items
FROM clean.order_items oi
JOIN clean.products p ON p.product_id = oi.product_id
JOIN dw.dim_status s  ON s.status = oi.status
OUTER APPLY (SELECT TOP 1 i.inventory_item_id
             FROM clean.inventory i
             WHERE i.product_id = oi.product_id AND i.sold_at = oi.created_at
             ORDER BY i.inventory_item_id) inv;
ALTER TABLE dw.fact_order_items ADD CONSTRAINT PK_fact_order_items PRIMARY KEY (order_item_id);
ALTER TABLE dw.fact_order_items ADD CONSTRAINT FK_foi_user    FOREIGN KEY (user_key)    REFERENCES dw.dim_users(user_key);
ALTER TABLE dw.fact_order_items ADD CONSTRAINT FK_foi_product FOREIGN KEY (product_key) REFERENCES dw.dim_products(product_key);
ALTER TABLE dw.fact_order_items ADD CONSTRAINT FK_foi_dc      FOREIGN KEY (distribution_center_key) REFERENCES dw.dim_distribution_centers(distribution_center_key);
ALTER TABLE dw.fact_order_items ADD CONSTRAINT FK_foi_created FOREIGN KEY (created_date_key) REFERENCES dw.dim_date(date_key);
ALTER TABLE dw.fact_order_items ADD CONSTRAINT FK_foi_shipped FOREIGN KEY (shipped_date_key) REFERENCES dw.dim_date(date_key);
ALTER TABLE dw.fact_order_items ADD CONSTRAINT FK_foi_deliv   FOREIGN KEY (delivered_date_key) REFERENCES dw.dim_date(date_key);
ALTER TABLE dw.fact_order_items ADD CONSTRAINT FK_foi_return  FOREIGN KEY (returned_date_key) REFERENCES dw.dim_date(date_key);
CREATE INDEX IX_foi_created ON dw.fact_order_items(created_date_key) INCLUDE (gross_revenue, net_revenue, net_profit);
CREATE INDEX IX_foi_order   ON dw.fact_order_items(order_id);
GO

/* ---------- fact_inventory ---------- */
DECLARE @as_of datetime2(3) = (SELECT MAX(created_at) FROM clean.events);   -- last activity in the data

SELECT i.inventory_item_id,
       i.product_id AS product_key,
       i.distribution_center_id AS distribution_center_key,
       i.cost, p.retail_price,
       i.received_at, i.sold_at,
       CAST(CONVERT(char(8), i.received_at, 112) AS int) AS received_date_key,
       CAST(CONVERT(char(8), i.sold_at,     112) AS int) AS sold_date_key,
       CASE WHEN i.sold_at IS NULL THEN 0 ELSE 1 END AS is_sold,
       DATEDIFF(DAY, i.received_at, COALESCE(i.sold_at, @as_of)) AS days_in_stock,
       CASE WHEN i.sold_at IS NULL THEN NULL ELSE DATEDIFF(DAY, i.received_at, i.sold_at) END AS days_to_sell,
       CASE WHEN i.sold_at IS NOT NULL THEN 'Sold'
            WHEN DATEDIFF(DAY, i.received_at, @as_of) <= 90  THEN '0-90 days'
            WHEN DATEDIFF(DAY, i.received_at, @as_of) <= 180 THEN '91-180 days'
            WHEN DATEDIFF(DAY, i.received_at, @as_of) <= 365 THEN '181-365 days'
            WHEN DATEDIFF(DAY, i.received_at, @as_of) <= 730 THEN '1-2 years'
            ELSE 'Over 2 years' END AS aging_bucket
INTO dw.fact_inventory
FROM clean.inventory i
JOIN clean.products p ON p.product_id = i.product_id;
ALTER TABLE dw.fact_inventory ADD CONSTRAINT PK_fact_inventory PRIMARY KEY (inventory_item_id);
ALTER TABLE dw.fact_inventory ADD CONSTRAINT FK_fi_product FOREIGN KEY (product_key) REFERENCES dw.dim_products(product_key);
ALTER TABLE dw.fact_inventory ADD CONSTRAINT FK_fi_dc      FOREIGN KEY (distribution_center_key) REFERENCES dw.dim_distribution_centers(distribution_center_key);
ALTER TABLE dw.fact_inventory ADD CONSTRAINT FK_fi_recv    FOREIGN KEY (received_date_key) REFERENCES dw.dim_date(date_key);
ALTER TABLE dw.fact_inventory ADD CONSTRAINT FK_fi_sold    FOREIGN KEY (sold_date_key) REFERENCES dw.dim_date(date_key);
GO

/* ---------- fact_web_sessions (one row per session, 680,862 rows instead of 2.4M events) ---------- */
WITH s AS (
  SELECT CAST(e.session_id AS nvarchar(64)) AS session_id,
         MIN(e.created_at) AS session_start,
         MAX(e.created_at) AS session_end,
         MAX(e.user_id)    AS user_key,
         MAX(e.is_anonymous) AS is_anonymous,
         MIN(e.traffic_source) AS traffic_source,
         MIN(e.browser) AS browser,
         MIN(e.state)   AS state,
         COUNT(*) AS event_count,
         MAX(CASE WHEN e.event_type = 'home'       THEN 1 ELSE 0 END) AS has_home,
         MAX(CASE WHEN e.event_type = 'department' THEN 1 ELSE 0 END) AS has_department,
         MAX(CASE WHEN e.event_type = 'product'    THEN 1 ELSE 0 END) AS has_product,
         MAX(CASE WHEN e.event_type = 'cart'       THEN 1 ELSE 0 END) AS has_cart,
         MAX(CASE WHEN e.event_type = 'purchase'   THEN 1 ELSE 0 END) AS has_purchase,
         MAX(CASE WHEN e.event_type = 'cancel'     THEN 1 ELSE 0 END) AS has_cancel
  FROM clean.events e
  GROUP BY CAST(e.session_id AS nvarchar(64))
)
SELECT s.*,
       CAST(CONVERT(char(8), s.session_start, 112) AS int) AS session_date_key,
       CASE WHEN has_purchase = 1 THEN 3 WHEN has_cart = 1 THEN 2 WHEN has_product = 1 THEN 1 ELSE 0 END AS funnel_stage,
       CASE WHEN has_purchase = 1 THEN 'Purchased'
            WHEN has_cancel   = 1 THEN 'Cart then cancel'
            WHEN has_cart     = 1 THEN 'Abandoned cart'
            ELSE 'Browsed only' END AS session_outcome
INTO dw.fact_web_sessions
FROM s;
ALTER TABLE dw.fact_web_sessions ALTER COLUMN session_id nvarchar(64) NOT NULL;
ALTER TABLE dw.fact_web_sessions ADD CONSTRAINT PK_fact_web_sessions PRIMARY KEY (session_id);
ALTER TABLE dw.fact_web_sessions ADD CONSTRAINT FK_fws_user FOREIGN KEY (user_key) REFERENCES dw.dim_users(user_key);
ALTER TABLE dw.fact_web_sessions ADD CONSTRAINT FK_fws_date FOREIGN KEY (session_date_key) REFERENCES dw.dim_date(date_key);
CREATE INDEX IX_fws_date ON dw.fact_web_sessions(session_date_key) INCLUDE (traffic_source, has_cart, has_purchase);
GO

SELECT 'dim_date' AS tbl, COUNT(*) AS row_count FROM dw.dim_date
UNION ALL SELECT 'dim_users',     COUNT(*) FROM dw.dim_users
UNION ALL SELECT 'dim_products',  COUNT(*) FROM dw.dim_products
UNION ALL SELECT 'dim_distribution_centers', COUNT(*) FROM dw.dim_distribution_centers
UNION ALL SELECT 'dim_status',    COUNT(*) FROM dw.dim_status
UNION ALL SELECT 'fact_order_items',  COUNT(*) FROM dw.fact_order_items
UNION ALL SELECT 'fact_inventory',    COUNT(*) FROM dw.fact_inventory
UNION ALL SELECT 'fact_web_sessions', COUNT(*) FROM dw.fact_web_sessions;
