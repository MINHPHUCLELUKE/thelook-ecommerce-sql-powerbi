# QA Checklist | SQL vs Power BI reconciliation

Completed 15 Nov 2026. Every Power BI value below was queried from the open model with no slicers (all years, both departments), then compared with the SQL value. All checks pass.

## Sales (target source: sql/03b_reconciliation.sql and 04_analysis/01)
| Check | Expected | Power BI | OK |
|---|---|---|---|
| Gross Revenue | $9,172,697.60 | $9,172,697.60 | [x] |
| Net Revenue | $8,096,531.48 | $8,096,531.48 | [x] |
| Net Profit | $4,201,367.01 (SUM of net_profit in dw.fact_order_items) | $4,201,367.01 | [x] |
| Net Margin % | about 51.9% | 51.9% | [x] |
| Orders (non-cancelled) | 106,135 (distinct order_id where is_cancelled = 0) | 106,135 | [x] |
| Orders by year add up to more than the total | Yearly distinct counts sum to 106,296, 161 above 106,135, because an order with items in two years counts once in each year (see definitions) | as expected | [x] |
| Net Revenue, year 2019 / 2020 / 2021 / 2022 / 2023 | $148,301.57 / $484,853.11 / $926,101.80 / $1,583,798.54 / $2,793,942.35 | same | [x] |
| Net Revenue, year 2024 (to 13 May) | $2,159,534.10 | $2,159,534.10 | [x] |
| Net Revenue LFL, 2023 and 2024 | $817,308.44 and $2,159,534.10 | same | [x] |
| Net Revenue LFL YoY %, 2024 (also the Page 1 card with all years selected) | +164.2% | +164.2% | [x] |
| Orders LFL YoY %, 2024 (also the Page 1 card with all years selected) | +163.0% | +163.0% | [x] |
| Return Rate | 11.73% (18,041 returned of 153,790 non-cancelled items) | 11.73%, 18,041 | [x] |
| Cancel Rate | 14.97% (27,072 of 180,862) | 14.97% | [x] |
| Net margin, Jeans / Outerwear and Coats | 46.5% / 55.6% | 46.5% / 55.6% | [x] |

## Customers (sql 04_analysis/03 and 04)
| Check | Expected | Power BI | OK |
|---|---|---|---|
| Registered Users | 100,000 | 100,000 | [x] |
| RFM Customers (buying) | 72,096 | 72,096 | [x] |
| Never Bought | 27,904 (27.9%) | 27,904 (27.9%) | [x] |
| Segments: Lost / New or recent / Needs attention / Loyal / Champions / At risk | 27,460 / 24,244 / 12,891 / 4,417 / 1,705 / 1,379 | same | [x] |
| Segment shares add to 100% | 100% each for customers and revenue | 100% (after adding ALL on the Segment Order table) | [x] |
| One-Time Buyer % | 66.7% | 66.7% | [x] |
| Cohort retention, Mar 2024 cohort, month 1 | 12.7% | 12.7% | [x] |

## Marketing funnel (sql 04_analysis/05)
| Check | Expected | Power BI | OK |
|---|---|---|---|
| Sessions | 680,862 | 680,862 | [x] |
| Cart Sessions | 430,614 | 430,614 | [x] |
| Purchase Sessions | 180,862 | 180,862 | [x] |
| Purchase Rate | 26.6% | 26.6% | [x] |
| Cart to Purchase % | 42.0% | 42.0% | [x] |
| Email sessions / Adwords sessions | 306,377 / 203,690 | 306,377 / 203,690 | [x] |
| Net Revenue, acquisition channel Search | $5,670,116.93 | $5,670,116.93 | [x] |

## Operations and inventory (sql 04_analysis/06 and 07)
| Check | Expected | Power BI | OK |
|---|---|---|---|
| Delivered Valid Items | 44,330 | 44,330 | [x] |
| Delivered Revenue (Complete status only) | $2.73M (analysis_insights 4.6) | $2,729,363.48 (33.7% of net revenue) | [x] |
| Avg Days to Deliver, Houston TX / Memphis TN | 3.908 / 3.986 | 3.908 / 3.986 | [x] |
| Delivered Within 5 Days %, Charleston SC | 71.7% | 71.7% | [x] |
| Stuck Shipments (>14d) | 35,936 items, about $2.14M | 35,936 items, $2,139,493.53 | [x] |
| Items Received / Unsold Items | 488,146 / 307,284 | 488,146 / 307,284 | [x] |
| Unsold Cost Value | about $8.83M | $8,833,075.34 | [x] |
| Over 1 Year Unsold Value | about $6.81M (77%) | $6,812,215.36 (77.1%) | [x] |
| Dead Stock Value (>2y) | $4,787,150 | $4,787,150.28 | [x] |
| Gross Sell-Through % | 37.1% | 37.05% | [x] |
| Average Order Value (all time) | gross revenue / non-cancelled orders = $86.42 | $86.42 | [x] |

## Visual and usability checks
- [x] Every page opens without errors and loads in a few seconds
- [x] Slicers sync across pages; all-time visuals ignore the Year slicer
- [x] Navigation buttons work and the active page shows the highlighted button
- [x] No overlapping visuals; all content sits inside the 1920 x 1080 canvas (left panel x 35 to 329, content x 348 to 1880)
- [x] May 2024 is lightened as a partial month on the monthly chart
- [x] Caveat notes present on Funnel and Operations pages (in visual subtitles, no text boxes)
- [x] Text readable at 100% zoom
- [x] Screenshots exported for the README (one per page, `docs/screenshots/`)

## Issues found and fixed during QA
| Issue | Cause | Fix |
|---|---|---|
| Stuck Shipments gave a different count than SQL | Cutoff used midnight of the last day | Cutoff is now the exact latest timestamp minus 14 days |
| Segment shares all showed 100% | Share denominators did not clear the filter coming from the Segment Order table | Added ALL ( 'Segment Order' ) to both share measures |
| Aging bucket sort was circular | Sort column was derived from the bucket text | Aging Sort is built from is_sold and days_in_stock |
| Monthly combo chart was crowded | One label per month on a text axis | Axis on dim_date[month_start], continuous, one tick per year |
| Page 1 growth card showed 123.4% instead of 164.2% | With all years selected, the prior-year window summed every earlier year | LFL YoY measures now compare the latest year in context with the year before |

## If a number does not match
1. Check the slicers and page filters first.
2. Check the relationship used (created date vs shipped or received date).
3. Check blank handling: fields with blanks need `COUNT` or an explicit `ISBLANK` test.
4. Re-run the SQL check in SSMS and compare row by row.
