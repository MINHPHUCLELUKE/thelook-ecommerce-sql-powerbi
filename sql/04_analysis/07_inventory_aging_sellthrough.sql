/* =====================================================================
   4.7 Inventory aging and sell-through
   Business question: how much stock is sitting unsold, how old is it, and what is it worth?
   Sold status comes from inventory.sold_at (not order_items.inventory_item_id, see finding 13).
   Ages are measured as of the last activity in the data (13 May 2024).
   Note: sold_at is set for every order item, including cancelled and returned ones, so query G adds a net view.
   Techniques: conditional aggregation, window shares, RANK per group, CTE.
   ===================================================================== */

/* A. Sell-through by category */
SELECT p.category,
       COUNT(*) AS items_received,
       SUM(i.is_sold) AS items_sold,
       SUM(i.is_sold) * 1.0 / COUNT(*) AS sell_through_pct,
       SUM(CASE WHEN i.is_sold = 0 THEN 1 ELSE 0 END) AS unsold_items,
       SUM(CASE WHEN i.is_sold = 0 THEN i.cost ELSE 0 END) AS unsold_cost_value,
       SUM(CASE WHEN i.is_sold = 0 THEN i.retail_price ELSE 0 END) AS unsold_retail_value,
       AVG(i.days_to_sell * 1.0) AS avg_days_to_sell
FROM dw.fact_inventory i
JOIN dw.dim_products p ON p.product_key = i.product_key
GROUP BY p.category
ORDER BY unsold_cost_value DESC;

/* B. Aging of unsold stock */
SELECT i.aging_bucket,
       COUNT(*) AS unsold_items,
       COUNT(*) * 1.0 / SUM(COUNT(*)) OVER () AS share_of_unsold,
       SUM(i.cost) AS cost_value,
       SUM(i.cost) / SUM(SUM(i.cost)) OVER () AS share_of_cost_value
FROM dw.fact_inventory i
WHERE i.is_sold = 0
GROUP BY i.aging_bucket
ORDER BY MIN(i.days_in_stock);

/* C. Sell-through by the year stock was received.
      Recent receipts show higher sell-through: items that sell do so within about 30 days,
      so stock that is still unsold after a long time rarely sells. */
SELECT d.year_no AS received_year,
       COUNT(*) AS items_received,
       SUM(i.is_sold) * 1.0 / COUNT(*) AS sell_through_pct,
       AVG(i.days_to_sell * 1.0) AS avg_days_to_sell
FROM dw.fact_inventory i
JOIN dw.dim_date d ON d.date_key = i.received_date_key
GROUP BY d.year_no
ORDER BY d.year_no;

/* D. Stock position by distribution center */
SELECT dc.distribution_center_name,
       COUNT(*) AS items_received,
       SUM(i.is_sold) * 1.0 / COUNT(*) AS sell_through_pct,
       SUM(CASE WHEN i.is_sold = 0 THEN i.cost ELSE 0 END) AS unsold_cost_value
FROM dw.fact_inventory i
JOIN dw.dim_distribution_centers dc ON dc.distribution_center_key = i.distribution_center_key
GROUP BY dc.distribution_center_name
ORDER BY unsold_cost_value DESC;

/* E. Slow movers: top 3 products per department by unsold stock value */
WITH prod AS (
  SELECT p.department, p.product_key, p.product_name, p.brand, p.category,
         COUNT(*) AS items_received, SUM(i.is_sold) AS items_sold,
         SUM(CASE WHEN i.is_sold = 0 THEN i.cost ELSE 0 END) AS unsold_cost_value
  FROM dw.fact_inventory i
  JOIN dw.dim_products p ON p.product_key = i.product_key
  GROUP BY p.department, p.product_key, p.product_name, p.brand, p.category
),
ranked AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY department ORDER BY unsold_cost_value DESC) AS rn
  FROM prod
)
SELECT department, product_name, brand, category, items_received, items_sold,
       items_sold * 1.0 / items_received AS sell_through_pct, unsold_cost_value
FROM ranked
WHERE rn <= 3
ORDER BY department, rn;

/* F. Dead stock: unsold items older than 2 years, by department */
SELECT p.department, COUNT(*) AS items, SUM(i.cost) AS cost_value
FROM dw.fact_inventory i
JOIN dw.dim_products p ON p.product_key = i.product_key
WHERE i.is_sold = 0 AND i.aging_bucket = 'Over 2 years'
GROUP BY p.department;

/* G. Net sell-through: sold and neither cancelled nor returned (ROLLUP row with NULL department is the total) */
SELECT p.department,
       COUNT(*) AS items_received,
       SUM(i.is_sold) * 1.0 / COUNT(*) AS gross_sell_through_pct,
       SUM(CASE WHEN f.order_item_id IS NOT NULL AND f.is_cancelled = 0 AND f.is_returned = 0 THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS net_sell_through_pct
FROM dw.fact_inventory i
JOIN dw.dim_products p ON p.product_key = i.product_key
LEFT JOIN dw.fact_order_items f ON f.sold_inventory_item_key = i.inventory_item_id
GROUP BY ROLLUP (p.department);
