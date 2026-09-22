/* ============================================================================
   SQL SERVER (T-SQL): FROM BASICS TO ADVANCED FOR DATA ENGINEERS
   ============================================================================
   TABLE OF CONTENTS
     3.  Basic querying - SELECT, WHERE, ORDER BY, DISTINCT, TOP
     4.  NULLs - ISNULL, COALESCE, NULLIF, three-valued logic
     5.  Aggregates & GROUP BY / HAVING (incl. COUNT(*) vs COUNT(col))
     6.  String functions
     7.  Date/time functions
     8.  CASE expressions
     9.  Joins (INNER/LEFT/RIGHT/FULL/CROSS/SELF, anti-joins)
     10. Subqueries, EXISTS, IN pitfalls, CROSS/OUTER APPLY
     11. Set operators - UNION / UNION ALL / INTERSECT / EXCEPT
     12. CTEs, incl. recursive CTE -> date dimension table
     13. Views
     14. Window functions
     15. PIVOT / UNPIVOT
     16. Temp tables vs table variables vs CTEs vs views
     17. Indexes & reading basic performance signals
     18. Stored procedures
     19. User-defined functions (scalar + inline table-valued)
     20. Triggers
     21. Transactions & error handling (TRY/CATCH)
     22. MERGE - the upsert pattern used in ETL/ELT
     23. Deduplication / "gaps and islands" style DE patterns
     24. Performance & interview-gotcha cheat sheet
*/


-- Section:3 Basic Querying
-- SELECT specific columns, alias with AS
SELECT CustomerID, CustomerName AS Name, Country
FROM retail.Customers;

-- WHERE with comparison / logical operators
SELECT * FROM retail.Products WHERE UnitPrice > 50 AND Category = 'Electronics';

-- BETWEEN, IN, LIKE
SELECT * FROM retail.Products WHERE UnitPrice BETWEEN 15 AND 30; -- shows all where UnitPrice is 15 to 30
SELECT * FROM retail.Customers WHERE Country IN ('United Kingdom', 'Canada', 'Germany'); -- shows customers from United Kingdom, Canada, Germany
SELECT * FROM retail.Products WHERE ProductName LIKE 'Wireless%';   -- shows where product name starts with "Wireless"
SELECT * FROM retail.Products WHERE ProductName LIKE '%Set%';       -- shows product names that contain letters "Set" anywhere
SELECT * FROM retail.Customers WHERE CustomerName LIKE '_a%';       -- shows all where 2nd letter is 'a'

-- ORDER BY: ASC is the default, multiple keys allowed
SELECT ProductName, Category, UnitPrice
FROM retail.Products
ORDER BY Category ASC, UnitPrice DESC;

-- DISTINCT
SELECT DISTINCT Category FROM retail.Products;

-- TOP N / TOP N PERCENT / TOP N WITH TIES
SELECT TOP (5) ProductName, UnitPrice FROM retail.Products ORDER BY UnitPrice DESC; -- Top 5 Product by highest price
SELECT TOP (10) PERCENT ProductName, UnitPrice FROM retail.Products ORDER BY UnitPrice DESC; -- Top 10% products by highest price
SELECT TOP (3) WITH TIES ProductName, UnitPrice FROM retail.Products ORDER BY UnitPrice DESC; --TOP (N) WITH TIES can return more than $N$ rows if there are matching values at the cutoff boundary. 

-- OFFSET-FETCH: the standard way to paginate (requires ORDER BY)
SELECT ProductName, UnitPrice
FROM retail.Products
ORDER BY ProductID
OFFSET 5 ROWS FETCH NEXT 5 ROWS ONLY;   -- It will shows the records after first 5 rows to next 5 rows which means 6th to 10th.


-- SECTION 4: NULLS
-- NULL means "unknown" - it is never equal to anything, not even another NULL.
SELECT * FROM retail.Customers WHERE City IS NULL;
SELECT * FROM retail.Customers WHERE City IS NOT NULL;

-- ISNULL (SQL Server only, 2 arguments, returns all records where Nulls are converted into Unknown)
SELECT CustomerName, ISNULL(City, 'Unknown') AS City FROM retail.Customers;

-- COALESCE (ANSI standard, any number of arguments, returns the highest-precedence type)
-- Prefer COALESCE in portable/production code.
SELECT CustomerName, COALESCE(City, 'Unknown') AS City FROM retail.Customers;

-- NULLIF: returns NULL if the two expressions are equal, otherwise the first expression.
-- Classic use: avoid divide-by-zero.
SELECT
    ProductID,
    StockQuantity,
    100 / NULLIF(StockQuantity, 0) AS SomeRatio   -- would error on / 0 without NULLIF
FROM retail.Products;

-- Using NOT IN with a NULL in the list silently returns ZERO rows for everything.
SELECT * FROM retail.Customers
WHERE Country NOT IN (SELECT City FROM retail.Customers);   -- returns ZERO rows, because City contains NULLs

-- NOT EXISTS is NULL-safe and gives the answer you actually wanted:
SELECT c.*
FROM retail.Customers c
WHERE NOT EXISTS (SELECT 1 FROM retail.Customers c2 WHERE c2.City = c.Country);   -- returns rows normally


-- SECTION 5: AGGREGATES, GROUP BY, HAVING
-- Difference between COUNT(*) vs COUNT(column) vs COUNT(DISTINCT column)
SELECT
    COUNT(*)              AS TotalRows,        -- counts every row, even NULLs included
    COUNT(City)            AS RowsWithCity,     -- counts only non-NULL City values
    COUNT(DISTINCT Country) AS DistinctCountries -- counts unique non-NULL values
FROM retail.Customers;

-- SUM / AVG / MIN / MAX
SELECT
    SUM(Quantity)         AS TotalUnitsSold,
    AVG(Quantity) AS AvgUnitsPerOrder, 
    MIN(OrderDate)         AS FirstOrder,
    MAX(OrderDate)         AS LastOrder
FROM retail.Orders;

-- GROUP BY: one row per unique combination of the grouped columns
SELECT Status, COUNT(*) AS OrderCount
FROM retail.Orders
GROUP BY Status
ORDER BY OrderCount DESC;

-- WHERE filters rows BEFORE grouping; HAVING filters groups AFTER aggregation.

SELECT
    p.Category,
    SUM(o.Quantity * p.UnitPrice) AS Revenue
FROM retail.Orders o
JOIN retail.Products p ON p.ProductID = o.ProductID
WHERE o.Status = 'Completed'          -- row-level filter, applied first
GROUP BY p.Category
HAVING SUM(o.Quantity * p.UnitPrice) > 3000   -- group-level filter, applied after SUM()
ORDER BY Revenue DESC;

-- ROLLUP: adds subtotal + grand-total rows - handy for BI summary tables/Power BI exports
SELECT
    p.Category,
    SUM(o.Quantity * p.UnitPrice) AS Revenue
FROM retail.Orders o
JOIN retail.Products p ON p.ProductID = o.ProductID
WHERE o.Status = 'Completed'
GROUP BY ROLLUP (p.Category)
ORDER BY GROUPING(p.Category), p.Category;   -- GROUPING() = 1 marks the rolled-up total row


-- SECTION 6: STRING FUNCTIONS   
SELECT
    ProductName,
    LEN(ProductName)                       AS NameLength,
    UPPER(ProductName)                     AS Upper,
    LOWER(ProductName)                     AS Lower,
    LEFT(ProductName, 5)                   AS First5,
    RIGHT(ProductName, 5)                  AS Last5,
    SUBSTRING(ProductName, 1, 3)           AS FirstThreeChars,
    REPLACE(ProductName, 'Wireless', 'W/L') AS Replaced,
    CHARINDEX('Set', ProductName)          AS PositionOfSet,   -- 0 if not found
    CONCAT(ProductName, ' - ', Category)   AS Combined,
    CONCAT_WS(' | ', ProductName, Category, CAST(UnitPrice AS VARCHAR(20))) AS ConcatWithSeparator,
    TRIM('  padded value  ')               AS Trimmed --removes unnecessary spaces from both end         
FROM retail.Products;

-- STRING_AGG: write all rows into one delimited string 
SELECT Category, STRING_AGG(ProductName, ', ') WITHIN GROUP (ORDER BY ProductName) AS ProductsInCategory
FROM retail.Products
GROUP BY Category;

-- STRING_SPLIT: the reverse - turn a delimited string into rows
SELECT value AS Tag FROM STRING_SPLIT('Electronics,Books,Clothing', ',');


-- SECTION 7: DATE/TIME FUNCTIONS
  
SELECT 
    GETDATE() AS NOW,                                      -- Current system date and timestamp (e.g., 2026-09-22 01:23:36.000)
    FORMAT(GETDATE(), 'yyyy-MM-dd') AS IsoFormatted,       -- Formats date as ISO string ('2026-09-22')
    FORMAT(GETDATE(), 'MM-dd-yyyy') AS US_format,          -- Formats date as US string ('09-22-2026')
    CAST(GETDATE() AS DATE) AS TODAY,                      -- Strips time part, returns DATE type (2026-09-22)
    DATEPART(YEAR, CAST(GETDATE() AS DATE)) AS YEAR1,      -- Extracts year integer using DATEPART (2026)
    YEAR(GETDATE()) AS YEAR2,                              -- Shorthand approach to extract year (2026)
    DATEPART(MONTH, CAST(GETDATE() AS DATE)) AS MONTH,     -- Extracts month number using DATEPART (9)
    MONTH(GETDATE()) AS MONTH2,                            -- Shorthand approach to extract month number (9)
    DATENAME(MONTH, GETDATE()) AS MonthName1,              -- Full month name as string ('September')
    FORMAT(GETDATE(), 'MMMM') AS MonthName2,               -- Full month name via format ('September')
    FORMAT(GETDATE(), 'MMM') AS MonthName3,                -- Abbreviated month name via format ('Sep')
    DATENAME(WEEKDAY, GETDATE()) AS DayName1,              -- Full day name as string ('Tuesday')
    FORMAT(GETDATE(), 'dddd') AS DayName2,                 -- Full day name via format ('Tuesday')
    FORMAT(GETDATE(), 'ddd') AS DayName3,                  -- Abbreviated day name via format ('Tue')
    DATEPART(DAY, CAST(GETDATE() AS DATE)) AS DAY1,        -- Extracts day of the month using DATEPART (22)
    DAY(GETDATE()) AS DAY2,                                -- Shorthand approach to extract day of the month (22)
    DATEPART(QUARTER, CAST(GETDATE() AS DATE)) AS QUARTER, -- Returns quarter of the year 1-4 (3)
    DATEPART(WEEK, CAST(GETDATE() AS DATE)) AS Week,       -- Returns week number of the year 1-53 (39)
    DATEPART(WEEKDAY, CAST(GETDATE() AS DATE)) AS Weekday, -- Day of week index based on DATEFIRST (3 if Sun=1, Mon=2, Tue=3)
    DATEADD(DAY, 30, GETDATE()) AS In30Days,               -- Adds 30 days to current timestamp (2026-10-22)
    DATEADD(MONTH, 2, GETDATE()) AS In2Months,             -- Adds 2 months to current timestamp (2026-11-22)
    DATEADD(YEAR, 3, GETDATE()) AS In3Years,               -- Adds 3 years to current timestamp (2029-09-22)
    DATEDIFF(DAY, '2026-09-20', GETDATE()) AS DAY_DIFF,    -- Days elapsed since target date (2)
    DATEDIFF(MONTH, '2026-08-20', GETDATE()) AS MONTH_DIFF,-- Month boundaries crossed since target date (1)
    DATEDIFF(YEAR, '2025-09-20', GETDATE()) AS YEAR_DIFF,  -- Year boundaries crossed since target date (1)
    DATETRUNC(MONTH, GETDATE()) AS TRUNC_MONTH,            -- Truncates to start of current month (2026-09-01 00:00:00.000)
    DATETRUNC(YEAR, GETDATE()) AS TRUNC_YEAR;              -- Truncates to start of current year (2026-01-01 00:00:00.000)


--SECTION 8: CASE EXPRESSIONS

SELECT
    ProductName,
    UnitPrice,
    CASE
        WHEN UnitPrice < 20  THEN 'Budget'
        WHEN UnitPrice < 60  THEN 'Mid-range'
        WHEN UnitPrice < 100 THEN 'Premium'
        ELSE 'Luxury'
    END AS PriceTier
FROM retail.Products;


--SECTION 9: JOINS
-- INNER JOIN: only rows with a match on both sides
SELECT o.OrderID, c.CustomerName, p.ProductName, o.Quantity, o.OrderDate
FROM retail.Orders o
INNER JOIN retail.Customers c ON c.CustomerID = o.CustomerID
INNER JOIN retail.Products  p ON p.ProductID  = o.ProductID;

-- LEFT (OUTER) JOIN: all rows from the left table, matched columns NULL when no match
-- Use case: find customers who have never placed an order
SELECT c.CustomerID, c.CustomerName, o.OrderID
FROM retail.Customers c
LEFT JOIN retail.Orders o ON o.CustomerID = c.CustomerID
WHERE o.OrderID IS NULL;         

-- RIGHT (OUTER) JOIN: mirror of LEFT - rarely used in practice, just flip the tables instead
SELECT p.ProductName, o.OrderID
FROM retail.Orders o
RIGHT JOIN retail.Products p ON p.ProductID = o.ProductID
WHERE o.OrderID IS NULL;         -- products that were never ordered

-- FULL OUTER JOIN: everything from both sides, matched where possible
SELECT c.CustomerName, o.OrderID
FROM retail.Customers c
FULL OUTER JOIN retail.Orders o ON o.CustomerID = c.CustomerID;

-- CROSS JOIN: cartesian product - every row from A with every row from B.
-- Legitimate uses: generating combinations, calendar spines
SELECT c.Country, p.Category
FROM (SELECT DISTINCT Country FROM retail.Customers) c
CROSS JOIN (SELECT DISTINCT Category FROM retail.Products) p;

-- SELF JOIN: join a table to itself - here, find product pairs in the same category
-- where one is more than double the price of the other
SELECT
    p1.ProductName AS CheaperProduct,
    p2.ProductName AS PricierProduct,
    p1.Category
FROM retail.Products p1
JOIN retail.Products p2
    ON p1.Category = p2.Category
   AND p1.ProductID < p2.ProductID          -- avoid duplicate/mirrored pairs and self-pairing
WHERE p2.UnitPrice > p1.UnitPrice * 2;

-- NOT EXISTS anti-join (usually the best-performing way to say "has no match")
SELECT c.CustomerID, c.CustomerName
FROM retail.Customers c
WHERE EXISTS (SELECT 1 FROM retail.Orders o WHERE o.CustomerID = c.CustomerID);


-- SECTION 10: SUBQUERIES, IN, NOT IN, EXISTS, NOT EXISTS
-- Scalar subquery in SELECT (must return exactly one value)

SELECT
    ProductName,
    UnitPrice,
    (SELECT AVG(UnitPrice) FROM retail.Products) AS OverallAvgPrice,
    UnitPrice - (SELECT AVG(UnitPrice) FROM retail.Products) AS DiffFromAvg
FROM retail.Products;

-- Subquery in WHERE with IN
SELECT CustomerName
FROM retail.Customers
WHERE CustomerID IN (SELECT CustomerID FROM retail.Orders WHERE Status = 'Cancelled');


-- Correlated subquery: inner query correlated with outer query (can be slow on large tables -
-- compare its plan against the JOIN/window-function equivalents shown later)
SELECT c.CustomerName,
       (SELECT COUNT(*) FROM retail.Orders o WHERE o.CustomerID = c.CustomerID) AS OrderCount
FROM retail.Customers c;

-- EXISTS: stops at the first match, doesn't materialize values - generally the fastest
-- way to answer "does at least one related row exist?"
SELECT c.CustomerName
FROM retail.Customers c
WHERE EXISTS (SELECT 1 FROM retail.Orders o WHERE o.CustomerID = c.CustomerID AND o.Status = 'Returned');

-- Derived table (subquery in FROM) - must have an alias
SELECT Category, AvgPrice
FROM (
    SELECT Category, AVG(UnitPrice) AS AvgPrice
    FROM retail.Products
    GROUP BY Category
) AS CategoryAverages
WHERE AvgPrice > 30;

-- CROSS APPLY: like INNER JOIN, but the right side can reference columns from the left -
-- perfect for "top N per group" queries. Here: each customer's 2 most recent orders.
-- You can get the same result using window function i.e ROW_NUMBER()

SELECT c.CustomerID, c.CustomerName, oa.OrderID, oa.OrderDate, oa.Quantity
FROM retail.Customers c
CROSS APPLY (
    SELECT TOP (2) o.OrderID, o.OrderDate, o.Quantity
    FROM retail.Orders o
    WHERE o.CustomerID = c.CustomerID
    ORDER BY o.OrderDate DESC
) AS oa
ORDER BY c.CustomerID, oa.OrderDate DESC;

   
--SECTION 11: SET OPERATORS
-- UNION removes duplicates (implicit DISTINCT across the combined set - costs a sort/hash)
SELECT City AS Location FROM retail.Customers WHERE City IS NOT NULL
UNION
SELECT Country FROM retail.Customers;

-- UNION ALL keeps duplicates - cheaper, and the right choice whenever you know
-- the two sets can't overlap (e.g. stacking monthly partitions)
SELECT City AS Location FROM retail.Customers WHERE City IS NOT NULL
UNION ALL
SELECT Country FROM retail.Customers;

-- INTERSECT: rows present in both sets
SELECT ProductID FROM retail.Products WHERE Category = 'Electronics'
INTERSECT
SELECT ProductID FROM retail.Orders WHERE Status = 'Returned';

-- EXCEPT: rows in the first set, not in the second (order matters!)
SELECT ProductID FROM retail.Products
EXCEPT
SELECT ProductID FROM retail.Orders;   -- products that have never been ordered

--SECTION 12: CTEs (COMMON TABLE EXPRESSIONS)
-- Basic CTE: named, temporary result set, scoped to the one statement that follows it
WITH CompletedOrders AS
(
    SELECT * FROM retail.Orders WHERE Status = 'Completed'
)
SELECT CustomerID, COUNT(*) AS CompletedOrderCount
FROM CompletedOrders
GROUP BY CustomerID
ORDER BY CompletedOrderCount DESC;

-- Multiple, chained CTEs - each can reference the ones defined before it.
-- This is the readable alternative to nesting nine subqueries inside each other.
WITH OrderValues AS
(
    SELECT o.OrderID, o.CustomerID, o.Quantity * p.UnitPrice AS LineTotal
    FROM retail.Orders o
    JOIN retail.Products p ON p.ProductID = o.ProductID
    WHERE o.Status = 'Completed'
),
CustomerTotals AS
(
    SELECT CustomerID, SUM(LineTotal) AS TotalSpend
    FROM OrderValues
    GROUP BY CustomerID
)
SELECT c.CustomerName, ct.TotalSpend
FROM CustomerTotals ct
JOIN retail.Customers c ON c.CustomerID = ct.CustomerID
ORDER BY ct.TotalSpend DESC;

-- RECURSIVE CTE: a CTE that calls/references itself. 
-- Anchor member  UNION ALL  recursive member (with a stopping condition)
-- Let's make a list from 1 to 10:

WITH Numbers AS(
    SELECT 1 AS number                                  -- anchor member
    UNION ALL
    SELECT number + 1 FROM Numbers WHERE number < 10    -- recursive step + stop condition
)
SELECT number FROM Numbers 
OPTION (MAXRECURSION 0);                                -- Disables the safety limit on recursion depth, allowing infinite iterations (default limit is 100)

-- Practical version: build a DATE DIMENSION table spanning the order history.(We'll keep this inside a table.)
-- This is a genuinely common data engineering task (every warehouse needs a calendar table).
-- Default MAXRECURSION is 100 which we will set to zero - our range can exceed that, so it must be raised.

IF OBJECT_ID('retail.DateDimension', 'U') IS NOT NULL 
    DROP TABLE retail.DateDimension;

DECLARE @startdate DATE = (SELECT CAST(MIN(OrderDate) AS DATE) FROM retail.Orders WITH (NOLOCK));
DECLARE @enddate   DATE = (SELECT CAST(MAX(OrderDate) AS DATE) FROM retail.Orders WITH (NOLOCK));

WITH DateSeries AS (
    SELECT @startdate AS CalenderDate
    UNION ALL
    SELECT DATEADD(DAY, 1, CalenderDate)
    FROM DateSeries
    WHERE CalenderDate < @enddate
)
SELECT 
    CalenderDate,
    YEAR(CalenderDate)              AS CalenderYear,
    MONTH(CalenderDate)             AS CalenderMonth,
    DATENAME(MONTH, CalenderDate)   AS MonthName,
    DATENAME(WEEKDAY, CalenderDate) AS DayName,
    CASE WHEN DATENAME(WEEKDAY, CalenderDate) IN ('Saturday', 'Sunday') THEN 1 ELSE 0 END AS IsWeekend
INTO retail.DateDimension
FROM DateSeries
OPTION (MAXRECURSION 0);

SELECT * FROM retail.DateDimension ;

-- SECTION 13: VIEWS
   
-- A view is a saved, named query - it doesn't store data itself (unless indexed,
-- see the note below). Great for hiding join complexity from downstream consumers
-- (e.g. Power BI connecting straight to a clean, documented view instead of raw tables).

GO
CREATE VIEW retail.vw_OrderDetails
AS
SELECT
    o.OrderID,
    c.CustomerName,
    c.Country,
    p.ProductName,
    p.Category,
    o.Quantity,
    p.UnitPrice,
    o.Quantity * p.UnitPrice AS LineTotal,
    o.OrderDate,
    o.Status
FROM retail.Orders o
JOIN retail.Customers c ON c.CustomerID = o.CustomerID
JOIN retail.Products  p ON p.ProductID  = o.ProductID;
GO

SELECT * FROM retail.vw_OrderDetails WHERE Status = 'Completed' ORDER BY LineTotal DESC;

GO
CREATE VIEW retail.vw_CustomerLifetimeValue
AS
SELECT
    c.CustomerID,
    c.CustomerName,
    COUNT(o.OrderID)                                   AS TotalOrders,
    SUM(CASE WHEN o.Status = 'Completed' THEN o.Quantity * p.UnitPrice ELSE 0 END) AS LifetimeValue
FROM retail.Customers c
LEFT JOIN retail.Orders o  ON o.CustomerID = c.CustomerID
LEFT JOIN retail.Products p ON p.ProductID = o.ProductID
GROUP BY c.CustomerID, c.CustomerName;
GO

SELECT * FROM retail.vw_CustomerLifetimeValue ORDER BY LifetimeValue DESC;


/* SECTION 14: WINDOW FUNCTIONS
    The single most powerful feature for analytics SQL. OVER() lets a function see
    other rows related to the current one, WITHOUT collapsing the result like GROUP BY does.*/

-- ROW_NUMBER / RANK / DENSE_RANK - the differences show up on ties
SELECT
    ProductName,
    Category,
    UnitPrice,
    ROW_NUMBER() OVER (PARTITION BY Category ORDER BY UnitPrice DESC) AS RowNum,   -- always unique, no gaps
    RANK()       OVER (PARTITION BY Category ORDER BY UnitPrice DESC) AS Rank_,     -- ties share a rank, gaps after
    DENSE_RANK() OVER (PARTITION BY Category ORDER BY UnitPrice DESC) AS DenseRank_ -- ties share a rank, no gaps
FROM retail.Products;

-- NTILE: split rows into N roughly-equal buckets - e.g. quartile customers by spend
WITH Spend AS
(
    SELECT CustomerID, SUM(Quantity) AS TotalUnits
    FROM retail.Orders
    WHERE Status = 'Completed'
    GROUP BY CustomerID
)
SELECT CustomerID, TotalUnits, NTILE(4) OVER (ORDER BY TotalUnits DESC) AS SpendQuartile
FROM Spend;

-- LAG / LEAD: look at the previous/next row without a self-join
SELECT
    CustomerID,
    OrderID,
    OrderDate,
    LAG(OrderDate)  OVER (PARTITION BY CustomerID ORDER BY OrderDate) AS PreviousOrderDate,
    DATEDIFF(DAY,
        LAG(OrderDate) OVER (PARTITION BY CustomerID ORDER BY OrderDate),
        OrderDate
    ) AS DaysSincePreviousOrder,
    LEAD(OrderDate) OVER (PARTITION BY CustomerID ORDER BY OrderDate) AS NextOrderDate
FROM retail.Orders;

-- Running total: a frame clause (ROWS BETWEEN ...) controls exactly which rows are summed
SELECT
    CustomerID,
    OrderDate,
    Quantity,
    SUM(Quantity) OVER (
        PARTITION BY CustomerID
        ORDER BY OrderDate
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS RunningTotalUnits
FROM retail.Orders;


-- Moving average over the current row and the 2 preceding rows
SELECT
    CustomerID,
    OrderDate,
    Quantity,
    AVG(CAST(Quantity AS DECIMAL(5,2))) OVER (
        PARTITION BY CustomerID
        ORDER BY OrderDate
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS MovingAvg3
FROM retail.Orders;

-- FIRST_VALUE / LAST_VALUE (LAST_VALUE needs an explicit frame to behave as expected)
SELECT DISTINCT
    CustomerID,
    FIRST_VALUE(OrderDate) OVER (PARTITION BY CustomerID ORDER BY OrderDate
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS FirstOrderDate,
    LAST_VALUE(OrderDate) OVER (PARTITION BY CustomerID ORDER BY OrderDate
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS LastOrderDate
FROM retail.Orders;

-- PERCENT_RANK / CUME_DIST: relative standing within the partition, 0..1
SELECT
    ProductName,
    UnitPrice,
    PERCENT_RANK() OVER (ORDER BY UnitPrice) AS PercentRank,  -- percentage of items cheaper than specific percentage
    CUME_DIST()    OVER (ORDER BY UnitPrice) AS CumulativeDist --percentage of items below specific cumulative distribution value
FROM retail.Products;

-- IMPORTANT: window functions cannot be referenced directly in WHERE (they're computed
-- during the SELECT phase, after WHERE runs). Wrap in a CTE/subquery and filter outside.
-- Practical example: best-selling product per category by revenue.
WITH RankedRevenue AS
(
    SELECT
        p.Category,
        p.ProductName,
        SUM(o.Quantity * p.UnitPrice) AS Revenue,
        ROW_NUMBER() OVER (PARTITION BY p.Category ORDER BY SUM(o.Quantity * p.UnitPrice) DESC) AS rn
    FROM retail.Orders o
    JOIN retail.Products p ON p.ProductID = o.ProductID
    WHERE o.Status = 'Completed'
    GROUP BY p.Category, p.ProductName
)
SELECT Category, ProductName, Revenue
FROM RankedRevenue
WHERE rn = 1
ORDER BY Category;


--SECTION 15: PIVOT / UNPIVOT

-- PIVOT: turn row values (Category) into columns, aggregating as it goes.
-- Column names with spaces/special characters need [bracket] quoting.
SELECT *
INTO #CategoryPivot
FROM
(
    SELECT p.Category, YEAR(o.OrderDate) AS OrderYear, o.Quantity
    FROM retail.Orders o
    JOIN retail.Products p ON p.ProductID = o.ProductID
    WHERE o.Status = 'Completed'
) AS src
PIVOT
(
    SUM(Quantity)
    FOR Category IN ([Electronics], [Home & Kitchen], [Books], [Clothing], [Sports & Outdoors])
) AS pvt;

SELECT * FROM #CategoryPivot ORDER BY OrderYear;


-- UNPIVOT: reverse it - columns back into rows
SELECT OrderYear, Category, TotalQuantity
FROM #CategoryPivot
UNPIVOT
(
    TotalQuantity FOR Category IN ([Electronics], [Home & Kitchen], [Books], [Clothing], [Sports & Outdoors])
) AS unpvt
ORDER BY OrderYear, Category;


DROP TABLE #CategoryPivot;


-- SECTION 16: TEMP TABLES vs CTEs vs VIEWS
/* CTE            - inline, exists only for the one statement, no indexes of its own,
                    easiest to read for a linear pipeline of transformations.
   Temp table     - scoped to the session (# ) or globally (## ), supports indexes,
                    constraints, and full statistics - best choice for large
                    intermediate result sets reused across several statements.
   View           - persisted definition, reusable across sessions/users, no data
                    of its own unless indexed. */

CREATE TABLE #HighValueCustomers
(
    CustomerID INT PRIMARY KEY,
    TotalSpend DECIMAL(12,2)
);

INSERT INTO #HighValueCustomers
SELECT o.CustomerID, SUM(o.Quantity * p.UnitPrice)
FROM retail.Orders o
JOIN retail.Products p ON p.ProductID = o.ProductID
WHERE o.Status = 'Completed'
GROUP BY o.CustomerID
HAVING SUM(o.Quantity * p.UnitPrice) > 500;

SELECT * FROM #HighValueCustomers ORDER BY TotalSpend DESC;

DROP TABLE #HighValueCustomers;


--SECTION 17: INDEXES & READING BASIC PERFORMANCE SIGNALS
   
-- The primary key already created a clustered index (the table's physical row order).
-- Add nonclustered indexes for the columns you filter/join on frequently.
CREATE NONCLUSTERED INDEX IX_Orders_CustomerID_OrderDate
    ON retail.Orders (CustomerID, OrderDate)
    INCLUDE (Quantity, Status);    -- "covering" columns: satisfies the query without a lookup
GO

CREATE NONCLUSTERED INDEX IX_Orders_ProductID ON retail.Orders (ProductID);
GO

-- SET STATISTICS IO/TIME are your first line of performance diagnosis - always
-- cheaper than guessing. Compare "logical reads" before/after adding an index.
SET STATISTICS IO ON;
SELECT OrderID, OrderDate, Quantity, Status
FROM retail.Orders
WHERE CustomerID = 7
ORDER BY OrderDate;
SET STATISTICS IO OFF;


--SECTION 18: STORED PROCEDURES

GO
CREATE PROCEDURE retail.usp_GetCustomerOrderSummary
    @CustomerID   INT,
    @MinOrderDate DATE = '2000-01-01',   -- optional parameter with a default
    @TotalOrders  INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;   -- suppresses the "(N rows affected)" messages - standard practice in procs

    SELECT o.OrderID, p.ProductName, o.Quantity, o.OrderDate, o.Status
    FROM retail.Orders o
    JOIN retail.Products p ON p.ProductID = o.ProductID
    WHERE o.CustomerID = @CustomerID
      AND o.OrderDate >= @MinOrderDate
    ORDER BY o.OrderDate DESC;

    SELECT @TotalOrders = COUNT(*)
    FROM retail.Orders
    WHERE CustomerID = @CustomerID;
END;
GO

-- Usage
DECLARE @Count INT;
EXEC retail.usp_GetCustomerOrderSummary @CustomerID = 5, @TotalOrders = @Count OUTPUT;
SELECT @Count AS TotalOrdersForCustomer5;


-- SECTION 19: USER-DEFINED FUNCTIONS

GO
CREATE FUNCTION retail.fn_CalculateLineTotal (@Quantity INT, @UnitPrice DECIMAL(10,2))
RETURNS DECIMAL(12,2)
AS
BEGIN
    RETURN @Quantity * @UnitPrice;
END;
GO

SELECT 
    o.OrderID, o.CustomerID, o.ProductID,
    o.Quantity, p.UnitPrice,retail.fn_CalculateLineTotal(o.Quantity, p.UnitPrice) as EstimatedLineTotal
FROM retail.Orders o
JOIN retail.Products p on o.ProductID = p.ProductID;

-- Inline table-valued function: behaves like a parameterized view. SQL Server expands
-- it directly into the calling query's plan, so it doesn't suffer the row-by-row cost
-- scalar UDFs do - prefer this style when you can.
GO
CREATE FUNCTION retail.fn_OrdersByCustomer (@CustomerID INT)
RETURNS TABLE
AS
RETURN
(
    SELECT OrderID, ProductID, OrderDate, Quantity, Status
    FROM retail.Orders
    WHERE CustomerID = @CustomerID
);
GO

SELECT * FROM retail.fn_OrdersByCustomer(21);


-- SECTION 20: TRIGGERS

CREATE TABLE retail.OrderAudit
(
    AuditID    INT      NOT NULL IDENTITY(1,1),
    OrderID    INT      NOT NULL,
    ActionType VARCHAR(10) NOT NULL,
    ActionDate DATETIME2   NOT NULL CONSTRAINT DF_OrderAudit_ActionDate DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_OrderAudit PRIMARY KEY (AuditID)
);
GO

-- AFTER INSERT trigger: fires once per statement (not once per row!) - the "inserted"
-- pseudo-table can hold many rows, so always write set-based logic inside triggers.
CREATE TRIGGER retail.trg_Orders_Audit
ON retail.Orders
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO retail.OrderAudit (OrderID, ActionType)
    SELECT OrderID, 'INSERT' FROM inserted;
END;
GO

-- Trigger it
INSERT INTO retail.Orders (CustomerID, ProductID, OrderDate, Quantity, Status)
VALUES (1, 1, CAST(GETDATE() AS DATE), 2, 'Completed');

SELECT * FROM retail.OrderAudit;


-- Another trigger for Customer Statistics (ID, Order Count)
-- First, we'll add for all existing customers and then write triggers to update for existing customers
-- and, insert for new customers. (We will be using UPSERT)

IF OBJECT_ID('retail.CustomerStats', 'U') IS NOT NULL
    DROP TABLE retail.CustomerStats ;

CREATE TABLE retail.CustomerStats
(
    CustomerID INT NOT NULL PRIMARY KEY,
    OrderCount INT NOT NULL DEFAULT 0
) ;
GO

INSERT INTO retail.CustomerStats(CustomerID, OrderCount)
(
    SELECT CustomerID, count(*) as OrderCount
    FROM retail.Orders
    GROUP BY CustomerID
) ;
GO

CREATE OR ALTER TRIGGER retail.trg_OrderInserted
ON retail.Orders 
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- MERGE (Update the retail.CustomerStats for existing customers, Insert for new customers)
    MERGE retail.CustomerStats AS target
    USING (SELECT CustomerID, COUNT(*) AS NewOrdersCount FROM INSERTED GROUP BY CustomerID) AS source
    On target.CustomerID = source.CustomerID
    WHEN MATCHED THEN UPDATE SET target.OrderCount = target.OrderCount + source.NewOrdersCount
    WHEN NOT MATCHED THEN INSERT (CustomerID, OrderCount) VALUES (source.CustomerID, source.NewOrdersCount) ;

END ;
GO

SELECT *
FROM retail.CustomerStats ;


-- Trigger it (Add for existing customer 1 to check how many orders he has placed in total)
-- before insering for customer 1, total orders placed is 21

INSERT INTO retail.Orders (CustomerID, ProductID, OrderDate, Quantity, Status)
VALUES (1, 2, CAST(GETDATE() AS DATE), 2, 'Completed');

SELECT * FROM retail.OrderAudit;  -- check if it updates the audit table

SELECT * FROM retail.CustomerStats WHERE CustomerID = 1;   -- check the order count now (22, updated)

-- again trigger it for new customer '26' to check how many orders he has placed in total
-- before insering for customer 26, total orders placed is 0

INSERT INTO retail.Customers (CustomerName, City, Country)
VALUES ('Ahsan Sunny', 'Manchester', 'United Kingdom') ;

SELECT * FROM retail.Customers WHERE CustomerID = 26 ;

INSERT INTO retail.Orders (CustomerID, ProductID, OrderDate, Quantity, Status)
VALUES (26, 2, CAST(GETDATE() AS DATE), 2, 'Completed');

SELECT * FROM retail.OrderAudit;  -- check if it updates the audit table

SELECT * FROM retail.CustomerStats WHERE CustomerID = 26;   -- check the order count now (22, updated)


-- SECTION 21: TRANSACTIONS & ERROR HANDLING
-- A transaction groups statements so they succeed or fail as one unit (ACID).
-- TRY/CATCH + XACT_STATE() is the standard SQL Server error-handling pattern.
BEGIN TRY
    BEGIN TRANSACTION;

        UPDATE retail.Products
        SET StockQuantity = StockQuantity - 10
        WHERE ProductID = 1;

        IF (SELECT StockQuantity FROM retail.Products WHERE ProductID = 1) < 0
            THROW 51000, 'Stock cannot go negative for ProductID 1.', 1;

        INSERT INTO retail.Orders (CustomerID, ProductID, OrderDate, Quantity, Status)
        VALUES (1, 1, CAST(GETDATE() AS DATE), 10, 'Completed');

    COMMIT TRANSACTION;
    PRINT 'Transaction committed successfully.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    PRINT 'Transaction rolled back: ' + ERROR_MESSAGE();
END CATCH;

-- XACT_STATE(): 1 = commitable transaction, -1 = uncommitable (must roll back), 0 = none open.
-- ERROR_MESSAGE() / ERROR_NUMBER() / ERROR_LINE() / ERROR_PROCEDURE() all work inside CATCH.

--SECTION 22: MERGE - THE UPSERT PATTERN
/* MERGE is the workhorse of ETL/ELT "upsert" loads: match a staging batch against
the target table, UPDATE what changed, INSERT what's new, all in one statement.
This is exactly how you'd apply a daily product feed in a real pipeline. */

CREATE TABLE retail.Products_Staging
(
    ProductID     INT           NOT NULL,
    ProductName   VARCHAR(100)  NOT NULL,
    Category      VARCHAR(50)   NOT NULL,
    UnitPrice     DECIMAL(10,2) NOT NULL,
    StockQuantity INT           NOT NULL
);
GO

INSERT INTO retail.Products_Staging VALUES
(3,  'USB-C Hub',            'Electronics',       17.99, 200),  -- existing product: price/stock changed
(21, 'Smart Water Bottle',   'Sports & Outdoors',  24.99,  80); -- brand-new product

SELECT * FROM retail.Products_Staging ;

-- IDENTITY_INSERT must be ON to insert an explicit value into an IDENTITY column
SET IDENTITY_INSERT retail.Products ON;

MERGE retail.Products AS target
USING retail.Products_Staging AS source
    ON target.ProductID = source.ProductID
WHEN MATCHED THEN
    UPDATE SET target.UnitPrice     = source.UnitPrice,
               target.StockQuantity = source.StockQuantity
WHEN NOT MATCHED BY TARGET THEN
    INSERT (ProductID, ProductName, Category, UnitPrice, StockQuantity)
    VALUES (source.ProductID, source.ProductName, source.Category, source.UnitPrice, source.StockQuantity)
OUTPUT $action AS Action, inserted.ProductID, deleted.UnitPrice AS OldPrice, inserted.UnitPrice AS NewPrice;

SET IDENTITY_INSERT retail.Products OFF;
GO

-- SECTION 23: DEDUPLICATION - A CORE DATA ENGINEERING PATTERN
  
-- Simulate an accidental duplicate load (very common when a source system re-sends
-- files, or an ETL job reruns without idempotency checks)
INSERT INTO retail.Customers (CustomerName, City, Country, SignupDate)
SELECT CustomerName, City, Country, SignupDate
FROM retail.Customers
WHERE CustomerID IN (1, 2);

-- Confirm the duplicates exist
SELECT CustomerName, Country, COUNT(*) AS Copies
FROM retail.Customers
GROUP BY CustomerName, Country
HAVING COUNT(*) > 1;

-- The standard fix: rank duplicates with ROW_NUMBER() over the "natural key" columns,
-- keep rn = 1 (usually the earliest CustomerID, i.e. the original row), delete the rest.
-- You can DELETE directly through a CTE when it's a simple single-table SELECT.
WITH Dedup AS
(
    SELECT
        CustomerID,
        ROW_NUMBER() OVER (PARTITION BY CustomerName, Country ORDER BY CustomerID) AS rn
    FROM retail.Customers
)
DELETE FROM Dedup WHERE rn > 1;

-- Confirm they're gone
SELECT CustomerName, Country, COUNT(*) AS Copies
FROM retail.Customers
GROUP BY CustomerName, Country
HAVING COUNT(*) > 1;   -- should return no rows


--SECTION 24: PERFORMANCE & INTERVIEW-GOTCHA CHEAT SHEET
/* 
   - COUNT(*) counts rows (incl. NULLs everywhere); COUNT(col) counts non-NULL values
     in that column; COUNT(DISTINCT col) counts unique non-NULL values. All three can
     legitimately give different numbers on the same table.
   - NOT IN (subquery) silently returns zero rows if the subquery can produce a NULL.
     Use NOT EXISTS instead - it's NULL-safe and usually faster too.
   - WHERE filters rows before GROUP BY; HAVING filters the grouped results after.
   - UNION ALL is cheaper than UNION (no implicit dedup sort/hash) - use UNION only
     when you actually need duplicates removed.
   - A correlated subquery re-runs once per outer row; a JOIN or window function
     usually rewrites the same logic as a single set-based pass. Compare execution
     plans when in doubt.
   - Wrapping an indexed column in a function (WHERE YEAR(OrderDate) = 2025) makes the
     predicate "non-SARGable" - the optimizer can't seek the index, forcing a scan.
     Rewrite as a range instead:
         NOT SARGable: WHERE YEAR(OrderDate) = 2025   (takes more time to execute)
         SARGable:     WHERE OrderDate >= '2025-01-01' AND OrderDate < '2026-01-01' (comparatively faster)
   - Implicit data-type conversions (comparing an INT column to an NVARCHAR literal,
     for example) can silently disable index usage. Match types explicitly.
   - Window functions execute after WHERE/GROUP BY/HAVING but before the final ORDER BY,
     which is why they can't be referenced directly inside a WHERE clause.
*/


