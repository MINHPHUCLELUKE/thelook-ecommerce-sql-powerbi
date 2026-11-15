/* =====================================================================
   TheLook E-commerce | 03b Reconciliation and link checks
   Run after 03_star_schema.sql. Read-only. Tip: Ctrl+Shift+F saves the results to a file.
   ===================================================================== */

/* 1. Totals must match the clean layer (every row should say PASS) */
SELECT check_name, expected, actual,
       CASE WHEN expected = actual THEN 'PASS' ELSE 'FAIL' END AS result
FROM (
  SELECT 'fact_order_items rows' AS check_name,
         CAST((SELECT COUNT(*) FROM clean.order_items) AS decimal(18,2)) AS expected,
         CAST((SELECT COUNT(*) FROM dw.fact_order_items) AS decimal(18,2)) AS actual
  UNION ALL SELECT 'fact_inventory rows',  (SELECT COUNT(*) FROM clean.inventory), (SELECT COUNT(*) FROM dw.fact_inventory)
  UNION ALL SELECT 'fact_web_sessions rows', (SELECT COUNT(DISTINCT session_id) FROM clean.events), (SELECT COUNT(*) FROM dw.fact_web_sessions)
  UNION ALL SELECT 'sum of session events', (SELECT COUNT(*) FROM clean.events), (SELECT SUM(event_count) FROM dw.fact_web_sessions)
  UNION ALL SELECT 'dim_users rows', (SELECT COUNT(*) FROM clean.users), (SELECT COUNT(*) FROM dw.dim_users)
  UNION ALL SELECT 'dim_products rows', (SELECT COUNT(*) FROM clean.products), (SELECT COUNT(*) FROM dw.dim_products)
  UNION ALL SELECT 'gross revenue',
         (SELECT CAST(SUM(CASE WHEN status <> 'Cancelled' THEN sale_price ELSE 0 END) AS decimal(18,2)) FROM clean.order_items),
         (SELECT CAST(SUM(gross_revenue) AS decimal(18,2)) FROM dw.fact_order_items)
  UNION ALL SELECT 'net revenue',
         (SELECT CAST(SUM(CASE WHEN status NOT IN ('Cancelled','Returned') THEN sale_price ELSE 0 END) AS decimal(18,2)) FROM clean.order_items),
         (SELECT CAST(SUM(net_revenue) AS decimal(18,2)) FROM dw.fact_order_items)
  UNION ALL SELECT 'gross revenue vs profiling baseline', 9172697.60,
         (SELECT CAST(SUM(gross_revenue) AS decimal(18,2)) FROM dw.fact_order_items)
  UNION ALL SELECT 'net revenue vs profiling baseline', 8096531.48,
         (SELECT CAST(SUM(net_revenue) AS decimal(18,2)) FROM dw.fact_order_items)
  UNION ALL SELECT 'returned items', 18041, (SELECT SUM(is_returned) FROM dw.fact_order_items)
  UNION ALL SELECT 'cancelled items', 27072, (SELECT SUM(is_cancelled) FROM dw.fact_order_items)
  UNION ALL SELECT 'invalid-timeline rows with a duration (must be 0)', 0,
         (SELECT COUNT(*) FROM dw.fact_order_items WHERE is_timeline_invalid = 1 AND days_to_ship IS NOT NULL)
  UNION ALL SELECT 'sold inventory rows', 180862, (SELECT SUM(is_sold) FROM dw.fact_inventory)
  UNION ALL SELECT 'purchased sessions', 180862, (SELECT SUM(has_purchase) FROM dw.fact_web_sessions)
  UNION ALL SELECT 'max session_id length (must be <= 64)', 1,
         (SELECT CASE WHEN MAX(LEN(session_id)) <= 64 THEN 1 ELSE 0 END FROM clean.events)
) t;

/* 2. Inventory link: is (product_id, sale time) a safe one-to-one key? */
SELECT (SELECT COUNT(*) FROM (SELECT product_id, sold_at FROM clean.inventory WHERE sold_at IS NOT NULL
                              GROUP BY product_id, sold_at HAVING COUNT(*) > 1) x) AS dup_sold_rows,
       (SELECT COUNT(*) FROM (SELECT product_id, created_at FROM clean.order_items
                              GROUP BY product_id, created_at HAVING COUNT(*) > 1) y) AS dup_order_items,
       (SELECT COUNT(*) FROM dw.fact_order_items WHERE sold_inventory_item_key IS NULL) AS items_without_sold_row;

/* 3. The raw inventory_item_id pointer: does it even point at the same product? */
SELECT SUM(CASE WHEN i.product_id <> oi.product_id THEN 1 ELSE 0 END) AS pointer_wrong_product,
       SUM(CASE WHEN i.received_at > oi.created_at THEN 1 ELSE 0 END) AS pointer_received_after_order,
       COUNT(*) AS items
FROM clean.order_items oi
JOIN clean.inventory i ON i.inventory_item_id = oi.inventory_item_id;

/* 4. Can purchase events be tied to order items by user and time? (channel revenue attribution) */
SELECT COUNT(*) AS matched_pairs,
       COUNT(DISTINCT e.event_id) AS distinct_purchase_events,
       COUNT(DISTINCT oi.order_item_id) AS distinct_order_items
FROM clean.events e
JOIN clean.order_items oi ON oi.user_id = e.user_id AND oi.created_at = e.created_at
WHERE e.event_type = 'purchase';
