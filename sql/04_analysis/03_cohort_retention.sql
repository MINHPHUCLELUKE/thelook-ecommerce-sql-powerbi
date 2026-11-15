/* =====================================================================
   4.3 Customer cohort retention
   Business question: of the customers who first bought in a given month, how many come back?
   Cohort = month of first non-cancelled order. Returned orders still count as orders.
   Techniques: multi-step CTEs, DATEFROMPARTS, DATEDIFF month index, window functions.
   ===================================================================== */

/* A. Monthly cohort retention, months 0 to 12 (long format).
      Note: the inner join drops zero-activity cells and the partial May 2024 month is included.
      The complete grid used by Power BI is dw.vw_cohort_retention (sql/09_powerbi_views.sql). */
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
)
SELECT fo.cohort_month,
       DATEDIFF(MONTH, fo.cohort_month, a.activity_month) AS month_index,
       cs.cohort_customers,
       COUNT(DISTINCT a.user_key) AS active_customers,
       COUNT(DISTINCT a.user_key) * 1.0 / cs.cohort_customers AS retention_pct
FROM first_order fo
JOIN activity a     ON a.user_key = fo.user_key
JOIN cohort_size cs ON cs.cohort_month = fo.cohort_month
WHERE DATEDIFF(MONTH, fo.cohort_month, a.activity_month) BETWEEN 0 AND 12
GROUP BY fo.cohort_month, DATEDIFF(MONTH, fo.cohort_month, a.activity_month), cs.cohort_customers
ORDER BY fo.cohort_month, month_index;

/* B. Repeat purchase rate by cohort year */
WITH o AS (
  SELECT f.user_key, f.order_id, MIN(f.created_at) AS order_at
  FROM dw.fact_order_items f WHERE f.is_cancelled = 0
  GROUP BY f.user_key, f.order_id
),
per_user AS (
  SELECT user_key, COUNT(*) AS orders, MIN(order_at) AS first_order_at FROM o GROUP BY user_key
)
SELECT YEAR(first_order_at) AS cohort_year,
       COUNT(*) AS customers,
       SUM(CASE WHEN orders >= 2 THEN 1 ELSE 0 END) AS repeat_customers,
       SUM(CASE WHEN orders >= 2 THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS repeat_rate,
       AVG(orders * 1.0) AS avg_orders_per_customer
FROM per_user
GROUP BY YEAR(first_order_at)
ORDER BY cohort_year;

/* C. Orders per customer distribution */
WITH o AS (
  SELECT f.user_key, COUNT(DISTINCT f.order_id) AS orders
  FROM dw.fact_order_items f WHERE f.is_cancelled = 0 GROUP BY f.user_key
)
SELECT CASE WHEN orders >= 5 THEN '5+' ELSE CAST(orders AS varchar(2)) END AS orders_bucket,
       COUNT(*) AS customers,
       COUNT(*) * 1.0 / SUM(COUNT(*)) OVER () AS share
FROM o
GROUP BY CASE WHEN orders >= 5 THEN '5+' ELSE CAST(orders AS varchar(2)) END
ORDER BY orders_bucket;

/* D. How many registered users never ordered? */
SELECT COUNT(*) AS users,
       SUM(x.never_ordered) AS never_ordered,
       SUM(x.never_ordered) * 1.0 / COUNT(*) AS never_ordered_pct
FROM (
  SELECT CASE WHEN NOT EXISTS (SELECT 1 FROM dw.fact_order_items f
                               WHERE f.user_key = u.user_key AND f.is_cancelled = 0)
              THEN 1 ELSE 0 END AS never_ordered
  FROM dw.dim_users u
) x;
