# Data Dictionary

Two layers: the `clean` schema (typed copy of the raw tables) and the `dw` schema (star schema used by Power BI). Types in the `clean` section are after `sql/01_clean_layer.sql`. All timestamps are UTC.

## Part 1: clean schema

## clean.users (100,000)
| Column | Type | Description |
|---|---|---|
| user_id | bigint, PK | Customer key |
| first_name, last_name | nvarchar | Trimmed names |
| email | nvarchar | Not unique (16,322 duplicates) |
| age | bigint | 12 to 70 |
| gender | nvarchar | M or F |
| state, city, postal_code | nvarchar | Customer address parts |
| country | nvarchar | Standardized (Brazil, Spain, Germany) |
| latitude, longitude | float | Customer location |
| traffic_source | nvarchar | Acquisition channel: Search, Organic, Facebook, Email, Display |
| created_at | datetime2(3) | Sign-up time |

## clean.products (29,120)
| Column | Type | Description |
|---|---|---|
| product_id | bigint, PK | Product key |
| name, brand, category, department, sku | nvarchar | Descriptors. 15 categories; department is Women or Men; 24 blank brands |
| cost | float | Unit cost |
| retail_price | float | List price (equals sale price on every order item) |
| unit_margin | float | Derived: retail_price minus cost |
| distribution_center_id | bigint, FK | Home distribution center |

## clean.distribution_centers (10)
| Column | Type | Description |
|---|---|---|
| distribution_center_id | bigint, PK | Key |
| name | nvarchar | Center name |
| latitude, longitude | float | Location |

## clean.inventory (488,146)
| Column | Type | Description |
|---|---|---|
| inventory_item_id | bigint, PK | Inventory row key. order_items.inventory_item_id points at a different row, so do not join on it |
| product_id | bigint | Product |
| cost | float | Unit cost (equals product cost) |
| received_at | datetime2(3) | Stock creation time |
| sold_at | datetime2(3) | Sale time; NULL on 307,284 rows (unsold stock). Use this column for sell-through, not order_items.inventory_item_id (finding 13) |
| distribution_center_id | bigint | Center holding the item |

## clean.orders (124,814)
| Column | Type | Description |
|---|---|---|
| order_id | bigint, PK | Order key |
| user_id | bigint, FK | Customer |
| status | nvarchar | Shipped, Complete, Processing, Cancelled, Returned |
| num_of_item | bigint | Items in the order (always matches order_items) |
| created_at, shipped_at, delivered_at, returned_at | datetime2(3) | Lifecycle times; NULL when the stage has not happened |

## clean.order_items (180,862)
| Column | Type | Description |
|---|---|---|
| order_item_id | bigint, PK | Line key |
| order_id, user_id, product_id, inventory_item_id | bigint, FK | Links to orders, users, products, inventory |
| status | nvarchar | Same values as orders; always equals the parent order status |
| sale_price | float | Price paid (equals retail price) |
| created_at, shipped_at, delivered_at, returned_at | datetime2(3) | Lifecycle times |
| is_timeline_invalid | int | 1 when shipped, delivered or returned time is earlier than the previous stage (35,440 rows) |

## clean.events (2,420,661)
| Column | Type | Description |
|---|---|---|
| event_id | bigint, PK | Event key |
| user_id | bigint | NULL for anonymous visitors |
| is_anonymous | int | 1 when user_id is NULL |
| session_id | nvarchar | Session (680,862 sessions); each has one traffic source |
| sequence_number | bigint | Order of the event in a session |
| created_at | datetime2(3) | Event time |
| city, state, postal_code, browser | nvarchar | Visitor context |
| traffic_source | nvarchar | Session channel: Adwords, YouTube, Facebook, Email, Organic |
| uri | nvarchar | Page visited |
| event_type | nvarchar | home, department, product, cart, purchase, cancel |

## Relationships
- orders.user_id to users.user_id
- order_items.order_id to orders.order_id; order_items.product_id to products.product_id; order_items.inventory_item_id to inventory.inventory_item_id
- products.distribution_center_id to distribution_centers.distribution_center_id
- events.user_id to users.user_id (nullable); events have no link to orders

---

## Part 2: dw schema (star schema)

Built by `sql/03_star_schema.sql`. Dates are stored as integer keys in the form `yyyymmdd` that join to `dw.dim_date`.

## Revenue rules
| Status | Gross revenue | Net revenue |
|---|---|---|
| Processing, Shipped, Complete | Counted | Counted |
| Returned | Counted | Not counted |
| Cancelled | Not counted | Not counted |

## dw.fact_order_items (180,862 rows, one per order item)
| Column | Description |
|---|---|
| order_item_id (PK), order_id | Line and order keys |
| user_key, product_key, distribution_center_key | Links to the dimensions |
| created_date_key, shipped_date_key, delivered_date_key, returned_date_key | Role-playing date keys (NULL when the stage has not happened) |
| created_at, shipped_at, delivered_at, returned_at | Lifecycle timestamps |
| status | Processing, Shipped, Complete, Returned or Cancelled |
| sale_price, unit_cost, unit_margin | Price paid, product cost, price minus cost |
| gross_revenue, net_revenue, gross_profit, net_profit | Revenue and profit under the rules above (0 when not counted) |
| returned_revenue, cancelled_value | Sale price of returned or cancelled items |
| is_returned, is_cancelled | 1 or 0 flags |
| is_timeline_invalid | 1 when a ship, delivery or return time is earlier than the previous stage (19.6% of rows) |
| days_to_ship, days_in_transit, days_to_deliver | Durations in days, only for rows with a valid timeline |
| sold_inventory_item_key | Inventory row matched on product and sale time (the raw `inventory_item_id` is unreliable) |

## dw.fact_inventory (488,146 rows, one per stock item)
| Column | Description |
|---|---|
| inventory_item_id (PK), product_key, distribution_center_key | Keys |
| cost, retail_price | Unit cost and list price |
| received_at, sold_at, received_date_key, sold_date_key | Stock lifecycle (`sold_at` is NULL for unsold stock) |
| is_sold | 1 when `sold_at` is set |
| days_in_stock | Days from receipt to sale, or to the last activity date for unsold items |
| days_to_sell | Days from receipt to sale (sold items only) |
| aging_bucket | Sold, 0-90 days, 91-180 days, 181-365 days, 1-2 years or Over 2 years (as of 13 May 2024) |

## dw.fact_web_sessions (680,862 rows, one per session)
| Column | Description |
|---|---|
| session_id (PK), user_key | Session key; user is NULL for anonymous sessions |
| session_start, session_end, session_date_key | Timing |
| traffic_source | Session channel: Adwords, YouTube, Facebook, Email, Organic |
| is_anonymous | 1 when no user is attached |
| has_home, has_department, has_product, has_cart, has_purchase, has_cancel | 1 when the session contained that event type |
| funnel_stage | 0 browse, 1 product view, 2 cart, 3 purchase |
| session_outcome | Purchased, Cart then cancel, Abandoned cart or Browsed only |
| event_count, browser, state | Session context |

## Dimensions
| Table | Rows | Key columns and notes |
|---|---|---|
| dim_date | 2,557 | date_key (PK), full_date, year_no, quarter_no, month_no, month_name, year_month, day_of_month, weekday_no, weekday_name, is_weekend, **is_ytd_window** (1 for 1 Jan to 13 May of any year, used for like-for-like comparisons) |
| dim_users | 100,000 | user_key (PK), full_name, age, age_group, gender, country, state, city, latitude, longitude, **acquisition_channel** (Search, Organic, Facebook, Email, Display), signup_at, signup_date_key. No email or street address |
| dim_products | 29,120 | product_key (PK), product_name, brand ("Unknown" when blank), category, department, sku, cost, retail_price, unit_margin, price_band, distribution_center_key |
| dim_distribution_centers | 10 | distribution_center_key (PK), distribution_center_name, latitude, longitude |
| dim_status | 5 | status (PK) with the flags that define gross and net revenue |

## Views used by Power BI
| View | Rows | Description |
|---|---|---|
| dw.vw_customer_rfm | 72,096 | One row per buying customer: user_key, recency_days, last_order_at, frequency, monetary (net revenue), r_score, f_score, m_score, segment (Champions, Loyal, Needs attention, At risk, New or recent, Lost) |
| dw.vw_cohort_retention | 754 | Cohort grid: cohort_month, month_index (0 to 12), cohort_customers, active_customers. Excludes cells that fall in the partial month of May 2024 |

Other `dw` objects not used by Power BI: `vw_monthly_kpis`, `vw_product_performance`, `usp_kpi_summary`. Measure definitions are in `powerbi/dax_measures.md`.
