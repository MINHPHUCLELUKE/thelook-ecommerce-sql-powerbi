# SQL scripts

T-SQL for SQL Server (developed on SQL Server Express with SSMS). The scripts build a clean layer, a star schema and the analysis queries behind the Power BI report.

## Layers
| Schema | Purpose |
|---|---|
| `dbo` | Raw tables as imported: `distribution_centers`, `users`, `products`, `inventory_events`, `orders`, `order_items`, `events` |
| `clean` | Typed, keyed and flagged copy of the raw tables |
| `dw` | Star schema used by Power BI (3 fact tables, 5 dimensions, 4 views, 1 stored procedure) |

The raw data is not included in this repository (the backup is about 1 GB). The main README explains how the project is reproduced. The columns each `dbo` table must provide can be read from the `SELECT` lists in `01_clean_layer.sql`.

## Run order
| Step | File | What it does | Notes |
|---|---|---|---|
| 1 | `01_clean_layer.sql` | Converts text dates to `datetime2`, standardizes country names, adds keys and the `is_timeline_invalid` flag | Safe to re-run |
| 2 | `02_profile.sql` | Profiling queries (nulls, duplicates, ranges) | Read-only; feeds `docs/data_quality_report.md` |
| 3 | `02b_diagnostics.sql` | Follow-up checks on web sessions, purchase events and the inventory link | Read-only |
| 4 | `03_star_schema.sql` | Builds the `dw` dimensions and facts | Safe to re-run (drops and recreates `dw` tables) |
| 5 | `03b_reconciliation.sql` | Compares totals between `clean` and `dw`; every row should say PASS | Read-only |
| 6 | `04_analysis/01` to `08` | Analysis queries (see below). `04_rfm_segmentation.sql` creates `dw.vw_customer_rfm`; `08_views_and_procedure.sql` creates the reporting views and `dw.usp_kpi_summary` | Run the whole file for 04 and 08; the other files hold separate queries (A, B, C ...) you can run one at a time |
| 7 | `09_powerbi_views.sql` | Creates `dw.vw_cohort_retention` for the retention heatmap | Run before loading Power BI |

## Expected row counts
| Table | Rows |
|---|---|
| dw.dim_date | 2,557 |
| dw.dim_users | 100,000 |
| dw.dim_products | 29,120 |
| dw.dim_distribution_centers | 10 |
| dw.dim_status | 5 |
| dw.fact_order_items | 180,862 |
| dw.fact_inventory | 488,146 |
| dw.fact_web_sessions | 680,862 |
| dw.vw_customer_rfm | 72,096 |
| dw.vw_cohort_retention | 754 |

## Analysis queries
| File | Business question | Techniques |
|---|---|---|
| `04_analysis/01_revenue_profit_trends.sql` | How are sales, profit and margin trending, and is 2024 on track? | CTE, `LAG`, moving average, running total |
| `04_analysis/02_returns.sql` | Where do returns come from and what do they cost? | CTE, `RANK`, conditional aggregation |
| `04_analysis/03_cohort_retention.sql` | Of customers who first bought in a month, how many come back? | Multi-step CTEs, `DATEDIFF` month index |
| `04_analysis/04_rfm_segmentation.sql` | Who are the best customers and who is slipping away? | `NTILE`, `CASE` segmentation, reusable view |
| `04_analysis/05_funnel_by_channel.sql` | Which channels reach the cart and buy? | `CROSS APPLY (VALUES)`, `FIRST_VALUE` |
| `04_analysis/06_fulfilment_by_dc.sql` | Which centers ship fastest and where do shipments get stuck? | `PERCENTILE_CONT`, SLA share |
| `04_analysis/07_inventory_aging_sellthrough.sql` | How much stock is unsold, how old and what is it worth? | Conditional aggregation, `RANK` per group |
| `04_analysis/08_views_and_procedure.sql` | One tested definition of each metric | Views, stored procedure |

## Definitions used throughout
- **Gross revenue:** all order items except Cancelled.
- **Net revenue:** all order items except Cancelled and Returned.
- **Like-for-like window:** 1 January to 13 May of each year (`dw.dim_date.is_ytd_window`), because the data ends on 13 May 2024.
- **Timeline flag:** `is_timeline_invalid = 1` when a ship, delivery or return time is earlier than the previous stage (35,440 rows, 19.6%). These rows stay in revenue and returns but are excluded from delivery-time metrics.
