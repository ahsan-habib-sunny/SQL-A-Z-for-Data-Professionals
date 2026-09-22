/* ============================================================================
   SQL SERVER (T-SQL): FROM BASICS TO ADVANCED FOR DATA ENGINEERS
   ============================================================================
   TABLE OF CONTENTS
     0.  Database & schema setup
     1.  DDL - tables, data types, constraints
     2.  Loading sample data
*/

-- Drop and recreate so the script is safely re-runnable
IF DB_ID('SalesAnalyticsDB') IS NOT NULL
BEGIN
    ALTER DATABASE SalesAnalyticsDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE SalesAnalyticsDB;
END
GO

CREATE DATABASE SalesAnalyticsDB;
GO

USE SalesAnalyticsDB;
GO

-- Schemas namespace your objects 
-- Real warehouses use this for staging/curated layers: raw, stg, dw, etc.
CREATE SCHEMA retail;
GO

/* ============================================================================
   SECTION 1: DDL - TABLES, DATA TYPES, CONSTRAINTS
   ============================================================================ */

CREATE TABLE retail.Customers
(
    CustomerID   INT          NOT NULL IDENTITY(1,1),   -- auto incrementing surrogate key
    CustomerName VARCHAR(100) NOT NULL ,
    City         VARCHAR(50)  Null ,     -- nullable on purpose to show difference between COUNT(*) and Count(col)
    Country      VARCHAR(50)  NOT NULL,
    SignupDate   DATE         NOT NULL CONSTRAINT DF_Customers_SignupDate DEFAULT (GETDATE()),
    CONSTRAINT PK_Customers PRIMARY KEY (CustomerID)
) ;
GO

CREATE TABLE retail.Products
(
    ProductID     INT           NOT NULL IDENTITY(1,1),
    ProductName   VARCHAR(100)  NOT NULL,
    Category      VARCHAR(50)   NOT NULL,
    UnitPrice     DECIMAL(10,2) NOT NULL,
    StockQuantity INT           NOT NULL CONSTRAINT DF_Products_StockQuantity DEFAULT (0),
    CONSTRAINT PK_Products PRIMARY KEY (ProductID),
    CONSTRAINT CK_Products_UnitPrice CHECK (UnitPrice >= 0)
);
GO

CREATE TABLE retail.Orders
(
    OrderID    INT          NOT NULL IDENTITY(1,1),
    CustomerID INT          NOT NULL,
    ProductID  INT          NOT NULL,
    OrderDate  DATE         NOT NULL,
    Quantity   INT          NOT NULL,
    Status     VARCHAR(20)  NOT NULL CONSTRAINT DF_Orders_Status DEFAULT ('Completed'),
    CONSTRAINT PK_Orders PRIMARY KEY (OrderID),
    CONSTRAINT FK_Orders_Customers FOREIGN KEY (CustomerID) REFERENCES retail.Customers (CustomerID),
    CONSTRAINT FK_Orders_Products  FOREIGN KEY (ProductID)  REFERENCES retail.Products (ProductID),
    CONSTRAINT CK_Orders_Quantity  CHECK (Quantity > 0),
    CONSTRAINT CK_Orders_Status    CHECK (Status IN ('Completed', 'Pending', 'Cancelled', 'Returned'))
);
GO

/* ============================================================================
   SECTION 2: LOADING SAMPLE DATA
   ============================================================================ */

INSERT INTO retail.Customers (CustomerName, City, Country, SignupDate) VALUES
('Alice Morgan',      'Manchester',   'United Kingdom',       '2023-01-15'),
('Bilal Ahmed',       'Rochdale',     'United Kingdom',       '2023-02-03'),
('Carla Jimenez',     'Madrid',       'Spain',                '2023-01-22'),
('David Chen',        'Toronto',      'Canada',               '2023-03-10'),
('Emily Clarke',      'London',       'United Kingdom',       '2023-02-17'),
('Farhan Islam',      'Dhaka',        'Bangladesh',           '2023-04-05'),
('Grace Kim',         'Seoul',        'South Korea',          '2023-03-28'),
('Hassan Ali',        'Dubai',        'United Arab Emirates', '2023-05-12'),
('Isabella Rossi',    'Milan',        'Italy',                '2023-01-09'),
('Jack Wilson',       NULL,           'Australia',            '2023-06-01'), -- unknown city
('Karim Haddad',      'Cairo',        'Egypt',                '2023-04-19'),
('Laura Schmidt',     'Berlin',       'Germany',              '2023-02-25'),
('Mohammed Yusuf',    'Riyadh',       'Saudi Arabia',         '2023-07-14'),
('Nina Petrova',      'Sofia',        'Bulgaria',             '2023-03-03'),
('Omar Sheikh',       NULL,           'Pakistan',             '2023-08-08'), -- unknown city
('Priya Nair',        'Bengaluru',    'India',                '2023-01-30'),
('Quentin Dubois',    'Paris',        'France',               '2023-05-22'),
('Rachel Adams',      'New York',     'United States',        '2023-02-11'),
('Samuel Osei',       'Accra',        'Ghana',                '2023-06-17'),
('Tania Novak',       'Prague',       'Czechia',              '2023-04-27'),
('Umar Farooq',       'Lahore',       'Pakistan',             '2023-09-02'),
('Victoria Hughes',   'Leeds',        'United Kingdom',       '2023-03-15'),
('Wei Zhang',         'Shanghai',     'China',                '2023-07-29'),
('Ximena Torres',     'Mexico City',  'Mexico',               '2023-08-19'),
('Yusuf Karimov',     'Tashkent',     'Uzbekistan',           '2023-09-10');
GO

INSERT INTO retail.Products (ProductName, Category, UnitPrice, StockQuantity) VALUES
('Wireless Mouse',              'Electronics',        19.99, 150),
('Mechanical Keyboard',         'Electronics',        59.99,  90),
('USB-C Hub',                   'Electronics',        29.50, 120),
('Noise Cancelling Headphones', 'Electronics',       129.99,  60),
('Portable SSD 1TB',            'Electronics',        89.00,  75),
('Stainless Steel Kettle',      'Home & Kitchen',      34.99, 100),
('Non-Stick Frying Pan',        'Home & Kitchen',      24.50, 140),
('Air Fryer',                   'Home & Kitchen',      79.99,  55),
('Coffee Grinder',              'Home & Kitchen',      27.99,  85),
('The Data Engineer''s Handbook','Books',              22.00, 200),
('SQL for Analysts',            'Books',               18.50, 180),
('Introduction to Python',      'Books',               21.00, 160),
('Cotton T-Shirt',              'Clothing',            12.99, 300),
('Denim Jacket',                'Clothing',            49.99,  90),
('Running Shoes',               'Clothing',            64.99, 110),
('Wool Scarf',                  'Clothing',            15.99, 130),
('Yoga Mat',                    'Sports & Outdoors',   18.99, 150),
('Camping Tent (2-Person)',     'Sports & Outdoors',   89.99,  40),
('Adjustable Dumbbell Set',     'Sports & Outdoors',  109.99,  50),
('Insulated Water Bottle',      'Sports & Outdoors',   16.99, 220);
GO

-- 500 orders, generated instead of hand-typed 

WITH Tally AS
(
    SELECT TOP (500) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects AS a
    CROSS JOIN sys.all_objects AS b
)
INSERT INTO retail.Orders (CustomerID, ProductID, OrderDate, Quantity, Status)
SELECT
    ((n * 37) % 25) + 1                                AS CustomerID,   -- spread across 25 customers
    ((n * 53) % 20) + 1                                AS ProductID,    -- spread across 20 products
    DATEADD(DAY, -(n % 730), CAST(GETDATE() AS DATE))  AS OrderDate,    -- last ~2 years
    ((n % 5) + 1)                                      AS Quantity,     -- 1 to 5 units
    CASE
        WHEN n % 20 = 0 THEN 'Cancelled'   -- ~5%
        WHEN n % 15 = 0 THEN 'Returned'
        WHEN n % 10 = 0 THEN 'Pending'
        ELSE 'Completed'                   -- majority
    END                                                 AS Status
FROM Tally;
GO

-- Sanity check the load
SELECT
    (SELECT COUNT(*) FROM retail.Customers) AS CustomerCount,
    (SELECT COUNT(*) FROM retail.Products)  AS ProductCount,
    (SELECT COUNT(*) FROM retail.Orders)    AS OrderCount;
GO