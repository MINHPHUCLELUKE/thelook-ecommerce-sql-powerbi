# Analysis Insights | The Look Co.

Findings from `sql/04_analysis/` (run on the restored database).
Revenue terms: **gross** = all items except Cancelled; **net** = also excluding Returned. 2024 data ends 13 May, so year-over-year uses the same Jan 1 to May 13 window. **Average order value** is gross revenue divided by non-cancelled orders (all-time $86.42).

## Headline findings

1. **Growth is strong, and 2024 is running well ahead.** Net revenue grew from $148k (2019) to $2.79M (2023). Like-for-like (Jan 1 to May 13), 2024 net revenue is $2.16M against $0.82M in 2023, up 164%, with orders up 163%. Full-year growth slowed from 227% in 2020 to 71% to 91% a year since (76% in 2023), so the jump is in the partial 2024 figures.
2. **Margin is flat at about 52%.** Prices always equal list price (no discounting) and costs track price, so margin barely moves by year, department or channel. The real margin differences are by category.
3. **Most customers buy once.** 66.7% of buying customers placed a single order, and nobody placed more than four. 27.9% of registered users never bought.
4. **$6.8M of stock (at cost) is more than a year old and unsold.** 54% of unsold stock value is over two years old.
5. **$2.1M of "Shipped" revenue looks stuck.** Items shipped more than 14 days ago and still not delivered, against a normal delivery time of about 4 days.
6. **Channels, centers and categories look almost identical on conversion, returns and speed.** Differences are within noise. The levers that matter are volume, price mix, stock and retention.

## 4.1 Revenue and profit trends
| Finding | Evidence |
|---|---|
| Steady year-over-year growth | Net revenue: 2020 +227%, 2021 +91%, 2022 +71%, 2023 +76% (full calendar years) |
| 2024 is ahead of every prior pace | Jan 1 to May 13 net revenue $2.16M vs $0.82M in 2023 (+164%); orders 28,168 vs 10,710 (+163%). The 2024 window has one extra day (29 February); per day, revenue growth is about +162% |
| Recent run rate is steeper still | Orders per day: Jan 151, Feb 171, Mar 194, Apr 245, first 13 days of May 434. May is partial, so its month total is not comparable |
| Margin is stable | Net margin 51.8% to 52.1% every year |
| Category margin differs | Accessories 59.9%, Suits and Sport Coats 59.7%, Active 58.1%, Outerwear and Coats 55.6%, Jeans 46.5% |
| Profit concentration | Outerwear and Coats is 13.2% of net profit ($554k), Jeans 10.5% ($441k), Sweaters 7.6% |
| Department mix | Men is 53% to 54% of net revenue each year, although Women has 55% of products |
| Order value is stable | Average order value about $83 to $88 |

So what: growth comes from more orders, not higher prices or better margin. Jeans is the second biggest profit pool but has the thinnest margin, so it is the first place to look for pricing or sourcing gains.

## 4.2 Returns
| Finding | Evidence |
|---|---|
| Return rate is narrow | 11.7% overall; categories range from 10.6% (Women's Socks and Hosiery) to 14.3% (Women's Jumpsuits and Rompers, only 811 items) |
| Cost follows volume and price, not rate | Largest profit lost to returns: Men's Outerwear and Coats $49.1k, Men's Jeans $36.8k, Men's Suits and Sport Coats $36.6k, Men's Sweaters $28.0k |
| Brand differences are small | Among brands with 500+ items: Diesel 14.8% (1,233 items), Anne Klein 14.0%, Orvis 13.5%, Calvin Klein 13.2%. Against 11.7% overall and with 500 to 1,300 items each, gaps of 1 to 2 points are mostly noise; Diesel (about 3 points above average on 1,233 items) is the one brand that stands out |
| Price band barely matters | Rates stay between 11.3% and 12.1%, except Women over $200 at 12.9% (1,862 items) |
| Slow upward drift | 10.7% (2019, small sample) to 11.8% (2022 to 2023) to 12.0% (2024) |
| Returns come back fast | About 1.5 days from delivery to return in both departments |

So what: to cut return losses, target the high-value men's categories (outerwear, jeans, suits) before looking at individual brands.

## 4.3 Cohort retention
| Finding | Evidence |
|---|---|
| Cohorts are growing | New buyers per month: 10 (Jan 2019), 1,129 (Jan 2022), 3,972 (Apr 2024) |
| One-time buyers dominate | 1 order 66.7%, 2 orders 22.9%, 3 orders 6.9%, 4 orders 3.5% (72,096 buying customers) |
| Many users never buy | 27,904 of 100,000 users (27.9%) have no non-cancelled order |
| Monthly repeat-order rate is low but rising | In 2019 to 2021 cohorts, about 1% to 3% of a cohort orders in any later month; in late-2023 and 2024 cohorts, about 5% to 13% in month 1 |
| Repeat rate falls for newer cohorts | 52% (2019 cohort) to 21% (2024), mostly because younger cohorts have had less time to repeat |

Cautions: May 2024 is a partial month, so any cohort cell in May 2024 looks artificially low. Query A in `03_cohort_retention.sql` includes those cells, so exclude activity months of May 2024 when reading it; the Power BI view `vw_cohort_retention` already drops them. Cohorts from 2019 are tiny (10 to 280 customers), so their percentages are noisy.

So what: the cheapest growth lever is the second order. Illustration: turning just 5% of the 48,103 one-time buyers into repeat customers is about 2,400 extra orders, roughly $209k at the 2024 year-to-date average order value of $86.86.

## 4.4 Customer segmentation by recency and frequency (72,096 buying customers)
| Segment | Customers | Share of revenue | Avg orders | Avg days since last order | Avg net spend |
|---|---|---|---|---|---|
| Lost | 27,460 (38.1%) | 30.8% ($2.49M) | 1.2 | 834 | $91 |
| New or recent | 24,244 (33.6%) | 30.4% | 1.3 | 78 | $101 |
| Needs attention | 12,891 (17.9%) | 15.5% | 1.3 | 288 | $97 |
| Loyal | 4,417 (6.1%) | 12.7% | 3.1 | 145 | $234 |
| Champions | 1,705 (2.4%) | 6.4% | 4.0 | 71 | $305 |
| At risk | 1,379 (1.9%) | 4.2% | 3.2 | 642 | $248 |

- Loyal plus Champions are 8.5% of customers but 19.2% of net revenue, spending about three times a typical customer.
- At risk is a small, high-value group (1,379 customers, $342k lifetime net revenue) that stopped buying: the obvious first win-back target.
- Segment shares are almost identical in every country, so country is not a driver here.
- Frequency is capped at four orders, so Champions means "four orders and recent".

## 4.5 Funnel and channels
| Finding | Evidence |
|---|---|
| The funnel is the same in every channel | Product view 100%, cart 63.2% to 63.6%, purchase 26.4% to 26.8% of sessions. Cart to purchase is about 42% everywhere |
| Outcome mix is identical by channel | About 36.7% browse only, 26.5% purchase, 18.4% abandon the cart, 18.3% cancel after carting |
| Channel mix | Email 45% of sessions (306k), Adwords 30%, YouTube 10%, Facebook 10%, Organic 5% |
| Purchase rate "improves" over time | 3.3% (2019), 10.5%, 18%, 27%, 40%, 59% (2024) in every channel |
| Revenue by acquisition channel | Search 70.0% ($5.67M), Organic 14.8%, Facebook 6.1%, Email 5.1%, Display 3.9%. Revenue per customer is $110 to $113 and margin 51.9% in all of them |

Cautions: anonymous sessions never purchase in this dataset, so purchase rate is simply the share of logged-in sessions. The rise from 3% to 59% reflects purchase sessions growing while anonymous browsing sessions stayed roughly level; it should not be presented as conversion improving 18 times. Revenue share by acquisition channel just mirrors how many customers each channel brought (Search is 70% of users). Neither view includes marketing cost, so channel return on spend cannot be judged from this data.

## 4.6 Fulfilment by distribution center
| Finding | Evidence |
|---|---|
| Centers are indistinguishable | Average days to deliver range from about 3.91 to 3.99 across centers (for example Houston 3.91, Memphis 3.99); median about 4 days; 90th percentile 6.1 to 6.3 days |
| About 70% to 72% delivered within 5 days | Best Savannah 72.0%, lowest Memphis 70.3% |
| Flat over time | 3.93 to 3.98 days in every year since 2019 |
| Stuck shipments | 38,149 items have status Shipped with a valid timeline; 35,936 (94%) were shipped more than 14 days before the end of the data, worth $2.14M |
| Cancel and return rates are flat | Cancel 14.5% to 15.5%, return 11.4% to 12.1% by center |
| Bad timelines are everywhere | 29% to 31% of shipped rows have an invalid timeline in every center |

Based on 44,330 delivered items with valid timelines. So what: speed is not a differentiator, so the operational question is the shipped-not-delivered backlog. Either the status is not being updated after delivery, or about $2.1M of net revenue is at risk. Because net revenue counts Shipped items, the Power BI model includes a "Delivered Revenue" sensitivity measure (Complete status only, $2.73M).

## 4.7 Inventory
| Finding | Evidence |
|---|---|
| Large unsold position | 307,284 of 488,146 items unsold, $8.83M at cost |
| It is old | 54.2% older than 2 years ($4.79M), 22.9% 1 to 2 years ($2.03M), only 5.4% under 90 days |
| Sell-through is the same everywhere | 36.9% to 37.9% by category and 36.9% to 37.2% by center |
| Stock that does not sell quickly stays unsold | Items that sell do so in about 30 days regardless of year or category; sell-through by receipt year: 2020 14%, 2021 23%, 2022 34%, 2023 48%, 2024 62% |
| Stock overbuying started in 2020 | Items received in 2018 and 2019 all sold; from 2020 onward, far more stock was received than sold |
| Biggest unsold value by category | Jeans $1.16M, Outerwear and Coats $1.00M, Sweaters $0.68M |
| Biggest unsold value by center | Houston $1.27M, Memphis $1.14M, Chicago $1.10M |
| Largest single products | Men's North Face jackets, about $11k unsold per product id in query E. Their sell-through is normal; they are large because of volume and price. The report's top 10 table groups by product name instead, so its top row (The North Face Apex Bionic Soft Shell Jacket - Men's, 48 items, $21,223) is about twice that, most likely because two catalog entries share the name (see the caveat below) |

Caveat: `sold_at` is set for every order item, including cancelled and returned ones. Net of those, sell-through is 27.8% (135,749 of 488,146; Men 27.8%, Women 27.9%) against 37.1% gross, from query G. Also, one product name (The North Face Denali Down Womens Jacket 2013) appears under two categories with different product ids, which suggests duplicate catalog entries.

So what: stop buying slow categories, clear stock older than one year, and review Jeans and Outerwear first.

## 4.8 KPI procedure
`dw.usp_kpi_summary` compares any date range with the equal-length period immediately before it (not the same period last year). Example: 2024-01-01 to 2024-05-13 against the previous 134 days: net revenue $2.16M vs $1.27M (+70%), margin 51.9% vs 51.9%, average order value $86.86 vs $85.99, return rate 12.0% vs 11.7%. For Women, 2023-01-01 to 2023-05-13: net revenue $371.5k vs $308.2k (+20.5%), return rate 11.4% vs 12.2%. Use query 4.1 B for like-for-like year over year.

## Data caveats
- The dataset is synthetic: uniform patterns (same margin, same conversion, same delivery time everywhere) are a property of the data, not a business result.
- 2024 ends 13 May. The last 13 days run at a much higher daily rate than April, which may reflect how the data was generated.
- 19.6% of order items (35,440) have impossible shipping timelines and are excluded from delivery-time metrics only.
- Net revenue includes Processing and Shipped items; it is not "delivered revenue".

## Recommendations
1. Win back "At risk" customers first (1,379 customers, $342k lifetime), then test a reactivation offer on the 27,460 "Lost" customers ($2.49M lifetime).
2. Push the second order: a post-purchase journey aimed at the 48,103 one-time buyers.
3. Cut buying in slow categories and clear stock older than one year ($6.8M at cost).
4. Investigate the shipped-not-delivered backlog ($2.14M) and fix status updates.
5. Review Jeans pricing and sourcing (46.5% margin, second largest profit pool).
6. Add marketing cost data before judging channels: conversion and returns are identical across them.
