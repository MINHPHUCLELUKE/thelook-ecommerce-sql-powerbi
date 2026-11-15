# Power BI Data Model | The Look Co.

Import mode. 14 tables, 15 relationships, 74 measures. The finished report is `The_Look_Ecommerce.pbix`; this file documents how the model is built so it can be rebuilt or audited. The diagram is in `docs/erd.png`.

## 1. Source and load
Connect to any SQL Server instance that holds the `dw` schema built by `sql/` (database `The_Look_Ecommerce`). Load these 10 objects with Get Data, SQL Server, Import, and rename each to drop the `dw ` prefix.

| Object | Role |
|---|---|
| dw.dim_date | Date table |
| dw.dim_users | Customers |
| dw.dim_products | Products |
| dw.dim_distribution_centers | Distribution centers |
| dw.fact_order_items | Sales facts (180,862 rows) |
| dw.fact_inventory | Stock facts (488,146 rows) |
| dw.fact_web_sessions | Session facts (680,862 rows) |
| dw.vw_customer_rfm | RFM segments (72,096 rows) |
| dw.vw_cohort_retention | Cohort grid (754 rows) |
| dw.dim_status | Loaded but not related or used by any measure |

Four tables are created inside Power BI: `_Measures` (holds all 74 measures), `Funnel Stage`, `Revenue Bridge Stage` and `Segment Order` (small DATATABLE helpers; definitions in `dax_measures.md`). `fact_web_sessions` replaces 2.4 million raw events, so the events table is not loaded.

## 2. Relationships (all many-to-one, single direction, from fact to dimension)
| From (many) | To (one) | Active |
|---|---|---|
| fact_order_items[created_date_key] | dim_date[date_key] | Yes |
| fact_order_items[shipped_date_key] | dim_date[date_key] | No (USERELATIONSHIP) |
| fact_order_items[delivered_date_key] | dim_date[date_key] | No |
| fact_order_items[returned_date_key] | dim_date[date_key] | No |
| fact_order_items[user_key] | dim_users[user_key] | Yes |
| fact_order_items[product_key] | dim_products[product_key] | Yes |
| fact_order_items[distribution_center_key] | dim_distribution_centers[distribution_center_key] | Yes |
| fact_inventory[product_key] | dim_products[product_key] | Yes |
| fact_inventory[distribution_center_key] | dim_distribution_centers[distribution_center_key] | Yes |
| fact_inventory[received_date_key] | dim_date[date_key] | Yes |
| fact_inventory[sold_date_key] | dim_date[date_key] | No |
| fact_web_sessions[session_date_key] | dim_date[date_key] | Yes |
| fact_web_sessions[user_key] | dim_users[user_key] | Yes (nullable: anonymous sessions) |
| vw_customer_rfm[user_key] | dim_users[user_key] | Yes |
| vw_customer_rfm[segment] | 'Segment Order'[Segment] | Yes |

Not related on purpose: dim_products and dim_distribution_centers (it would create two paths to the same dimension), vw_cohort_retention (stands alone), the Funnel Stage and Revenue Bridge Stage tables (disconnected, driven by SELECTEDVALUE), and dim_status.

## 3. Model settings
1. `dim_date` is marked as the date table on `full_date`. Auto date/time is off.
2. `dim_date[month_name]` is sorted by `month_no` and `weekday_name` by `weekday_no`.
3. Calculated columns: `dim_date[month_start]` (axis of the monthly chart), `fact_inventory[Aging Sort]` (hidden, sorts `aging_bucket`) and `vw_cohort_retention[cohort_year]` (heatmap rows). Formulas are in `dax_measures.md`.
4. Sort-by-column: `aging_bucket` by Aging Sort; `'Segment Order'[Segment]` by `'Segment Order'[Segment Order]` (the segment axis of the visuals uses this column, so segments appear in a fixed order); `Stage` by `Order` in both helper tables. The sort columns are hidden with summarization set to none.
5. Key columns (`*_key`, `order_id`, `order_item_id`, `inventory_item_id`) and raw numeric fact columns are hidden; measures are used instead.
6. Measure formats use Power BI's own Currency, Whole number, Percentage and Decimal options.
7. Display folders: Sales, Time intelligence, Returns, Customers, Marketing funnel, Operations, Inventory, Bridge.

## 4. Design decisions
- **Role-playing dates:** one date table serves orders (created, shipped, delivered, returned) and stock (received, sold). Inactive relationships are activated inside measures.
- **Partial 2024:** the data ends on 13 May 2024, so year-over-year measures use the same 1 January to 13 May window each year (`dim_date[is_ytd_window]`).
- **Why the cutoff for stuck shipments uses the full timestamp:** midnight of the last day would count extra items and differ from the SQL result.
- **Why a helper table sorts segments:** Power BI cannot sort a column by another column derived from itself, so segment order comes from a small independent table and the visuals use its `Segment` column on the axis. Both share measures clear the filter on that table, otherwise every share shows 100%.
- **Why web sessions are a fact table:** session-level data answers the funnel questions at 680,862 rows instead of 2.4 million events.

## 5. Performance
Expected file size is under 100 MB (the supplied file is about 84 MB). Pages open in a few seconds.
