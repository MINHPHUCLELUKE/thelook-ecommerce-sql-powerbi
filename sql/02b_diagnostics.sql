/* =====================================================================
   TheLook E-commerce | 02b Diagnostics
   Diagnostics behind findings 11 to 13 of the data quality report.
   Read-only. Tip: press Ctrl+Shift+F first to save the results to a file.
   ===================================================================== */

/* A. Session shapes: what combinations of events make up a session? */
SELECT anon, home, dept, prod, cart, purch, cancel, COUNT(*) AS sessions
FROM (
  SELECT session_id,
         MAX(is_anonymous) AS anon,
         MAX(CASE WHEN event_type = 'home'       THEN 1 ELSE 0 END) AS home,
         MAX(CASE WHEN event_type = 'department' THEN 1 ELSE 0 END) AS dept,
         MAX(CASE WHEN event_type = 'product'    THEN 1 ELSE 0 END) AS prod,
         MAX(CASE WHEN event_type = 'cart'       THEN 1 ELSE 0 END) AS cart,
         MAX(CASE WHEN event_type = 'purchase'   THEN 1 ELSE 0 END) AS purch,
         MAX(CASE WHEN event_type = 'cancel'     THEN 1 ELSE 0 END) AS cancel
  FROM clean.events GROUP BY session_id
) s
GROUP BY anon, home, dept, prod, cart, purch, cancel
ORDER BY sessions DESC;

/* B. Inventory: does every sold row have a "twin" row with the same product and received time? */
SELECT COUNT(*) AS sold_rows, SUM(x.has_twin) AS has_unsold_twin
FROM (
  SELECT CASE WHEN EXISTS (
           SELECT 1 FROM clean.inventory n
           WHERE n.sold_at IS NULL AND n.product_id = s.product_id
             AND n.received_at = s.received_at
             AND n.inventory_item_id <> s.inventory_item_id) THEN 1 ELSE 0 END AS has_twin
  FROM clean.inventory s WHERE s.sold_at IS NOT NULL
) x;

/* C. Inventory: do sold rows match order items on product and time? */
SELECT COUNT(*) AS sold_rows_matching_an_order_item
FROM clean.inventory s
JOIN clean.order_items oi ON oi.product_id = s.product_id AND oi.created_at = s.sold_at
WHERE s.sold_at IS NOT NULL;

/* D. Sample: an ordered inventory row beside its possible sold row */
SELECT TOP 10 oi.order_item_id, oi.inventory_item_id AS ordered_inv_id,
       i1.received_at AS ordered_received, i1.sold_at AS ordered_sold,
       s.inventory_item_id AS sold_inv_id, s.received_at AS sold_received, s.sold_at
FROM clean.order_items oi
JOIN clean.inventory i1 ON i1.inventory_item_id = oi.inventory_item_id
LEFT JOIN clean.inventory s ON s.product_id = oi.product_id AND s.sold_at = oi.created_at
ORDER BY oi.order_item_id;
