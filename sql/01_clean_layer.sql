/* =====================================================================
   TheLook E-commerce | 01 Clean layer
   Source: dbo.* (raw import)   Target: clean.* (typed, keyed, flagged)
   Run on the restored database. Safe to re-run.
   ===================================================================== */

IF SCHEMA_ID('clean') IS NULL EXEC('CREATE SCHEMA clean');
GO

/* ---------- reset: drop in dependency order so the script can be re-run ---------- */
DROP TABLE IF EXISTS clean.order_items;
DROP TABLE IF EXISTS clean.orders;
DROP TABLE IF EXISTS clean.events;
DROP TABLE IF EXISTS clean.inventory;
DROP TABLE IF EXISTS clean.products;
DROP TABLE IF EXISTS clean.users;
DROP TABLE IF EXISTS clean.distribution_centers;
GO

/* ---------- distribution_centers ---------- */
DROP TABLE IF EXISTS clean.distribution_centers;
SELECT id AS distribution_center_id, name, latitude, longitude
INTO clean.distribution_centers
FROM dbo.distribution_centers;
ALTER TABLE clean.distribution_centers ADD CONSTRAINT PK_clean_dc PRIMARY KEY (distribution_center_id);
GO

/* ---------- users ---------- */
DROP TABLE IF EXISTS clean.users;
SELECT id AS user_id,
       LTRIM(RTRIM(first_name)) AS first_name,
       LTRIM(RTRIM(last_name))  AS last_name,
       email, age, gender, state, city,
       CASE LTRIM(RTRIM(country)) WHEN 'Brasil' THEN 'Brazil' WHEN N'Espa' + NCHAR(241) + N'a' THEN 'Spain'
            WHEN 'Deutschland' THEN 'Germany' ELSE LTRIM(RTRIM(country)) END AS country,
       postal_code,
       latitude, longitude, traffic_source,
       TRY_CAST(REPLACE(created_at,' UTC','') AS datetime2(3)) AS created_at
INTO clean.users
FROM dbo.users;
ALTER TABLE clean.users ADD CONSTRAINT PK_clean_users PRIMARY KEY (user_id);
GO

/* ---------- products ---------- */
DROP TABLE IF EXISTS clean.products;
SELECT id AS product_id, name, brand, category, department, sku,
       cost, retail_price,
       retail_price - cost AS unit_margin,
       distribution_center_id
INTO clean.products
FROM dbo.products;
ALTER TABLE clean.products ALTER COLUMN product_id bigint NOT NULL;
ALTER TABLE clean.products ADD CONSTRAINT PK_clean_products PRIMARY KEY (product_id);
ALTER TABLE clean.products ADD CONSTRAINT FK_products_dc
    FOREIGN KEY (distribution_center_id) REFERENCES clean.distribution_centers(distribution_center_id);
GO

/* ---------- inventory (stock items) ---------- */
DROP TABLE IF EXISTS clean.inventory;
SELECT id AS inventory_item_id, product_id, cost,
       TRY_CAST(REPLACE(created_at,' UTC','') AS datetime2(3)) AS received_at,
       TRY_CAST(REPLACE(sold_at,' UTC','')    AS datetime2(3)) AS sold_at,
       product_distribution_center_id AS distribution_center_id
INTO clean.inventory
FROM dbo.inventory_events;
ALTER TABLE clean.inventory ALTER COLUMN inventory_item_id bigint NOT NULL;
ALTER TABLE clean.inventory ADD CONSTRAINT PK_clean_inventory PRIMARY KEY (inventory_item_id);
GO

/* ---------- orders ---------- */
DROP TABLE IF EXISTS clean.orders;
SELECT o.order_id, o.user_id, o.status, o.num_of_item,
       t.created_at, t.shipped_at, t.delivered_at, t.returned_at
INTO clean.orders
FROM dbo.orders o
CROSS APPLY (VALUES (
    TRY_CAST(REPLACE(o.created_at,' UTC','')   AS datetime2(3)),
    TRY_CAST(REPLACE(o.shipped_at,' UTC','')   AS datetime2(3)),
    TRY_CAST(REPLACE(o.delivered_at,' UTC','') AS datetime2(3)),
    TRY_CAST(REPLACE(o.returned_at,' UTC','')  AS datetime2(3))
)) t(created_at, shipped_at, delivered_at, returned_at);
ALTER TABLE clean.orders ADD CONSTRAINT PK_clean_orders PRIMARY KEY (order_id);
ALTER TABLE clean.orders ADD CONSTRAINT FK_orders_users
    FOREIGN KEY (user_id) REFERENCES clean.users(user_id);
GO

/* ---------- order_items (with data quality flag) ---------- */
DROP TABLE IF EXISTS clean.order_items;
SELECT oi.id AS order_item_id, oi.order_id, oi.user_id, oi.product_id, oi.inventory_item_id,
       oi.status, oi.sale_price,
       t.created_at, t.shipped_at, t.delivered_at, t.returned_at,
       CASE WHEN t.shipped_at   < t.created_at
              OR t.delivered_at < t.shipped_at
              OR t.returned_at  < t.delivered_at THEN 1 ELSE 0 END AS is_timeline_invalid
INTO clean.order_items
FROM dbo.order_items oi
CROSS APPLY (VALUES (
    TRY_CAST(REPLACE(oi.created_at,' UTC','')   AS datetime2(3)),
    TRY_CAST(REPLACE(oi.shipped_at,' UTC','')   AS datetime2(3)),
    TRY_CAST(REPLACE(oi.delivered_at,' UTC','') AS datetime2(3)),
    TRY_CAST(REPLACE(oi.returned_at,' UTC','')  AS datetime2(3))
)) t(created_at, shipped_at, delivered_at, returned_at);
ALTER TABLE clean.order_items ADD CONSTRAINT PK_clean_order_items PRIMARY KEY (order_item_id);
ALTER TABLE clean.order_items ADD CONSTRAINT FK_oi_orders    FOREIGN KEY (order_id)          REFERENCES clean.orders(order_id);
ALTER TABLE clean.order_items ADD CONSTRAINT FK_oi_products  FOREIGN KEY (product_id)        REFERENCES clean.products(product_id);
ALTER TABLE clean.order_items ADD CONSTRAINT FK_oi_inventory FOREIGN KEY (inventory_item_id) REFERENCES clean.inventory(inventory_item_id);
CREATE INDEX IX_oi_created ON clean.order_items(created_at) INCLUDE (sale_price, status);
GO

/* ---------- events (web clickstream) ---------- */
DROP TABLE IF EXISTS clean.events;
SELECT id AS event_id,
       TRY_CAST(user_id AS bigint) AS user_id,
       CASE WHEN TRY_CAST(user_id AS bigint) IS NULL THEN 1 ELSE 0 END AS is_anonymous,
       session_id, sequence_number,
       TRY_CAST(REPLACE(created_at,' UTC','') AS datetime2(3)) AS created_at,
       city, state, postal_code, browser, traffic_source, uri, event_type
INTO clean.events
FROM dbo.events;
ALTER TABLE clean.events ALTER COLUMN event_id bigint NOT NULL;
ALTER TABLE clean.events ADD CONSTRAINT PK_clean_events PRIMARY KEY (event_id);
CREATE INDEX IX_events_session ON clean.events(session_id) INCLUDE (event_type, traffic_source, created_at);
GO

/* ---------- validation: raw vs clean ---------- */
SELECT 'users'        AS tbl, (SELECT COUNT(*) FROM dbo.users)            AS raw_rows, (SELECT COUNT(*) FROM clean.users)       AS clean_rows
UNION ALL SELECT 'products',   (SELECT COUNT(*) FROM dbo.products),         (SELECT COUNT(*) FROM clean.products)
UNION ALL SELECT 'inventory',  (SELECT COUNT(*) FROM dbo.inventory_events), (SELECT COUNT(*) FROM clean.inventory)
UNION ALL SELECT 'orders',     (SELECT COUNT(*) FROM dbo.orders),           (SELECT COUNT(*) FROM clean.orders)
UNION ALL SELECT 'order_items',(SELECT COUNT(*) FROM dbo.order_items),      (SELECT COUNT(*) FROM clean.order_items)
UNION ALL SELECT 'events',     (SELECT COUNT(*) FROM dbo.events),           (SELECT COUNT(*) FROM clean.events);

/* integrity checks: oi_null_created should be 0 (no failed date conversion on order_items.created_at);
   oi_timeline_invalid is informational (35,440 rows expected) */
SELECT
  SUM(CASE WHEN created_at IS NULL THEN 1 ELSE 0 END) AS oi_null_created,
  SUM(is_timeline_invalid)                            AS oi_timeline_invalid
FROM clean.order_items;
