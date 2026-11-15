/* =====================================================================
   4.2 Return rate by category and brand
   Business question: where do returns come from, and what do they cost?
   Return rate = returned items / items not cancelled.
   Techniques: CTE, RANK, conditional aggregation, HAVING for minimum volume.
   ===================================================================== */

/* A. Category ranking */
WITH c AS (
  SELECT p.department, p.category,
         SUM(CASE WHEN f.is_cancelled = 0 THEN 1 ELSE 0 END) AS items_sold,
         SUM(f.is_returned)       AS items_returned,
         SUM(f.returned_revenue)  AS returned_revenue,
         SUM(f.gross_profit) - SUM(f.net_profit) AS profit_lost_to_returns
  FROM dw.fact_order_items f
  JOIN dw.dim_products p ON p.product_key = f.product_key
  GROUP BY p.department, p.category
)
SELECT department, category, items_sold, items_returned,
       items_returned * 1.0 / NULLIF(items_sold, 0) AS return_rate,
       returned_revenue, profit_lost_to_returns,
       RANK() OVER (ORDER BY items_returned * 1.0 / NULLIF(items_sold, 0) DESC) AS rate_rank,
       RANK() OVER (ORDER BY profit_lost_to_returns DESC) AS cost_rank
FROM c
ORDER BY return_rate DESC;

/* B. Brands with at least 500 items sold (small brands are too noisy) */
WITH b AS (
  SELECT p.brand,
         SUM(CASE WHEN f.is_cancelled = 0 THEN 1 ELSE 0 END) AS items_sold,
         SUM(f.is_returned) AS items_returned,
         SUM(f.returned_revenue) AS returned_revenue
  FROM dw.fact_order_items f
  JOIN dw.dim_products p ON p.product_key = f.product_key
  GROUP BY p.brand
  HAVING SUM(CASE WHEN f.is_cancelled = 0 THEN 1 ELSE 0 END) >= 500
)
SELECT TOP 20 brand, items_sold, items_returned,
       items_returned * 1.0 / items_sold AS return_rate,
       returned_revenue
FROM b
ORDER BY return_rate DESC;

/* C. Return rate by department and price band */
SELECT p.department, p.price_band,
       SUM(CASE WHEN f.is_cancelled = 0 THEN 1 ELSE 0 END) AS items_sold,
       SUM(f.is_returned) * 1.0 / NULLIF(SUM(CASE WHEN f.is_cancelled = 0 THEN 1 ELSE 0 END), 0) AS return_rate
FROM dw.fact_order_items f
JOIN dw.dim_products p ON p.product_key = f.product_key
GROUP BY p.department, p.price_band
ORDER BY p.department, MIN(p.retail_price);

/* D. Return rate by year (returns are attributed to the order date) */
SELECT d.year_no,
       SUM(CASE WHEN f.is_cancelled = 0 THEN 1 ELSE 0 END) AS items_sold,
       SUM(f.is_returned) * 1.0 / NULLIF(SUM(CASE WHEN f.is_cancelled = 0 THEN 1 ELSE 0 END), 0) AS return_rate
FROM dw.fact_order_items f
JOIN dw.dim_date d ON d.date_key = f.created_date_key
GROUP BY d.year_no
ORDER BY d.year_no;

/* E. Days from delivery to return, by department (valid timelines only) */
SELECT p.department, COUNT(*) AS returned_items,
       AVG(DATEDIFF(HOUR, f.delivered_at, f.returned_at) / 24.0) AS avg_days_to_return
FROM dw.fact_order_items f
JOIN dw.dim_products p ON p.product_key = f.product_key
WHERE f.is_returned = 1 AND f.is_timeline_invalid = 0
GROUP BY p.department;
