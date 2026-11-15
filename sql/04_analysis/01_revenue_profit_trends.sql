/* =====================================================================
   4.1 Revenue and profit trends
   Business question: how are sales, profit and margin trending, and is 2024 on track?
   Techniques: CTE, LAG (growth), moving average and running total (window frames).
   Note: 2024 stops on 13 May. Year-over-year uses the same Jan 1 to May 13 window (dim_date.is_ytd_window).
   ===================================================================== */

/* A. Monthly KPIs with growth, 3 month average and year-to-date total */
WITH monthly AS (
  SELECT d.year_no, d.month_no, d.year_month,
         SUM(f.gross_revenue) AS gross_revenue,
         SUM(f.net_revenue)   AS net_revenue,
         SUM(f.net_profit)    AS net_profit,
         COUNT(DISTINCT CASE WHEN f.is_cancelled = 0 THEN f.order_id END) AS orders
  FROM dw.fact_order_items f
  JOIN dw.dim_date d ON d.date_key = f.created_date_key
  GROUP BY d.year_no, d.month_no, d.year_month
)
SELECT year_month, gross_revenue, net_revenue, net_profit,
       net_profit / NULLIF(net_revenue, 0)                         AS net_margin_pct,
       orders,
       gross_revenue / NULLIF(orders, 0)                           AS avg_order_value,
       net_revenue / NULLIF(LAG(net_revenue) OVER (ORDER BY year_month), 0) - 1 AS mom_growth_pct,
       AVG(net_revenue) OVER (ORDER BY year_month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS net_revenue_3m_avg,
       SUM(net_revenue) OVER (PARTITION BY year_no ORDER BY month_no) AS net_revenue_ytd,
       CASE WHEN year_month = '2024-05' THEN 1 ELSE 0 END           AS is_partial_month
FROM monthly
ORDER BY year_month;

/* B. Like-for-like year over year (Jan 1 to May 13 of every year) */
WITH ytd AS (
  SELECT d.year_no,
         SUM(f.gross_revenue) AS gross_revenue,
         SUM(f.net_revenue)   AS net_revenue,
         SUM(f.net_profit)    AS net_profit,
         COUNT(DISTINCT CASE WHEN f.is_cancelled = 0 THEN f.order_id END) AS orders
  FROM dw.fact_order_items f
  JOIN dw.dim_date d ON d.date_key = f.created_date_key
  WHERE d.is_ytd_window = 1
  GROUP BY d.year_no
)
SELECT year_no, gross_revenue, net_revenue, net_profit,
       net_profit / NULLIF(net_revenue, 0) AS net_margin_pct, orders,
       net_revenue / NULLIF(LAG(net_revenue) OVER (ORDER BY year_no), 0) - 1 AS yoy_net_revenue_pct,
       orders * 1.0 / NULLIF(LAG(orders) OVER (ORDER BY year_no), 0) - 1       AS yoy_orders_pct
FROM ytd
ORDER BY year_no;

/* C. Full calendar years (2019 to 2023 are complete) */
WITH yr AS (
  SELECT d.year_no,
         SUM(f.net_revenue) AS net_revenue, SUM(f.net_profit) AS net_profit,
         COUNT(DISTINCT CASE WHEN f.is_cancelled = 0 THEN f.order_id END) AS orders
  FROM dw.fact_order_items f
  JOIN dw.dim_date d ON d.date_key = f.created_date_key
  WHERE d.year_no < 2024
  GROUP BY d.year_no
)
SELECT year_no, net_revenue, net_profit, net_profit / NULLIF(net_revenue, 0) AS net_margin_pct, orders,
       net_revenue / NULLIF(LAG(net_revenue) OVER (ORDER BY year_no), 0) - 1 AS yoy_net_revenue_pct
FROM yr
ORDER BY year_no;

/* D. Department mix by year, with each department's share of the year */
SELECT d.year_no, p.department,
       SUM(f.net_revenue) AS net_revenue,
       SUM(f.net_revenue) * 1.0 / SUM(SUM(f.net_revenue)) OVER (PARTITION BY d.year_no) AS share_of_year,
       SUM(f.net_profit)  / NULLIF(SUM(f.net_revenue), 0) AS net_margin_pct
FROM dw.fact_order_items f
JOIN dw.dim_date d     ON d.date_key = f.created_date_key
JOIN dw.dim_products p ON p.product_key = f.product_key
GROUP BY d.year_no, p.department
ORDER BY d.year_no, p.department;

/* E. Top 10 categories by net profit (all time) */
SELECT TOP 10 p.category,
       SUM(f.net_revenue) AS net_revenue, SUM(f.net_profit) AS net_profit,
       SUM(f.net_profit) / NULLIF(SUM(f.net_revenue), 0) AS net_margin_pct,
       SUM(f.net_profit) * 1.0 / SUM(SUM(f.net_profit)) OVER () AS share_of_profit
FROM dw.fact_order_items f
JOIN dw.dim_products p ON p.product_key = f.product_key
GROUP BY p.category
ORDER BY net_profit DESC;
