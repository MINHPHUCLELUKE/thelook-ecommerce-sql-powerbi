# DAX Measures | The Look Co.

74 measures live in a table named `_Measures` (a calculated table, `ROW ( "Placeholder", 1 )`, with its column hidden). This file is the final version and matches the Power BI model checked on 15 Nov 2026. Display folders are named in the headings below.

## How formats are set
Formats are set with Power BI's own Format options (Measure tools, Format), not custom strings, so they show as Currency, Whole number, Percentage or Decimal number. The comment after each measure gives the type.

| Type | Power BI choice | Format string Power BI stores |
|---|---|---|
| Currency, 0 decimals | Currency, 0 | `\$#,0;(\$#,0);\$#,0` |
| Currency, 2 decimals | Currency, 2 | `\$#,0.00;(\$#,0.00);\$#,0.00` |
| Whole number | Whole number | `#,0` |
| Percentage | Percentage, 1 | `0.0%;-0.0%;0.0%` |
| Decimal number | Decimal number, 1 or 2 | `#,0.0` or `#,0.00` |

Headline money measures (Gross Revenue, Net Revenue, Net Profit, Average Order Value, Net Revenue per Customer, Unsold Cost Value, Stuck Shipments Value) use 2 decimals so the cards can switch display units; all other money measures use 0 decimals.

## Folder: Sales
```dax
Gross Revenue = SUM ( fact_order_items[gross_revenue] )            -- Currency 2
Net Revenue = SUM ( fact_order_items[net_revenue] )                -- Currency 2
Net Profit = SUM ( fact_order_items[net_profit] )                  -- Currency 2
Net Margin % = DIVIDE ( [Net Profit], [Net Revenue] )              -- Percentage
Ordered Value = SUM ( fact_order_items[sale_price] )               -- Currency 0
Cancelled Value = SUM ( fact_order_items[cancelled_value] )        -- Currency 0
Returned Revenue = SUM ( fact_order_items[returned_revenue] )      -- Currency 0

Orders =                                                           -- Decimal 2 (displayed in thousands on the card)
CALCULATE ( DISTINCTCOUNT ( fact_order_items[order_id] ), fact_order_items[is_cancelled] = 0 )

Items Sold =                                                       -- Whole number
CALCULATE ( COUNTROWS ( fact_order_items ), fact_order_items[is_cancelled] = 0 )

Average Order Value = DIVIDE ( [Gross Revenue], [Orders] )         -- Currency 2

Delivered Revenue =                                                -- Currency 0, sensitivity: Complete status only
CALCULATE ( [Gross Revenue], fact_order_items[status] = "Complete" )
```

## Folder: Time intelligence
```dax
Data As Of Date =                                                  -- yyyy-mm-dd
VAR d = CALCULATE ( MAX ( fact_order_items[created_at] ), ALL ( fact_order_items ) )
RETURN DATE ( YEAR ( d ), MONTH ( d ), DAY ( d ) )

Partial Month Flag =                                               -- Whole number, 1 when the month extends beyond the data
IF ( EOMONTH ( MAX ( dim_date[full_date] ), 0 ) > [Data As Of Date], 1, 0 )

Net Revenue LY = CALCULATE ( [Net Revenue], SAMEPERIODLASTYEAR ( dim_date[full_date] ) )   -- Currency 0
Net Revenue YoY % = DIVIDE ( [Net Revenue] - [Net Revenue LY], [Net Revenue LY] )           -- Percentage
Net Revenue PM = CALCULATE ( [Net Revenue], DATEADD ( dim_date[full_date], -1, MONTH ) )    -- Currency 0
Net Revenue MoM % = DIVIDE ( [Net Revenue] - [Net Revenue PM], [Net Revenue PM] )           -- Percentage
Net Revenue YTD = TOTALYTD ( [Net Revenue], dim_date[full_date] )                           -- Currency 0

-- Like-for-like: Jan 1 to May 13 of every year (dim_date[is_ytd_window] = 1, 134 days)
Net Revenue LFL = CALCULATE ( [Net Revenue], dim_date[is_ytd_window] = 1 )                   -- Currency 0
Net Revenue LFL LY = CALCULATE ( [Net Revenue LFL], SAMEPERIODLASTYEAR ( dim_date[full_date] ) )   -- Currency 0
Net Revenue LFL YoY % =                                                                      -- Percentage, latest year in context vs the year before
VAR yr = MAX ( dim_date[year_no] )
VAR cur = CALCULATE ( [Net Revenue], REMOVEFILTERS ( dim_date ), dim_date[is_ytd_window] = 1, dim_date[year_no] = yr )
VAR ly  = CALCULATE ( [Net Revenue], REMOVEFILTERS ( dim_date ), dim_date[is_ytd_window] = 1, dim_date[year_no] = yr - 1 )
RETURN DIVIDE ( cur - ly, ly )
Orders LFL = CALCULATE ( [Orders], dim_date[is_ytd_window] = 1 )                             -- Whole number
Orders LFL LY = CALCULATE ( [Orders LFL], SAMEPERIODLASTYEAR ( dim_date[full_date] ) )       -- Whole number
Orders LFL YoY % =                                                                           -- Percentage, same logic on [Orders]
VAR yr = MAX ( dim_date[year_no] )
VAR cur = CALCULATE ( [Orders], REMOVEFILTERS ( dim_date ), dim_date[is_ytd_window] = 1, dim_date[year_no] = yr )
VAR ly  = CALCULATE ( [Orders], REMOVEFILTERS ( dim_date ), dim_date[is_ytd_window] = 1, dim_date[year_no] = yr - 1 )
RETURN DIVIDE ( cur - ly, ly )
```
The two LFL YoY % measures are on the Page 1 cards and the year table. They compare the latest year in the current filter context with the year before, each limited to 1 January to 13 May. With all years selected the cards therefore show 2024 against 2023 (+164.2% net revenue, +163.0% orders); with a single year selected they show that year against the previous one. `Partial Month Flag` drives the conditional format that lightens the May 2024 bar.

`Net Revenue YoY %`, `MoM %` and `YTD` are kept for analysis and are not on report pages. `YoY %` compares the partial 2024 with a full 2023, so use the LFL measures for 2024. Other measures that are not on a page (for example `Cancel Rate`, `Median Days to Deliver`, `P90 Days to Deliver`, `Unsold Retail Value`) support ad-hoc analysis.

Calculated column on `dim_date` for the monthly chart axis (one tick per month, sorted by date):
```dax
month_start = DATE ( YEAR ( dim_date[full_date] ), MONTH ( dim_date[full_date] ), 1 )   -- Date format "mmm yyyy", summarize: none
```

## Folder: Returns
```dax
Returned Items = SUM ( fact_order_items[is_returned] )                           -- Whole number
Return Rate = DIVIDE ( [Returned Items], [Items Sold] )                          -- Percentage
Cancel Rate = DIVIDE ( SUM ( fact_order_items[is_cancelled] ), COUNTROWS ( fact_order_items ) )   -- Percentage
Profit Lost to Returns = SUM ( fact_order_items[gross_profit] ) - SUM ( fact_order_items[net_profit] )   -- Currency 0
```

## Folder: Customers
```dax
Registered Users = COUNTROWS ( dim_users )                                       -- Whole number
Buying Customers =                                                               -- Whole number, within the selected dates
CALCULATE ( DISTINCTCOUNT ( fact_order_items[user_key] ), fact_order_items[is_cancelled] = 0 )
Net Revenue per Customer = DIVIDE ( [Net Revenue], [Buying Customers] )          -- Currency 2
Orders per Customer = DIVIDE ( [Orders], [Buying Customers] )                    -- Decimal 2

-- All-time customer measures from the RFM view
RFM Customers = DISTINCTCOUNT ( vw_customer_rfm[user_key] )                      -- Whole number
Never Bought = [Registered Users] - [RFM Customers]                              -- Whole number
Never Bought % = DIVIDE ( [Never Bought], [Registered Users] )                   -- Percentage
Repeat Customers = CALCULATE ( DISTINCTCOUNT ( vw_customer_rfm[user_key] ), vw_customer_rfm[frequency] >= 2 )   -- Whole number
Repeat Rate = DIVIDE ( [Repeat Customers], [RFM Customers] )                     -- Percentage
One-Time Buyer % = 1 - [Repeat Rate]                                             -- Percentage
Segment Net Revenue = SUM ( vw_customer_rfm[monetary] )                          -- Currency 0

Segment Customer Share =                                                         -- Percentage
DIVIDE ( [RFM Customers],
    CALCULATE ( [RFM Customers], ALL ( vw_customer_rfm[segment] ), ALL ( 'Segment Order' ) ) )

Segment Revenue Share =                                                          -- Percentage
DIVIDE ( [Segment Net Revenue],
    CALCULATE ( [Segment Net Revenue], ALL ( vw_customer_rfm[segment] ), ALL ( 'Segment Order' ) ) )

-- Cohort matrix (rows: cohort_year, columns: month_index)
Retention % = DIVIDE ( SUM ( vw_cohort_retention[active_customers] ), SUM ( vw_cohort_retention[cohort_customers] ) )   -- Percentage
```

Segment sort order. A helper table fixes the order Champions, Loyal, Needs attention, At risk, New or recent, Lost. It is related to `vw_customer_rfm[segment]` (many to one, single direction) and `vw_customer_rfm[segment]` is sorted by `'Segment Order'[Segment Order]`. Both share measures must clear the filter on the helper table as well as on the segment column, otherwise every share shows 100%.
```dax
Segment Order = DATATABLE ( "Segment", STRING, "Segment Order", INTEGER,
    { { "Champions", 1 }, { "Loyal", 2 }, { "Needs attention", 3 },
      { "At risk", 4 }, { "New or recent", 5 }, { "Lost", 6 } } )
```

Calculated column on `vw_cohort_retention`. The heatmap shows 6 rows (one per cohort year) instead of 64 monthly cohorts, so it fits the page:
```dax
cohort_year = YEAR ( vw_cohort_retention[cohort_month] )                         -- Whole number "0", summarize: none
```

## Folder: Marketing funnel
```dax
Sessions = COUNTROWS ( fact_web_sessions )                                       -- Whole number
Product View Sessions = SUM ( fact_web_sessions[has_product] )                   -- Whole number
Cart Sessions = SUM ( fact_web_sessions[has_cart] )                              -- Whole number
Purchase Sessions = SUM ( fact_web_sessions[has_purchase] )                      -- Whole number
Cart Rate = DIVIDE ( [Cart Sessions], [Sessions] )                               -- Percentage
Purchase Rate = DIVIDE ( [Purchase Sessions], [Sessions] )                       -- Percentage
Cart to Purchase % = DIVIDE ( [Purchase Sessions], [Cart Sessions] )             -- Percentage
Abandoned Cart Sessions = CALCULATE ( COUNTROWS ( fact_web_sessions ), fact_web_sessions[session_outcome] = "Abandoned cart" )   -- Whole number
Cancel After Cart Sessions = CALCULATE ( COUNTROWS ( fact_web_sessions ), fact_web_sessions[session_outcome] = "Cart then cancel" )   -- Whole number
Logged-in Share = DIVIDE ( CALCULATE ( COUNTROWS ( fact_web_sessions ), fact_web_sessions[is_anonymous] = 0 ), [Sessions] )   -- Percentage

-- Disconnected table for the funnel visual (Stage sorted by Order, Order hidden)
Funnel Stage = DATATABLE ( "Stage", STRING, "Order", INTEGER,
    { { "All sessions", 0 }, { "Product view", 1 }, { "Cart", 2 }, { "Purchase", 3 } } )

Funnel Value =                                                                   -- Whole number
SWITCH ( SELECTEDVALUE ( 'Funnel Stage'[Order] ),
    0, [Sessions], 1, [Product View Sessions], 2, [Cart Sessions], 3, [Purchase Sessions] )
```
Caveat shown in the page 3 visual subtitles: anonymous sessions never purchase in this dataset, so Purchase Rate equals the logged-in share and is not a channel quality measure.

## Folder: Operations
```dax
Avg Days to Ship = AVERAGE ( fact_order_items[days_to_ship] )                    -- Decimal 2, valid timelines only
Avg Days in Transit = AVERAGE ( fact_order_items[days_in_transit] )              -- Decimal 2
Avg Days to Deliver = AVERAGE ( fact_order_items[days_to_deliver] )              -- Decimal 2
Median Days to Deliver = MEDIAN ( fact_order_items[days_to_deliver] )            -- Decimal 2
P90 Days to Deliver = PERCENTILE.INC ( fact_order_items[days_to_deliver], 0.9 )  -- Decimal 2
Delivered Valid Items = COUNT ( fact_order_items[days_to_deliver] )              -- Whole number

Delivered Within 5 Days % =                                                      -- Percentage
DIVIDE (
    COUNTROWS ( FILTER ( fact_order_items,
        NOT ISBLANK ( fact_order_items[days_to_deliver] ) && fact_order_items[days_to_deliver] <= 5 ) ),
    [Delivered Valid Items] )

Invalid Timeline Share =                                                         -- Percentage, of rows that have a ship date
DIVIDE (
    SUM ( fact_order_items[is_timeline_invalid] ),
    COUNTROWS ( FILTER ( fact_order_items, NOT ISBLANK ( fact_order_items[shipped_at] ) ) ) )

Stuck Shipments (>14d) =                                                         -- Whole number
VAR cutoff = CALCULATE ( MAX ( fact_order_items[created_at] ), ALL ( fact_order_items ) ) - 14
RETURN CALCULATE ( COUNTROWS ( fact_order_items ),
    fact_order_items[status] = "Shipped",
    fact_order_items[is_timeline_invalid] = 0,
    fact_order_items[shipped_at] < cutoff )

Stuck Shipments Value (>14d) =                                                   -- Currency 2
VAR cutoff = CALCULATE ( MAX ( fact_order_items[created_at] ), ALL ( fact_order_items ) ) - 14
RETURN CALCULATE ( SUM ( fact_order_items[sale_price] ),
    fact_order_items[status] = "Shipped",
    fact_order_items[is_timeline_invalid] = 0,
    fact_order_items[shipped_at] < cutoff )
```
Why the cutoff uses the full timestamp: `[Data As Of Date]` is midnight of the last day, so subtracting 14 days from it counts a handful of extra items and gives a different total than SQL. The exact latest timestamp gives 35,936 items and about $2.14M, matching SQL query 4.6.

## Folder: Inventory
Calculated column on `fact_inventory` (hidden) used to sort `aging_bucket`. It is built from `is_sold` and `days_in_stock` rather than from the bucket text, because Power BI rejects sorting a column by another column derived from itself (circular dependency):
```dax
Aging Sort =
SWITCH ( TRUE (),
    fact_inventory[is_sold] = 1, 0,
    fact_inventory[days_in_stock] <= 90, 1,
    fact_inventory[days_in_stock] <= 180, 2,
    fact_inventory[days_in_stock] <= 365, 3,
    fact_inventory[days_in_stock] <= 730, 4,
    5 )
```
Measures:
```dax
Items Received = COUNTROWS ( fact_inventory )                                    -- Whole number
Items Sold (Stock) = SUM ( fact_inventory[is_sold] )                             -- Whole number
Gross Sell-Through % = DIVIDE ( [Items Sold (Stock)], [Items Received] )         -- Percentage, counts cancelled and returned as sold
Unsold Items = CALCULATE ( COUNTROWS ( fact_inventory ), fact_inventory[is_sold] = 0 )   -- Whole number
Unsold Cost Value = CALCULATE ( SUM ( fact_inventory[cost] ), fact_inventory[is_sold] = 0 )   -- Currency 2
Unsold Retail Value = CALCULATE ( SUM ( fact_inventory[retail_price] ), fact_inventory[is_sold] = 0 )   -- Currency 0
Over 1 Year Unsold Value =                                                       -- Currency 0
CALCULATE ( [Unsold Cost Value], fact_inventory[aging_bucket] IN { "1-2 years", "Over 2 years" } )
Over 1 Year Share = DIVIDE ( [Over 1 Year Unsold Value], [Unsold Cost Value] )   -- Percentage
Dead Stock Value (>2y) = CALCULATE ( [Unsold Cost Value], fact_inventory[aging_bucket] = "Over 2 years" )   -- Currency 0
Avg Days to Sell = AVERAGE ( fact_inventory[days_to_sell] )                      -- Decimal 1
```
Net sell-through (27.8%, excluding cancelled and returned) is not a DAX measure because the two fact tables are not related. It is quoted in the subtitle of the sell-through chart ("Net: 27.8%") and comes from SQL query 4.7 G.

## Folder: Bridge
```dax
Revenue Bridge Stage = DATATABLE ( "Stage", STRING, "Order", INTEGER,
    { { "Ordered value", 1 }, { "Cancelled", 2 }, { "Returned", 3 }, { "Net revenue", 4 } } )

Revenue Bridge Value =                                                           -- Currency 0
SWITCH ( SELECTEDVALUE ( 'Revenue Bridge Stage'[Order] ),
    1, [Ordered Value], 2, -[Cancelled Value], 3, -[Returned Revenue], 4, [Net Revenue] )
```
Waterfall setup: `Stage` is sorted by `Order` in the model. The right-click menu has no "Set as total" in the current Power BI, so the "Net revenue" stage is excluded from the Category (right-click the bar, Exclude) and the waterfall's own Total bar closes the chart at $8.10M.

## Model-level settings that are part of the measures
- `Stage` columns of `Funnel Stage` and `Revenue Bridge Stage` are sorted by their `Order` column; the `Order` columns are hidden with summarization set to none.
- `Segment` is sorted by `Segment Order`; `Segment Order` is hidden.
- `fact_inventory[aging_bucket]` is sorted by `Aging Sort` (hidden).
- `dim_date[month_name]` is sorted by `month_no`, `weekday_name` by `weekday_no`.
