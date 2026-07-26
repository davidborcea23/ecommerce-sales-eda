# Online Retail II — Exploratory Data Analysis

EDA of the **Online Retail II** dataset (UK online gift retailer), done as a week-2
learning project to practice `pandas`, `matplotlib` and `seaborn`.

## Dataset

- **Source:** [UCI Machine Learning Repository — Online Retail II](https://archive.ics.uci.edu/dataset/502/online+retail+ii)
- This analysis uses the **2009–2010** sheet: `525,461` rows × `8` columns.
- Columns: `Invoice`, `StockCode`, `Description`, `Quantity`, `InvoiceDate`, `Price`, `Customer ID`, `Country`.

> The raw `.xlsx` file (~45 MB) is **not** committed to the repo (see `.gitignore`).
> Download it from the link above and place it at:
> `online+retail+ii/online_retail_II.xlsx`

## What the notebook covers

**Phase 1 — Orientation:** unique counts (28,816 orders, 4,632 products, 4,383 customers, 40 countries).

**Phase 2 — Univariate:** orders per country, most frequent products, distribution of `Quantity` and
`Price` (incl. checking for zero/negative prices), and the time span of the data
(`2009-12-01` → `2010-12-09`).

**Phase 3 — Data quality:** missing values (`Description`: 2,928, `Customer ID`: 107,927),
duplicate rows, and negative quantities — split into **cancellations** (invoices starting with `C`)
vs **internal adjustments** (damages, lost stock, etc.).

**Phase 4 — Relationships & insights:** a new `Revenue = Quantity × Price` column, top products and
top countries by revenue, and the monthly revenue trend.

**Extra:** outlier hunting on `Quantity`, the same conclusions plotted with both `matplotlib` and
`seaborn`, a correlation heatmap, and business questions (cancellation rate, wholesale vs retail,
top customers).

## Key findings

- Revenue is **heavily dominated by the United Kingdom**; all other markets are comparatively small.
- Revenue is **seasonal**, rising toward the autumn/winter months (pre-Christmas peak).
- Part of the top "revenue" comes from **shipping/postage**, not goods.
- A large share of transactions has **no `Customer ID`**, which limits customer-level analysis.

## SQL analysis

The same dataset was loaded into SQLite and analysed with SQL, as a counterpart to the
pandas exploration above. Queries are in `sql/queries.sql`, covering aggregation,
conditional counting, subqueries and window functions (`RANK` with `PARTITION BY`,
running totals, `LAG`).

The database is built from the same `.xlsx`, adding a `Revenue` column and renaming
`Customer ID` to `CustomerID`; it is not committed (see `.gitignore`).

Selected findings:

- **Revenue is strongly seasonal.** Monthly revenue grows from ~854k in September 2010
  to ~1.42M in November, then drops — the last month is partial, not a decline.
- **Cancellation rates vary widely by country.** Germany cancels 32% of invoices against
  15% for the UK, measured at invoice level rather than per product line.
- **The dataset is effectively UK plus noise.** The UK accounts for 4,035 of the distinct
  customers; no other country exceeds 70.
- **Average order value is ~425**, after excluding cancellations and adjustment invoices.
- **125 customers bought only in the first month and never returned** — under 3% of the
  customer base, which is the population a churn model has to identify.

## How to run

```bash
# 1. install dependencies
pip install -r requirements.txt

# 2. download the dataset (see "Dataset" above) into online+retail+ii/

# 3. open the notebook
jupyter notebook eda.ipynb
```

## Files

- `eda.ipynb` — the full exploratory analysis
- `sql/queries.sql` — the same dataset analysed in SQL
- `requirements.txt` — Python dependencies
- `.gitignore` — excludes the dataset and local artifacts
