# Data Quality Report | The Look Co. (TheLook e-commerce dataset)

Source: restored SQL Server backup, schema `dbo` (raw) profiled through `clean` (typed) using `sql/02_profile.sql`.
Period: 2019-01-02 to 2024-05-13 (2024 is partial).

## Summary

| # | Finding | Evidence | Impact | Handling |
|---|---|---|---|---|
| 1 | All dates stored as text with a " UTC" suffix | e.g. `2024-01-21 08:21:43 UTC`, some with microseconds | Cannot sort or compute durations | Converted to `datetime2(3)` in the clean layer; no null created date on order items after conversion |
| 2 | No primary or foreign keys declared in the raw tables | No key constraints in the database catalog for the raw tables | No enforced relationships | Added PKs and FKs on `clean.*` (all 5 FKs applied without violations) |
| 3 | Impossible shipping timelines | 35,440 of 180,862 items (19.6%): Shipped 16,307, Complete 13,577, Returned 5,556 | Fulfilment-time metrics would be wrong (negative durations) | Flag `is_timeline_invalid`; keep rows for revenue and returns; exclude from fulfilment-time analysis |
| 4 | Country names mixed languages | "Brasil", "España", "Deutschland" beside English names (14 users) | Split country totals | Standardized to Brazil, Spain, Germany |
| 5 | Email is not unique | 16,322 duplicate emails across 100,000 users | Email cannot identify a customer | Use `user_id` as the only customer key |
| 6 | Two traffic-source taxonomies | users: Search, Organic, Facebook, Email, Display. events: Adwords, YouTube, Facebook, Email, Organic | Channel names do not match across tables | Keep both; users = acquisition channel, events = session channel; never join them by name |
| 7 | Blank brand | 24 products | Missing brand in rollups | Label "Unknown" in `dim_products` |
| 8 | Extreme low prices | 2 products with retail price under $1 (min $0.02) | Skews averages slightly | Keep; call out in price analysis |
| 9 | Products never sold | 75 of 29,120 | None | Keep; useful for inventory and assortment views |
| 10 | Age range 12 to 70 | 1,692 users aged under 13 | Unusual for a retailer | Keep; bucket ages and note the data is synthetic |
| 11 | Web events only partly map to orders | 180,862 purchase events equals the number of order items, not orders (124,814); no `order_id` in events. Matching purchase events to order items by user and exact time ties only 93,945 of 180,862 (52%) | Revenue cannot be attributed to the session channel reliably | Web funnel stays session-level; revenue by channel uses the customer acquisition channel (`dim_users.acquisition_channel`) |
| 12 | Web sessions follow six fixed shapes | 500,000 anonymous sessions never purchase (product only 125,225; department and product 125,023; cart abandoned 124,951; cart then cancel 124,801). 180,862 logged-in sessions always purchase (87,406 start at home) | Purchase rate by channel mostly reflects the logged-in share; the data is synthetic | Funnel stages: Product view, Cart, Purchase, with exits Abandoned cart and Cart then cancel; limitation stated in the README |
| 13 | `order_items.inventory_item_id` points at the wrong inventory row | The pointer always has the right product but 53,835 of 180,862 (29.8%) reference stock received after the order was placed, which is impossible. All 180,862 sold rows match an order item uniquely on product and sale time (no duplicates either side) | Joining on `inventory_item_id` would mark every ordered item as unsold stock | Link by `product_id` and `sold_at = created_at` (`fact_order_items.sold_inventory_item_key`, 0 items unmatched); sell-through uses `sold_at` on inventory rows |

## Checks that passed

- No orphan rows between order_items and orders, products or inventory.
- No duplicate IDs in products, inventory or events. No duplicate `inventory_item_id` in order_items.
- `orders.num_of_item` equals the real item count for all 124,814 orders. No order without items.
- Item `user_id` and item status always match the parent order. `orders.gender` always matches `users.gender`.
- Status and timestamps are consistent: Processing and Cancelled have no ship date; Shipped has a ship date but no delivery; Complete has both; Returned has ship, delivery and return dates.
- Sale price always equals the product retail price (no discounts in this dataset). No item sold below cost. No non-positive prices.
- Inventory cost always equals product cost. No item sold before it was received.
- Every event with a `user_id` belongs to a real user. Every session has exactly one traffic source. No null event dates.

## Business baselines (from profiling, used later to reconcile SQL and Power BI)

| Measure | Value |
|---|---|
| Order items | 180,862 |
| Orders | 124,814 |
| Users | 100,000 |
| Gross revenue (all except Cancelled) | $9,172,698 |
| Net revenue (all except Cancelled and Returned) | $8,096,531 |
| Cancelled value | $1,623,638 (27,072 items, 15.0%) |
| Returned value | $1,076,166 (18,041 items, 11.7% of non-cancelled items) |
| Average sale price | $59.69 |
| Average unit margin (product table) | $30.74 |
| Sessions | 680,862 (3.56 events per session) |

Caveat: Processing and Shipped items are included in revenue, so the most recent months may still change as orders complete or return.
