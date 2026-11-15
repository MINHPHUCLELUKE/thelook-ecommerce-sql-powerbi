# Report Guide | The Look Co. dashboard

Canvas 1920 x 1080 (16:9; set per page in Format page, Canvas settings, Type Custom). Each page has a background image that draws the header band (about 0 to 110 px), logo, page title and footer note. Page screenshots are in `docs/screenshots/` and the full report is in `The_Look_Ecommerce.pbix` (see the main README for the download).

## Layout (same on every page)
Positions are approximate (px on the 1920 x 1080 canvas).

| Zone | Approx. x, y, w, h | Content |
|---|---|---|
| Left panel | 35, 137, 294, 906 | Terracotta panel: 4 stacked navigation buttons, Year slicer, Department slicer, Clear all slicers button |
| KPI row | 348 to 1880, y 134, each about 295 x 119 | 5 cards |
| Middle row | y 272, about 373 high | 2 to 3 visuals |
| Bottom row | y 664, about 379 high | 2 to 3 visuals |
| Footer | y 1055 | Drawn by the background |

Rules used on every page
- Year and Department slicers are synced across pages. Year uses the Between style (range slider); Department is a list with check boxes.
- Active navigation button is dark espresso; the other three are white with terracotta-brown text.
- No text boxes. Caveats live in the visual subtitle (Format, General, Title, Subtitle).
- The Year slicer range starts at 2018 because stock receipts begin that year; sales start in 2019.
- Visuals that ignore the Year slicer carry "(all time)" in their title or card label, and their interaction from the Year slicer is turned off (Edit interactions).

---
## Page 1: Executive Sales
Question it answers: is the business growing and is it profitable?

| # | Visual | Fields and settings |
|---|---|---|
| 1 | Card: Net Revenue (shown as $8.10M) | [Net Revenue]; reference label "LFL YoY (latest year selected)" with [Net Revenue LFL YoY %] (164.2%) |
| 2 | Card: Gross Revenue | [Gross Revenue] ($9.17M) |
| 3 | Card: Net Profit | [Net Profit] ($4.20M) |
| 4 | Card: Net Margin % | [Net Margin %] (51.9%) |
| 5 | Card: Orders | [Orders] (106.14K); reference label [Orders LFL YoY %] (163.0%) |
| 6 | Combo chart: monthly net revenue (columns) and net profit (line) | Axis dim_date[month_start] (continuous, one tick per year); [Net Revenue], [Net Profit]; May 2024 column lightened with a rule on [Partial Month Flag] |
| 7 | Bar: top 10 categories by net profit | dim_products[category], [Net Profit]; tooltip shows [Net Margin %]; Top N filter 10, gradient from terracotta to light terracotta |
| 8 | Waterfall: ordered value to net revenue | 'Revenue Bridge Stage'[Stage] (Net revenue excluded), [Revenue Bridge Value]; $10.80M, ($1.62M) cancelled, ($1.08M) returned, Total $8.10M |
| 9 | 100% stacked column: department share of net revenue by year | dim_date[year_no], dim_products[department], [Net Revenue]; data labels on |
| 10 | Table: year summary | dim_date[year_no] (descending), [Net Revenue], [Net Revenue LFL YoY %], [Net Margin %], [Orders]; conditional row background; total row on |

Reading the page: net revenue is up 164% like-for-like in 2024 (Jan 1 to May 13) and margin is flat at about 52% every year.

---
## Page 2: Customers
Question: who buys, who comes back, and who is slipping away?

| # | Visual | Fields and settings |
|---|---|---|
| 1 | Card: Registered Users (All time) | [Registered Users] (100K) |
| 2 | Card: Buying customers (All time) | [RFM Customers] (72K) |
| 3 | Card: Never Bought % (All time) | [Never Bought %] (27.9%) |
| 4 | Card: Repeat Rate (All time) | [Repeat Rate] (33.3%) |
| 5 | Card: Net Revenue per Customer | [Net Revenue per Customer] ($112.30) |
| 6 | Clustered bar: customer share vs revenue share by segment (all time) | 'Segment Order'[Segment] on the axis (sorted Champions to Lost by Segment Order); [Segment Customer Share] terracotta, [Segment Revenue Share] teal |
| 7 | Bar: customers by number of orders (all time) | vw_customer_rfm[frequency] (1 to 4, 4 is the true maximum), [RFM Customers] |
| 8 | Matrix heatmap: customer retention by first purchase year | Rows vw_cohort_retention[cohort_year], columns month_index 1 to 12, values [Retention %]; terracotta color scale; subtitle "Share of the cohort ordering again, by months since first order. 2024 cohort is partial" |
| 9 | Bar: buying customers by country (top 8) | dim_users[country], [Buying Customers]; Top N filter 8 |

Reading the page: 66.7% of buyers order only once. Loyal plus Champions are 8.5% of customers and about 19% of revenue. At risk: 1,379 customers. For the 2019 to 2023 cohorts, retention in any of the first 12 months after the first order is low (1.0% to 4.5%), which fits a business that acquires fast and rarely re-engages. The 2024 cohort (10.1%, 8.1%, 7.0%) is partial and covers only the first three months.

Interactions: the Year slicer is switched off for visuals 1 to 4, 6, 7 and 8 (all time). Visuals 5 and 9 follow it.

---
## Page 3: Marketing Funnel
Question: how do sessions turn into carts and purchases, and which customers come from which channel?

| # | Visual | Fields and settings |
|---|---|---|
| 1 | Card: Sessions | [Sessions] (681K) |
| 2 | Card: Cart Rate | [Cart Rate] (63.2%) |
| 3 | Card: Purchase Rate | [Purchase Rate] (26.6%) |
| 4 | Card: Cart to Purchase % | [Cart to Purchase %] (42.0%) |
| 5 | Card: Logged-in Share | [Logged-in Share] (26.6%) |
| 6 | Funnel: session funnel | 'Funnel Stage'[Stage], [Funnel Value]; subtitle "Every session views a product, so the first two bars match." |
| 7 | 100% stacked bar: session outcome by traffic source | fact_web_sessions[traffic_source], [session_outcome]; colors Abandoned cart terracotta, Browsed only teal, Cart then cancel saffron, Purchased green-grey |
| 8 | Table: traffic source performance | fact_web_sessions[traffic_source], [Sessions], [Cart Rate], [Purchase Rate]; subtitle "Conversion cannot rank channels. No marketing cost data." |
| 9 | Line: sessions and purchase sessions by year | dim_date[year_no], [Sessions], [Purchase Sessions]; subtitle "Purchase share of sessions rose from 3% in 2019 to 40% in 2023. 2024 is partial (to 13 May)." |
| 10 | Combo: net revenue (columns) and net revenue per customer (line, secondary axis) by acquisition channel | dim_users[acquisition_channel]; subtitle "Customer record channel, not the same as session channel." |

Caveats carried in the subtitles above: anonymous sessions never purchase, so Purchase Rate equals the logged-in share; funnel steps are identical in every channel; acquisition channel (customer record) and session channel (web events) use different names.

---
## Page 4: Operations and Inventory
Question: how fast do we deliver, where do shipments stall, and how much stock is stranded?

| # | Visual | Fields and settings |
|---|---|---|
| 1 | Card: Avg Days to Deliver | [Avg Days to Deliver] (3.95) |
| 2 | Card: Delivered Within 5 Days % | [Delivered Within 5 Days %] (71.1%) |
| 3 | Card: Stuck Shipments Value (>14d) | [Stuck Shipments Value (>14d)] ($2.14M); reference label [Stuck Shipments (>14d)] (35,936) |
| 4 | Card: Unsold stock at cost | [Unsold Cost Value] ($8.83M) |
| 5 | Card: Unsold stock over 1 year | [Over 1 Year Share] (77.1%) |
| 6 | Table: fulfilment by distribution center | dim_distribution_centers[distribution_center_name], [Delivered Valid Items], [Avg Days to Ship], [Avg Days to Deliver], [Delivered Within 5 Days %], [Return Rate]; background color scale; subtitle "Valid timelines only (about 70% of shipped items). Follows the Year slicer by order date." Scrolls (10 rows) |
| 7 | Bar: items sold by distribution center | dim_distribution_centers[distribution_center_name], [Items Sold]. Replaces the map: the 10 centers are close to uniform and a bar reads faster |
| 8 | Column: unsold stock at cost by age | fact_inventory[aging_bucket] (sorted by Aging Sort; the "Sold" bucket has no unsold cost so it does not appear), [Unsold Cost Value]; subtitle "Follows the Year slicer by received date." |
| 9 | Line: gross sell-through by received year | dim_date[year_no] (received date, 2020 to 2024), [Gross Sell-Through %]; subtitle "From 2020. Gross: cancelled and returned count as sold. Net: 27.8%." |
| 10 | Table: top 10 products by unsold stock at cost | dim_products[product_name], [Unsold Items], [Unsold Cost Value]; Top N 10; scrolls |

Reading the page: delivery is about 3.9 days in every center; 35,936 shipped items (about $2.14M) have been in "Shipped" for more than 14 days; 77.1% of unsold stock cost is over a year old, and $4.8M is over two years old.

---
## Interaction and design notes
- Edit interactions: all-time visuals ignore the Year slicer.
- Slicers are synced across the four pages; the active page's navigation button is highlighted.
- May 2024 is lightened as a partial month on the monthly combo chart.
- Caveats sit in visual subtitles on the Funnel and Operations pages.
- Known cosmetic limits: the two tables on Page 4 scroll inside their frames, data labels on the Page 3 combo chart overlap slightly, and on Page 2 the segment bar labels touch the bars above.
- Palette: Terracotta #C4572F (main series), Teal #2F6F73 (comparison), Saffron #E0A33A (highlight), Stone #8A8178 (context), Espresso #2B211C (text and header). Good #3F7D5A and bad #A8322A are used in the waterfall only.
