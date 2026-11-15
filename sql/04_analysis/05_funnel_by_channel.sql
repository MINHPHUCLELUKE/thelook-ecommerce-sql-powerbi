/* =====================================================================
   4.5 Funnel conversion by traffic source
   Business question: which channels bring sessions that reach the cart and buy?
   Caveats (see data_quality_report findings 6, 11, 12):
   - Web sessions use the session channel (Adwords, YouTube, Facebook, Email, Organic).
   - Anonymous sessions never purchase in this dataset, so purchase rate mainly reflects the logged-in share.
   - Revenue by channel uses the customer acquisition channel from dim_users, not the session channel.
   Techniques: CROSS APPLY (VALUES) unpivot, LAG, FIRST_VALUE, conditional aggregation.
   ===================================================================== */

/* A. Funnel stages per channel with step conversion */
WITH w AS (
  SELECT traffic_source,
         COUNT(*) AS s0, SUM(has_product) AS s1, SUM(has_cart) AS s2, SUM(has_purchase) AS s3
  FROM dw.fact_web_sessions GROUP BY traffic_source
),
stages AS (
  SELECT w.traffic_source, v.stage_no, v.stage, v.sessions
  FROM w CROSS APPLY (VALUES (0, 'All sessions', w.s0), (1, 'Product view', w.s1),
                             (2, 'Cart', w.s2), (3, 'Purchase', w.s3)) v(stage_no, stage, sessions)
)
SELECT traffic_source, stage_no, stage, sessions,
       sessions * 1.0 / FIRST_VALUE(sessions) OVER (PARTITION BY traffic_source ORDER BY stage_no) AS pct_of_all_sessions,
       sessions * 1.0 / NULLIF(LAG(sessions) OVER (PARTITION BY traffic_source ORDER BY stage_no), 0) AS step_conversion
FROM stages
ORDER BY traffic_source, stage_no;

/* B. Session outcome mix by channel */
SELECT traffic_source, session_outcome, COUNT(*) AS sessions,
       COUNT(*) * 1.0 / SUM(COUNT(*)) OVER (PARTITION BY traffic_source) AS share_of_channel
FROM dw.fact_web_sessions
GROUP BY traffic_source, session_outcome
ORDER BY traffic_source, sessions DESC;

/* C. Logged-in versus anonymous sessions by channel */
SELECT traffic_source,
       COUNT(*) AS sessions,
       SUM(CASE WHEN is_anonymous = 0 THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS logged_in_share,
       SUM(has_purchase) * 1.0 / COUNT(*)                                  AS purchase_rate,
       SUM(has_cart) * 1.0 / COUNT(*)                                      AS cart_rate
FROM dw.fact_web_sessions
GROUP BY traffic_source
ORDER BY sessions DESC;

/* D. Yearly sessions and purchase rate by channel */
SELECT d.year_no, s.traffic_source, COUNT(*) AS sessions,
       SUM(s.has_purchase) * 1.0 / COUNT(*) AS purchase_rate
FROM dw.fact_web_sessions s
JOIN dw.dim_date d ON d.date_key = s.session_date_key
GROUP BY d.year_no, s.traffic_source
ORDER BY d.year_no, s.traffic_source;

/* E. Revenue by customer acquisition channel (dim_users.acquisition_channel) */
SELECT u.acquisition_channel,
       COUNT(DISTINCT CASE WHEN f.is_cancelled = 0 THEN f.user_key END) AS buying_customers,
       COUNT(DISTINCT CASE WHEN f.is_cancelled = 0 THEN f.order_id END) AS orders,
       SUM(f.net_revenue) AS net_revenue,
       SUM(f.net_revenue) * 1.0 / SUM(SUM(f.net_revenue)) OVER () AS share_of_net_revenue,
       SUM(f.net_revenue) / NULLIF(COUNT(DISTINCT CASE WHEN f.is_cancelled = 0 THEN f.user_key END), 0) AS net_revenue_per_customer,
       SUM(f.net_profit) / NULLIF(SUM(f.net_revenue), 0) AS net_margin_pct,
       SUM(f.is_returned) * 1.0 / NULLIF(SUM(CASE WHEN f.is_cancelled = 0 THEN 1 ELSE 0 END), 0) AS return_rate
FROM dw.fact_order_items f
JOIN dw.dim_users u ON u.user_key = f.user_key
GROUP BY u.acquisition_channel
ORDER BY net_revenue DESC;
