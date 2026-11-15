/* =====================================================================
   TheLook E-commerce | 09 Views for Power BI
   dw.vw_cohort_retention: complete cohort grid (months 0 to 12) so Power BI can average correctly.
   - Zero-activity cells are included (a plain inner join would drop them and overstate retention).
   - Cells that fall in May 2024 (partial month) or later are excluded.
   dw.vw_customer_rfm is created in 04_analysis/04_rfm_segmentation.sql.
   ===================================================================== */

CREATE OR ALTER VIEW dw.vw_cohort_retention AS
WITH o AS (
  SELECT f.user_key, f.order_id, MIN(f.created_at) AS order_at
  FROM dw.fact_order_items f
  WHERE f.is_cancelled = 0
  GROUP BY f.user_key, f.order_id
),
first_order AS (
  SELECT user_key, DATEFROMPARTS(YEAR(MIN(order_at)), MONTH(MIN(order_at)), 1) AS cohort_month
  FROM o GROUP BY user_key
),
activity AS (
  SELECT DISTINCT user_key, DATEFROMPARTS(YEAR(order_at), MONTH(order_at), 1) AS activity_month
  FROM o
),
cohort_size AS (
  SELECT cohort_month, COUNT(*) AS cohort_customers FROM first_order GROUP BY cohort_month
),
idx AS (
  SELECT n FROM (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),(12)) v(n)
),
grid AS (
  SELECT cs.cohort_month, i.n AS month_index, cs.cohort_customers
  FROM cohort_size cs CROSS JOIN idx i
  WHERE DATEADD(MONTH, i.n, cs.cohort_month) <= '2024-04-01'
),
act AS (
  SELECT fo.cohort_month,
         DATEDIFF(MONTH, fo.cohort_month, a.activity_month) AS month_index,
         COUNT(DISTINCT a.user_key) AS active_customers
  FROM first_order fo
  JOIN activity a ON a.user_key = fo.user_key
  GROUP BY fo.cohort_month, DATEDIFF(MONTH, fo.cohort_month, a.activity_month)
)
SELECT g.cohort_month, g.month_index, g.cohort_customers,
       COALESCE(a.active_customers, 0) AS active_customers
FROM grid g
LEFT JOIN act a ON a.cohort_month = g.cohort_month AND a.month_index = g.month_index;
GO

SELECT COUNT(*) AS cells, MIN(cohort_month) AS first_cohort, MAX(cohort_month) AS last_cohort FROM dw.vw_cohort_retention;
