/* =====================================================================
   4.6 Fulfilment time by distribution center
   Business question: which centers ship and deliver fastest, and where do shipments get stuck?
   Only rows with a valid timeline are used (35,440 rows are excluded, see finding 3).
   Techniques: PERCENTILE_CONT as a window function, conditional SLA share, CTE.
   ===================================================================== */

/* A. Delivery performance by center (delivered items with valid timelines) */
SELECT DISTINCT
       dc.distribution_center_name,
       COUNT(*) OVER (PARTITION BY f.distribution_center_key)                          AS delivered_items,
       AVG(f.days_to_ship)       OVER (PARTITION BY f.distribution_center_key)         AS avg_days_to_ship,
       AVG(f.days_in_transit)    OVER (PARTITION BY f.distribution_center_key)         AS avg_days_in_transit,
       AVG(f.days_to_deliver)    OVER (PARTITION BY f.distribution_center_key)         AS avg_days_to_deliver,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY f.days_to_deliver) OVER (PARTITION BY f.distribution_center_key) AS median_days_to_deliver,
       PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY f.days_to_deliver) OVER (PARTITION BY f.distribution_center_key) AS p90_days_to_deliver,
       AVG(CASE WHEN f.days_to_deliver <= 5 THEN 1.0 ELSE 0.0 END) OVER (PARTITION BY f.distribution_center_key) AS pct_delivered_within_5_days
FROM dw.fact_order_items f
JOIN dw.dim_distribution_centers dc ON dc.distribution_center_key = f.distribution_center_key
WHERE f.is_timeline_invalid = 0 AND f.delivered_at IS NOT NULL
ORDER BY avg_days_to_deliver;

/* B. Yearly trend of average days to deliver */
SELECT d.year_no, COUNT(*) AS delivered_items,
       AVG(f.days_to_ship) AS avg_days_to_ship,
       AVG(f.days_in_transit) AS avg_days_in_transit,
       AVG(f.days_to_deliver) AS avg_days_to_deliver
FROM dw.fact_order_items f
JOIN dw.dim_date d ON d.date_key = f.created_date_key
WHERE f.is_timeline_invalid = 0 AND f.delivered_at IS NOT NULL
GROUP BY d.year_no
ORDER BY d.year_no;

/* C. Shipped but not delivered, older than 14 days (possible stuck shipments) */
WITH asof AS (SELECT MAX(created_at) AS as_of FROM dw.fact_order_items)
SELECT dc.distribution_center_name,
       SUM(CASE WHEN f.status = 'Shipped' THEN 1 ELSE 0 END) AS shipped_not_delivered,
       SUM(CASE WHEN f.status = 'Shipped' AND f.shipped_at < DATEADD(DAY, -14, a.as_of) THEN 1 ELSE 0 END) AS older_than_14_days,
       SUM(CASE WHEN f.status = 'Shipped' AND f.shipped_at < DATEADD(DAY, -14, a.as_of) THEN f.sale_price ELSE 0 END) AS value_older_than_14_days
FROM dw.fact_order_items f
JOIN dw.dim_distribution_centers dc ON dc.distribution_center_key = f.distribution_center_key
CROSS JOIN asof a
WHERE f.is_timeline_invalid = 0
GROUP BY dc.distribution_center_name
ORDER BY older_than_14_days DESC;

/* D. Return and cancellation rates by center, plus share of rows with invalid timelines */
SELECT dc.distribution_center_name,
       COUNT(*) AS items,
       SUM(f.is_cancelled) * 1.0 / COUNT(*) AS cancel_rate,
       SUM(f.is_returned) * 1.0 / NULLIF(SUM(CASE WHEN f.is_cancelled = 0 THEN 1 ELSE 0 END), 0) AS return_rate,
       SUM(CASE WHEN f.shipped_at IS NOT NULL THEN f.is_timeline_invalid ELSE 0 END) * 1.0
         / NULLIF(SUM(CASE WHEN f.shipped_at IS NOT NULL THEN 1 ELSE 0 END), 0) AS invalid_timeline_share
FROM dw.fact_order_items f
JOIN dw.dim_distribution_centers dc ON dc.distribution_center_key = f.distribution_center_key
GROUP BY dc.distribution_center_name
ORDER BY items DESC;
