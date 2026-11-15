/* =====================================================================
   4.4 RFM segmentation
   Business question: who are the best customers, and who is slipping away?
   Recency: days since last non-cancelled order (as of the last order in the data).
   Frequency: number of orders (capped at 5 for scoring). Monetary: net revenue.
   Techniques: NTILE, CASE segmentation, nested window aggregates, reusable view.
   ===================================================================== */

CREATE OR ALTER VIEW dw.vw_customer_rfm AS
WITH asof AS (
  SELECT MAX(created_at) AS as_of FROM dw.fact_order_items
),
cust AS (
  SELECT f.user_key,
         MAX(f.created_at)            AS last_order_at,
         COUNT(DISTINCT f.order_id)   AS frequency,
         SUM(f.net_revenue)           AS monetary
  FROM dw.fact_order_items f
  WHERE f.is_cancelled = 0
  GROUP BY f.user_key
),
scored AS (
  SELECT c.user_key, c.last_order_at, c.frequency, c.monetary,
         DATEDIFF(DAY, c.last_order_at, a.as_of) AS recency_days,
         NTILE(5) OVER (ORDER BY DATEDIFF(DAY, c.last_order_at, a.as_of) DESC) AS r_score,  -- 5 = most recent
         CASE WHEN c.frequency >= 5 THEN 5 ELSE c.frequency END AS f_score,
         NTILE(5) OVER (ORDER BY c.monetary) AS m_score                                       -- 5 = highest spend
  FROM cust c CROSS JOIN asof a
)
SELECT s.*,
       CASE WHEN r_score >= 4 AND f_score >= 4 THEN 'Champions'
            WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal'
            WHEN r_score >= 4 AND f_score <= 2 THEN 'New or recent'
            WHEN r_score <= 2 AND f_score >= 3 THEN 'At risk'
            WHEN r_score <= 2 AND f_score <= 2 THEN 'Lost'
            ELSE 'Needs attention' END AS segment
FROM scored s;
GO

/* A. Segment summary */
SELECT segment,
       COUNT(*) AS customers,
       COUNT(*) * 1.0 / SUM(COUNT(*)) OVER ()            AS pct_of_customers,
       SUM(monetary)                                      AS net_revenue,
       SUM(monetary) / SUM(SUM(monetary)) OVER ()         AS pct_of_revenue,
       AVG(frequency * 1.0)                               AS avg_orders,
       AVG(recency_days * 1.0)                            AS avg_recency_days,
       AVG(monetary)                                      AS avg_net_spend
FROM dw.vw_customer_rfm
GROUP BY segment
ORDER BY net_revenue DESC;

/* B. Score distribution (check the buckets are sensible) */
SELECT f_score, COUNT(*) AS customers, MIN(recency_days) AS min_recency, MAX(recency_days) AS max_recency
FROM dw.vw_customer_rfm GROUP BY f_score ORDER BY f_score;

/* C. Top 20 customers by net spend, with segment */
SELECT TOP 20 r.user_key, u.country, u.age_group, r.frequency, r.monetary, r.recency_days, r.segment
FROM dw.vw_customer_rfm r
JOIN dw.dim_users u ON u.user_key = r.user_key
ORDER BY r.monetary DESC;

/* D. Segment by country (top 6 countries by customers) */
WITH top_c AS (SELECT TOP 6 u.country FROM dw.vw_customer_rfm r JOIN dw.dim_users u ON u.user_key = r.user_key GROUP BY u.country ORDER BY COUNT(*) DESC)
SELECT u.country, r.segment, COUNT(*) AS customers,
       COUNT(*) * 1.0 / SUM(COUNT(*)) OVER (PARTITION BY u.country) AS share_in_country
FROM dw.vw_customer_rfm r
JOIN dw.dim_users u ON u.user_key = r.user_key
WHERE u.country IN (SELECT country FROM top_c)
GROUP BY u.country, r.segment
ORDER BY u.country, customers DESC;
