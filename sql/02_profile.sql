/* =====================================================================
   TheLook E-commerce | 02 Profiling (run after 01_clean_layer.sql)
   Read-only. Produces result sets that feed the data dictionary and
   the data quality report. Tip: in SSMS press Ctrl+Shift+F (results
   to file) before running to save the output as a report file.
   ===================================================================== */

/* ---- USERS ---- */
SELECT 'gender' AS dim, gender AS value, COUNT(*) AS n FROM clean.users GROUP BY gender
UNION ALL SELECT 'country', country, COUNT(*) FROM clean.users GROUP BY country
UNION ALL SELECT 'traffic_source', traffic_source, COUNT(*) FROM clean.users GROUP BY traffic_source
ORDER BY dim, n DESC;

SELECT MIN(age) AS min_age, MAX(age) AS max_age, AVG(age*1.0) AS avg_age,
       SUM(CASE WHEN age < 13 OR age > 100 THEN 1 ELSE 0 END) AS odd_age,
       COUNT(*) - COUNT(DISTINCT email) AS dup_email,
       MIN(created_at) AS first_signup, MAX(created_at) AS last_signup
FROM clean.users;

/* ---- PRODUCTS ---- */
SELECT COUNT(*) AS products,
       SUM(CASE WHEN retail_price < 1 THEN 1 ELSE 0 END) AS price_under_1,
       SUM(CASE WHEN cost > retail_price THEN 1 ELSE 0 END) AS cost_gt_price,
       SUM(CASE WHEN cost <= 0 THEN 1 ELSE 0 END) AS cost_zero,
       SUM(CASE WHEN brand IS NULL OR LTRIM(RTRIM(brand)) = '' THEN 1 ELSE 0 END) AS brand_blank,
       COUNT(*) - COUNT(DISTINCT sku) AS dup_sku,
       MIN(retail_price) AS min_price, MAX(retail_price) AS max_price,
       AVG(unit_margin) AS avg_unit_margin
FROM clean.products;

SELECT COUNT(*) AS products_never_sold
FROM clean.products p
WHERE NOT EXISTS (SELECT 1 FROM clean.order_items oi WHERE oi.product_id = p.product_id);

/* ---- ORDERS ---- */
SELECT status, COUNT(*) AS n FROM clean.orders GROUP BY status ORDER BY n DESC;

SELECT COUNT(*) AS orders_total,
       SUM(CASE WHEN o.num_of_item <> x.cnt THEN 1 ELSE 0 END) AS item_count_mismatch,
       SUM(CASE WHEN x.cnt IS NULL THEN 1 ELSE 0 END) AS orders_without_items
FROM clean.orders o
LEFT JOIN (SELECT order_id, COUNT(*) AS cnt FROM clean.order_items GROUP BY order_id) x
       ON x.order_id = o.order_id;

SELECT SUM(CASE WHEN oi.user_id <> o.user_id THEN 1 ELSE 0 END) AS item_user_mismatch,
       SUM(CASE WHEN oi.status <> o.status THEN 1 ELSE 0 END) AS item_vs_order_status_mismatch
FROM clean.order_items oi
JOIN clean.orders o ON o.order_id = oi.order_id;

/* orders.gender (raw column) vs users.gender */
SELECT SUM(CASE WHEN o.gender <> u.gender THEN 1 ELSE 0 END) AS order_gender_mismatch
FROM dbo.orders o
JOIN clean.users u ON u.user_id = o.user_id;

/* ---- ORDER ITEMS ---- */
SELECT status, COUNT(*) AS n,
       SUM(CASE WHEN shipped_at   IS NULL THEN 1 ELSE 0 END) AS no_shipped_at,
       SUM(CASE WHEN delivered_at IS NULL THEN 1 ELSE 0 END) AS no_delivered_at,
       SUM(CASE WHEN returned_at  IS NULL THEN 1 ELSE 0 END) AS no_returned_at,
       SUM(is_timeline_invalid) AS invalid_timeline,
       SUM(sale_price) AS sale_price_total
FROM clean.order_items GROUP BY status ORDER BY n DESC;

SELECT MIN(oi.sale_price) AS min_sale, MAX(oi.sale_price) AS max_sale, AVG(oi.sale_price) AS avg_sale,
       SUM(CASE WHEN oi.sale_price <= 0 THEN 1 ELSE 0 END) AS non_positive_price,
       SUM(CASE WHEN oi.sale_price > p.retail_price + 0.01 THEN 1 ELSE 0 END) AS above_retail,
       SUM(CASE WHEN oi.sale_price < p.retail_price - 0.01 THEN 1 ELSE 0 END) AS below_retail,
       SUM(CASE WHEN oi.sale_price < p.cost THEN 1 ELSE 0 END) AS sold_below_cost
FROM clean.order_items oi
JOIN clean.products p ON p.product_id = oi.product_id;

SELECT COUNT(*) - COUNT(DISTINCT inventory_item_id) AS dup_inventory_item_in_orders
FROM clean.order_items;

/* ---- INVENTORY ---- */
SELECT COUNT(*) AS items,
       SUM(CASE WHEN sold_at IS NULL THEN 1 ELSE 0 END) AS unsold,
       SUM(CASE WHEN sold_at < received_at THEN 1 ELSE 0 END) AS sold_before_received,
       MIN(received_at) AS first_received, MAX(received_at) AS last_received
FROM clean.inventory;

SELECT SUM(CASE WHEN ABS(i.cost - p.cost) > 0.01 THEN 1 ELSE 0 END) AS cost_differs_from_product
FROM clean.inventory i
JOIN clean.products p ON p.product_id = i.product_id;

SELECT SUM(CASE WHEN i.sold_at IS NOT NULL AND oi.inventory_item_id IS NULL THEN 1 ELSE 0 END) AS sold_but_not_in_orders,
       SUM(CASE WHEN i.sold_at IS NULL AND oi.inventory_item_id IS NOT NULL THEN 1 ELSE 0 END) AS unsold_but_ordered
FROM clean.inventory i
LEFT JOIN clean.order_items oi ON oi.inventory_item_id = i.inventory_item_id;

/* ---- EVENTS ---- */
SELECT event_type,
       SUM(CASE WHEN is_anonymous = 1 THEN 1 ELSE 0 END) AS anonymous,
       SUM(CASE WHEN is_anonymous = 0 THEN 1 ELSE 0 END) AS logged_in
FROM clean.events GROUP BY event_type ORDER BY event_type;

SELECT COUNT(DISTINCT session_id) AS sessions,
       COUNT(*) * 1.0 / COUNT(DISTINCT session_id) AS events_per_session,
       MIN(created_at) AS first_event, MAX(created_at) AS last_event,
       SUM(CASE WHEN created_at IS NULL THEN 1 ELSE 0 END) AS null_dates
FROM clean.events;

SELECT COUNT(DISTINCT session_id) AS sessions_with_purchase
FROM clean.events WHERE event_type = 'purchase';

SELECT COUNT(*) AS events_with_unknown_user
FROM clean.events e
WHERE e.user_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM clean.users u WHERE u.user_id = e.user_id);

SELECT COUNT(*) AS sessions_with_multiple_sources
FROM (SELECT session_id FROM clean.events
      GROUP BY session_id HAVING COUNT(DISTINCT traffic_source) > 1) x;
