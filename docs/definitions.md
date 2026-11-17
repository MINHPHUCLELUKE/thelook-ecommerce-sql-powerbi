# Definitions and methodology

How each metric in the report is defined. SQL file names refer to the `sql/` folder; DAX names refer to `powerbi/dax_measures.md`.

## Revenue and profit
| Term | Definition |
|---|---|
| Gross revenue | Sale price of all order items except Cancelled (returned items still count) |
| Net revenue | Sale price of all order items except Cancelled and Returned. It still includes Processing and Shipped items, so it is not "delivered revenue" |
| Delivered revenue | Gross revenue for items in Complete status only ($2.73M, 33.7% of net revenue). Kept as a sensitivity measure |
| Net profit | Net revenue minus unit cost of the same items |
| Net margin % | Net profit divided by net revenue |
| Orders | Distinct order ids with at least one non-cancelled item |
| Average order value | Gross revenue divided by non-cancelled orders (all time: $86.42) |
| Currency | The data has no currency field; amounts are treated as USD |
| Time zone | All timestamps are UTC |

## Like-for-like growth
The data ends on 13 May 2024, so 2024 is a partial year. Like-for-like (LFL) growth compares 1 January to 13 May of one year with the same calendar window of the year before (`dim_date.is_ytd_window`). The window is 134 days in leap years such as 2024 and 133 days otherwise, so the 2024 against 2023 comparison includes one extra day of 2024 sales; per day, the +164.2% revenue growth is about +162%. The LFL YoY measures take the latest year in the filter context and compare it with the year before, so with all years selected they show 2024 against 2023.

## Returns and cancellations
- Return rate = returned items divided by non-cancelled items (11.73%).
- Cancel rate = cancelled items divided by all items (14.97%).

## Customers
- **Buying customer:** a registered user with at least one non-cancelled order (72,096 of 100,000).
- **Repeat rate:** buying customers with two or more orders divided by buying customers. One-time buyer % is 1 minus repeat rate.
- **Cohort:** the month of a customer's first non-cancelled order. A returned order still counts as an order. Retention in month N is the share of the cohort that placed an order N months after the cohort month. Cells in the partial month of May 2024 are excluded, so the 2024 cohort row is partial.
- **RFM** (`vw_customer_rfm`, as of the last order date in the data):
  - Recency: days since the last non-cancelled order, scored 1 to 5 with `NTILE(5)` (5 = most recent).
  - Frequency: number of orders, capped at 5 (the maximum in the data is 4).
  - Monetary: net revenue, scored 1 to 5 with `NTILE(5)`. It is computed but not used in the segment rules.
  - Quintiles break ties arbitrarily, so a re-run on a different server could move a few customers between segments.

| Segment | Rule |
|---|---|
| Champions | Recency score 4 or 5 and frequency score 4 or more |
| Loyal | Recency score 3 or more and frequency score 3 or more (not Champions) |
| New or recent | Recency score 4 or 5 and frequency score 2 or less |
| At risk | Recency score 2 or less and frequency score 3 or more |
| Lost | Recency score 2 or less and frequency score 2 or less |
| Needs attention | Everything else |

## Web funnel
- A session is one `session_id` in the events table (680,862 sessions).
- Stages: product view, cart, purchase. Session outcomes: Purchased, Cart then cancel, Abandoned cart, Browsed only.
- Anonymous sessions never purchase and logged-in sessions always purchase, so purchase rate equals logged-in share.
- Session channel (Adwords, YouTube, Facebook, Email, Organic) differs from the customer acquisition channel (Search, Organic, Facebook, Email, Display). Revenue by channel uses the acquisition channel.

## Operations
- **Valid timeline:** ship, delivery and return times are in order. 19.6% of order items fail this test and are excluded from delivery-time metrics only.
- **Days to deliver:** hours from order to delivery divided by 24, valid timelines only.
- **Delivered within 5 days:** share of delivered items with days to deliver of 5 or less. Typical delivery takes about 4 days (90th percentile about 6 days).
- **Stuck shipment:** status Shipped, valid timeline, shipped more than 14 days before the latest order timestamp in the data.

## Inventory
- **Unsold item:** a stock row with no sale time. Unsold cost value is the sum of unit cost of unsold items.
- **Age:** days from receipt to the last activity date in the data (13 May 2024). Buckets: 0-90 days, 91-180 days, 181-365 days, 1-2 years, over 2 years.
- **Gross sell-through:** items with a sale time divided by items received. A sale time is also set for cancelled and returned items, so net sell-through (excluding those) is lower: 27.8% against 37.1%.
- **Link between orders and stock:** the raw `inventory_item_id` on order items is unreliable, so a sold stock row is found by product and sale time.

## Known limitations
- Monetary columns are stored as `float`; totals are compared at two decimals.
- Net revenue is not adjusted for items that may still be returned after the data ends.
- The data is synthetic and uniform, so differences between channels, centers and categories are small by construction.
