/* =====================================================================
   4.8 Reusable views and a stored procedure
   Views give Power BI and analysts one tested definition of each metric.
   dw.usp_kpi_summary compares any date range with the equal-length period before it.
   Run this file once; then call:
     EXEC dw.usp_kpi_summary '2024-01-01', '2024-05-13';
     EXEC dw.usp_kpi_summary '2023-01-01', '2023-05-13', 'Women';
   ===================================================================== */

CREATE OR ALTER VIEW dw.vw_monthly_kpis AS
SELECT d.year_no, d.month_no, d.year_month,
       SUM(f.gross_revenue) AS gross_revenue,
       SUM(f.net_revenue)   AS net_revenue,
       SUM(f.net_profit)    AS net_profit,
       SUM(f.net_profit) / NULLIF(SUM(f.net_revenue), 0) AS net_margin_pct,
       COUNT(DISTINCT CASE WHEN f.is_cancelled = 0 THEN f.order_id END) AS orders,
       SUM(f.is_returned) * 1.0 / NULLIF(SUM(CASE WHEN f.is_cancelled = 0 THEN 1 ELSE 0 END), 0) AS return_rate,
       SUM(f.is_cancelled) * 1.0 / COUNT(*) AS cancel_rate
FROM dw.fact_order_items f
JOIN dw.dim_date d ON d.date_key = f.created_date_key
GROUP BY d.year_no, d.month_no, d.year_month;
GO

CREATE OR ALTER VIEW dw.vw_product_performance AS
WITH sales AS (
  SELECT f.product_key,
         SUM(CASE WHEN f.is_cancelled = 0 THEN 1 ELSE 0 END) AS items_sold,
         SUM(f.net_revenue) AS net_revenue,
         SUM(f.net_profit)  AS net_profit,
         SUM(f.is_returned) AS items_returned
  FROM dw.fact_order_items f GROUP BY f.product_key
),
stock AS (
  SELECT i.product_key,
         COUNT(*) AS items_received,
         SUM(CASE WHEN i.is_sold = 0 THEN 1 ELSE 0 END) AS unsold_items,
         SUM(CASE WHEN i.is_sold = 0 THEN i.cost ELSE 0 END) AS unsold_cost_value
  FROM dw.fact_inventory i GROUP BY i.product_key
)
SELECT p.product_key, p.product_name, p.brand, p.category, p.department, p.price_band,
       COALESCE(s.items_sold, 0) AS items_sold,
       COALESCE(s.net_revenue, 0) AS net_revenue,
       COALESCE(s.net_profit, 0)  AS net_profit,
       s.items_returned * 1.0 / NULLIF(s.items_sold, 0) AS return_rate,
       COALESCE(k.items_received, 0) AS items_received,
       COALESCE(k.unsold_items, 0)   AS unsold_items,
       COALESCE(k.unsold_cost_value, 0) AS unsold_cost_value
FROM dw.dim_products p
LEFT JOIN sales s ON s.product_key = p.product_key
LEFT JOIN stock k ON k.product_key = p.product_key;
GO

CREATE OR ALTER PROCEDURE dw.usp_kpi_summary
  @start_date date,
  @end_date   date,
  @department nvarchar(20) = NULL
AS
BEGIN
  SET NOCOUNT ON;
  DECLARE @days int = DATEDIFF(DAY, @start_date, @end_date) + 1;
  DECLARE @prev_start date = DATEADD(DAY, -@days, @start_date);
  DECLARE @prev_end   date = DATEADD(DAY, -1, @start_date);

  WITH base AS (
    SELECT CASE WHEN d.full_date BETWEEN @start_date AND @end_date THEN 'Current' ELSE 'Previous' END AS period,
           f.order_id, f.is_cancelled, f.is_returned, f.gross_revenue, f.net_revenue, f.net_profit
    FROM dw.fact_order_items f
    JOIN dw.dim_date d     ON d.date_key = f.created_date_key
    JOIN dw.dim_products p ON p.product_key = f.product_key
    WHERE (d.full_date BETWEEN @start_date AND @end_date OR d.full_date BETWEEN @prev_start AND @prev_end)
      AND (@department IS NULL OR p.department = @department)
  ),
  kpi AS (
    SELECT period,
           SUM(gross_revenue) AS gross_revenue,
           SUM(net_revenue)   AS net_revenue,
           SUM(net_profit)    AS net_profit,
           SUM(net_profit) / NULLIF(SUM(net_revenue), 0) AS net_margin_pct,
           COUNT(DISTINCT CASE WHEN is_cancelled = 0 THEN order_id END) AS orders,
           SUM(gross_revenue) / NULLIF(COUNT(DISTINCT CASE WHEN is_cancelled = 0 THEN order_id END), 0) AS avg_order_value,
           SUM(is_returned) * 1.0 / NULLIF(SUM(CASE WHEN is_cancelled = 0 THEN 1 ELSE 0 END), 0) AS return_rate,
           SUM(is_cancelled) * 1.0 / NULLIF(COUNT(*), 0) AS cancel_rate
    FROM base GROUP BY period
  ),
  pair AS (
    SELECT c.gross_revenue AS c_gross, p.gross_revenue AS p_gross,
           c.net_revenue AS c_net, p.net_revenue AS p_net,
           c.net_profit AS c_profit, p.net_profit AS p_profit,
           c.net_margin_pct AS c_margin, p.net_margin_pct AS p_margin,
           c.orders AS c_orders, p.orders AS p_orders,
           c.avg_order_value AS c_aov, p.avg_order_value AS p_aov,
           c.return_rate AS c_ret, p.return_rate AS p_ret,
           c.cancel_rate AS c_can, p.cancel_rate AS p_can
    FROM kpi c CROSS JOIN kpi p
    WHERE c.period = 'Current' AND p.period = 'Previous'
  )
  SELECT kpi, current_value, previous_value,
         (current_value - previous_value) / NULLIF(previous_value, 0) AS pct_change
  FROM pair
  CROSS APPLY (VALUES
     ('Gross revenue',   c_gross,  p_gross),
     ('Net revenue',     c_net,    p_net),
     ('Net profit',      c_profit, p_profit),
     ('Net margin',      c_margin, p_margin),
     ('Orders',          CAST(c_orders AS float), CAST(p_orders AS float)),
     ('Average order value', c_aov, p_aov),
     ('Return rate',     c_ret,    p_ret),
     ('Cancel rate',     c_can,    p_can)
  ) v(kpi, current_value, previous_value);
END;
GO

/* Example calls */
EXEC dw.usp_kpi_summary '2024-01-01', '2024-05-13';
EXEC dw.usp_kpi_summary '2023-01-01', '2023-05-13', 'Women';
