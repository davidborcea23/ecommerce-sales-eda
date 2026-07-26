-- ============================================================
-- Online Retail II - business questions in SQL
-- ============================================================
-- Source: UCI Online Retail II, first sheet (Dec 2009 - Dec 2010, ~525k rows).
-- Loaded into SQLite as table `retail` from pandas, with two changes:
--   - "Customer ID" renamed to CustomerID (no space, easier to query)
--   - Revenue added as Quantity * Price
-- Dialect: SQLite. strftime() and julianday() are SQLite-specific;
-- PostgreSQL uses DATE_TRUNC / EXTRACT and plain date subtraction instead.
-- ============================================================


-- 1. Top 10 products by total revenue.
--    Grouping by StockCode as well as Description: the same product can appear
--    under slightly different descriptions and would otherwise split into two rows.
SELECT
    Description,
    StockCode,
    SUM(Revenue) AS Total_Revenue
FROM retail
GROUP BY Description, StockCode
ORDER BY Total_Revenue DESC
LIMIT 10;


-- 2. Revenue per month, in chronological order.
--    SQLite has no date type - InvoiceDate is ISO text, so the month is extracted
--    as '%Y-%m'. Keeping year and month together makes alphabetical sorting
--    chronological, and stops Dec 2009 and Dec 2010 from collapsing into one group.
SELECT
    strftime('%Y-%m', InvoiceDate) AS year_month,
    SUM(Revenue) AS Sum_rev
FROM retail
GROUP BY year_month
ORDER BY year_month ASC;


-- 3. Number of unique customers per country, keeping only countries above 20.
--    The filter applies after aggregation, so it belongs in HAVING, not WHERE.
SELECT
    Country,
    COUNT(DISTINCT CustomerID) AS dist_customer
FROM retail
GROUP BY Country
HAVING dist_customer > 20;


-- 4. Cancellation rate per country.
--    Cancelled invoices start with 'C'. Counting happens at invoice level, not row
--    level, since one invoice spans many product lines.
--    CASE WHEN inside the aggregate counts selectively without filtering rows away -
--    a WHERE clause would remove the denominator too.
--    The 100.0 multiplier forces floating-point division; integer division returns 0.
--    Add HAVING dist_inv >= 50 to drop countries whose rate rests on a handful of orders.
SELECT
    Country,
    COUNT(DISTINCT Invoice) AS dist_inv,
    COUNT(DISTINCT CASE WHEN Invoice LIKE 'C%' THEN Invoice END) AS dist_inv_neg,
    100.0 * COUNT(DISTINCT CASE WHEN Invoice LIKE 'C%' THEN Invoice END)
          / COUNT(DISTINCT Invoice) AS cancel_rate
FROM retail
GROUP BY Country;


-- 5. Average basket size (average revenue per invoice).
--    Two levels of aggregation are needed: total each invoice first, then average
--    those totals. AVG(Revenue) alone would measure the average product line,
--    not the average order.
--    The substr filter keeps only invoices starting with a digit. This drops both
--    cancellations ('C') and adjustments ('A') with a single rule - a whitelist,
--    which also catches any prefix letter not seen yet.
SELECT AVG(sum_rev) AS avg_basket
FROM (
    SELECT
        Invoice,
        SUM(Revenue) AS sum_rev
    FROM retail
    WHERE substr(Invoice, 1, 1) BETWEEN '0' AND '9'
    GROUP BY Invoice
) AS per_invoice;


-- 6. First and last order per customer, plus days between them.
--    julianday() places a date on a day-numbered axis, so subtracting two of them
--    gives elapsed days directly - across month and year boundaries.
--    strftime would not work here: it extracts a label, it does not measure distance.
--    Customers with a single order return 0, since MIN equals MAX.
SELECT
    CustomerID,
    MIN(InvoiceDate) AS first_order,
    MAX(InvoiceDate) AS last_order,
    julianday(MAX(InvoiceDate)) - julianday(MIN(InvoiceDate)) AS ord_dif
FROM retail
WHERE CustomerID IS NOT NULL
GROUP BY CustomerID;


-- 7. Top 3 products by revenue within each country.
--    LIMIT cannot express "3 per group" - it truncates the whole result once.
--    RANK() with PARTITION BY restarts the ranking for every country.
--    The rank cannot be filtered in WHERE, since it does not exist at that stage,
--    hence the wrapping query.
--    RANK keeps ties on the same position, so a country may return more than 3 rows.
--    ROW_NUMBER() would force exactly 3, but breaks ties arbitrarily.
SELECT *
FROM (
    SELECT
        Country,
        StockCode,
        SUM(Revenue) AS total_rev,
        RANK() OVER (PARTITION BY Country ORDER BY SUM(Revenue) DESC) AS rang
    FROM retail
    GROUP BY Country, StockCode
) AS ranked
WHERE rang <= 3;


-- 8. Cumulative revenue by month (running total).
--    No PARTITION BY: there is a single series, so the sum accumulates across all
--    months instead of resetting. The final row equals SUM(Revenue) over the table.
SELECT
    year_month,
    revenue_lunar,
    SUM(revenue_lunar) OVER (ORDER BY year_month) AS cumulativ
FROM (
    SELECT
        strftime('%Y-%m', InvoiceDate) AS year_month,
        SUM(Revenue) AS revenue_lunar
    FROM retail
    GROUP BY year_month
) AS monthly;


-- 9. Month-over-month change in spend, per customer.
--    LAG() looks exactly one row back, unlike the running total above which sees
--    everything before it. PARTITION BY CustomerID stops it from borrowing the
--    previous customer's value.
--    Each customer's first month returns NULL - there is nothing to subtract from.
--    LAG is written twice because an alias cannot be reused inside the same SELECT.
SELECT
    CustomerID,
    luna,
    suma,
    LAG(suma) OVER (PARTITION BY CustomerID ORDER BY luna) AS luna_anterioara,
    suma - LAG(suma) OVER (PARTITION BY CustomerID ORDER BY luna) AS diferenta
FROM (
    SELECT
        CustomerID,
        strftime('%Y-%m', InvoiceDate) AS luna,
        SUM(Revenue) AS suma
    FROM retail
    WHERE CustomerID IS NOT NULL
    GROUP BY CustomerID, luna
) AS per_month;


-- 10. Customers who bought in the first month of the dataset and never returned.
--     If a customer's last month equals the dataset's first month, that was their
--     only month. MIN inside a grouped query would return each customer's own first
--     month, not the dataset's - so the comparison value comes from a scalar
--     subquery, which runs without GROUP BY and therefore sees the whole table.
--     Returns 125 customers out of 4384.
SELECT
    CustomerID,
    MAX(strftime('%Y-%m', InvoiceDate)) AS luna_max
FROM retail
WHERE CustomerID IS NOT NULL
GROUP BY CustomerID
HAVING MAX(strftime('%Y-%m', InvoiceDate)) = (
    SELECT MIN(strftime('%Y-%m', InvoiceDate)) FROM retail
);