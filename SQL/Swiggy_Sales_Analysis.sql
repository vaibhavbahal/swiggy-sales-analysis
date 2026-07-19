SELECT * FROM swiggy_orders

-- Data Validation and Cleaning
-- Null Checking

SELECT
    SUM(CASE WHEN State IS NULL THEN 1 ELSE 0 END) AS null_state,
    SUM(CASE WHEN City IS NULL THEN 1 ELSE 0 END) AS null_city,
    SUM(CASE WHEN Order_Date IS NULL THEN 1 ELSE 0 END) AS null_order_date,
    SUM(CASE WHEN Restaurant_Name IS NULL THEN 1 ELSE 0 END) AS null_restaurant,
    SUM(CASE WHEN Location IS NULL THEN 1 ELSE 0 END) AS null_location,
    SUM(CASE WHEN Category IS NULL THEN 1 ELSE 0 END) AS null_category,
    SUM(CASE WHEN Dish_Name IS NULL THEN 1 ELSE 0 END) AS null_dish,
    SUM(CASE WHEN Price_INR IS NULL THEN 1 ELSE 0 END) AS null_price,
    SUM(CASE WHEN Rating IS NULL THEN 1 ELSE 0 END) AS null_rating,
    SUM(CASE WHEN Rating_Count IS NULL THEN 1 ELSE 0 END) AS null_rating_count
FROM swiggy_orders;

-- Blank Or Empty String

SELECT * FROM swiggy_orders
WHERE state = '' OR city = '' OR restaurant_name = '' OR category = '' OR dish_name = ''

-- Duplicate Detection

SELECT 
state , city , Order_Date , restaurant_name , Location , category,
dish_name , Price_INR , Rating, Rating_Count , count(*) as CNT 
FROM swiggy_orders
GROUP BY
state , city , Order_Date , restaurant_name , Location , category,
dish_name , Price_INR , Rating, Rating_Count 
HAVING COUNT(*) > 1

-- Delete Duplicates

WITH cte AS (
    SELECT
        ctid,
        ROW_NUMBER() OVER (
            PARTITION BY
                state,
                city,
                Order_Date,
                restaurant_name,
                Location,
                category,
                dish_name,
                Price_INR,
                Rating,
                Rating_Count
            ORDER BY ctid
        ) AS rn
    FROM swiggy_orders
)

DELETE FROM swiggy_orders
WHERE ctid IN (
    SELECT ctid
    FROM cte
    WHERE rn > 1
);

-- Creating Schema
-- Dimension Tables 
-- Date Table

CREATE TABLE dim_date (
    date_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    FULL_DATE DATE,
    YEAR INT,
    MONTH INT,
    MONTH_NAME VARCHAR(20),
    QUARTER INT,
    DAY INT,
    WEEK INT
)

-- dim_location
CREATE TABLE dim_location (
    location_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    state VARCHAR(100),
    city VARCHAR(100),
    location VARCHAR(200)
);

-- dim_restaurant
CREATE TABLE dim_restaurant (
    restaurant_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    restaurant_name VARCHAR(200)
);

-- dim_category
CREATE TABLE dim_category (
    category_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category VARCHAR(200)
);

-- dim_dish
CREATE TABLE dim_dish (
    dish_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    dish_name VARCHAR(200)
);

-- FACT_TABLE
CREATE TABLE fact_swiggy_orders (
    order_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    date_id INT,
    price_inr DECIMAL(10,2),
    rating DECIMAL(4,2),
    rating_count INT,

    location_id INT,
    restaurant_id INT,
    category_id INT,
    dish_id INT,

    FOREIGN KEY (date_id) REFERENCES dim_date(date_id),
    FOREIGN KEY (location_id) REFERENCES dim_location(location_id),
    FOREIGN KEY (restaurant_id) REFERENCES dim_restaurant(restaurant_id),
    FOREIGN KEY (category_id) REFERENCES dim_category(category_id),
    FOREIGN KEY (dish_id) REFERENCES dim_dish(dish_id)
);

SELECT * FROM fact_swiggy_orders

-- INSERTING DATA

-- dim_date
INSERT INTO dim_date (FULL_DATE, YEAR, MONTH, MONTH_NAME, QUARTER, DAY, WEEK)
SELECT DISTINCT 
    Order_Date,
    EXTRACT(YEAR FROM Order_Date),
    EXTRACT(MONTH FROM Order_Date),
    TO_CHAR(Order_Date, 'FMMonth'),
    EXTRACT(QUARTER FROM Order_Date),
    EXTRACT(DAY FROM Order_Date),
    EXTRACT(WEEK FROM Order_Date)
FROM swiggy_orders
WHERE Order_Date IS NOT NULL;

SELECT * FROM dim_date

-- dim_location

INSERT INTO dim_location (state, city, location)
SELECT DISTINCT
    state,
    city,
    location
FROM swiggy_orders
WHERE state IS NOT NULL
  AND city IS NOT NULL
  AND location IS NOT NULL;

-- dim_restaurant

INSERT INTO dim_restaurant(Restaurant_Name)
SELECT DISTINCT
    Restaurant_Name
FROM swiggy_orders;

-- dim_category

INSERT INTO dim_category(Category)
SELECT DISTINCT
    Category
FROM swiggy_orders;

-- dim_dish

INSERT INTO dim_dish(Dish_Name)
SELECT DISTINCT
    Dish_Name
FROM swiggy_orders;

-- FACT TABLE

INSERT INTO fact_swiggy_orders (
    date_id,
    price_inr,
    rating,
    rating_count,
    location_id,
    restaurant_id,
    category_id,
    dish_id
)
SELECT
    dd.date_id,
    s.price_inr,
    s.rating,
    s.rating_count,
    dl.location_id,
    dr.restaurant_id,
    dc.category_id,
    dsh.dish_id
FROM swiggy_orders s
INNER JOIN dim_date dd
    ON dd.full_date = s.order_date
INNER JOIN dim_location dl
    ON dl.state = s.state
   AND dl.city = s.city
   AND dl.location = s.location
INNER JOIN dim_restaurant dr
    ON dr.restaurant_name = s.restaurant_name
INNER JOIN dim_category dc
    ON dc.category = s.category
INNER JOIN dim_dish dsh
    ON dsh.dish_name = s.dish_name;

 
SELECT * FROM fact_swiggy_orders;

-- Want to see full Data
SELECT * FROM fact_swiggy_orders f
JOIN dim_date d on f.date_id = d.date_id
JOIN dim_location l on f.location_id = l.location_id
JOIN dim_restaurant r on f.restaurant_id = r.restaurant_id
JOIN dim_category c on f.category_id = c.category_id
JOIN dim_dish di on f.dish_id = di.dish_id;

-- BUSINESS INSIGHTS
-- HOW MANY ORDERS WERE PLACED DURING THE SELECTED PERIOD?
-- IT TELLS US THE PLATFORM ACTIVITY AND DEMAND

SELECT COUNT(*) AS Total_Orders 
FROM fact_swiggy_orders;


-- HOW MUCH REVENUE WAS GENERATED ?
-- TO MEASURE THE OVERALL FINANCIAL PERFORMANCE OF THE BUSINESS

SELECT
ROUND(SUM(Price_INR),2) AS total_revenue
FROM fact_swiggy_orders;

-- WHAT IS THE AVERAGE AMOUNT CUSTOMER SPENT ON A DISH?
-- HELPS UNDERSTAND CUSTOMER SPENDING BEHAVIOUR AND PRICING STRATEGY

SELECT (ROUND(AVG(Price_INR),2)) AS AVERAGE_DISH_PRICE
FROM fact_swiggy_orders


-- WHAT IS THE AVERAGE CUSTOMER RATING?
-- MEASURES OVERALL CUSTOMER SATISFACTION AND SERVICE QUALITY
SELECT ROUND(AVG(RATING),2) AS AVERAGE_RATING
FROM fact_swiggy_orders

--DEEP DIVE BUSINESS ANALYSIS

-- HOW DO CUSTOMER ORDERS CHANGE ACROSS DIFFERENT MONTHS?
-- HELPS IDENTIFY SEASONAL DEMAND PATTERNS, FORECAST FUTURE ORDERS, 
-- AND PLAN INVENTORY, DELIVERY PARTNERS, AND MARKETING CAMPAIGNS ACCORDINGLY

SELECT 
d.year,
d.month,
d.MONTH_NAME,
COUNT(*) AS Total_Orders
FROM fact_swiggy_orders f 
JOIN dim_date d ON f.date_id = d.date_id
GROUP BY d.year,
d.month,
d.MONTH_NAME
ORDER BY Total_Orders DESC;

-- Quarterly Trend
-- WHICH QUARTER HAS THE HIGHEST NUMBER OF ORDERS?
-- HELPS EVALUATE BUSINESS PERFORMANCE ON A QUARTERLY BASIS, 
-- SUPPORTS STRATEGIC PLANNING, AND ENABLES PERFORMANCE COMPARISON ACROSS QUARTERS.

SELECT 
d.year,
d.QUARTER,
COUNT(*) AS QUARTERLY_ORDERS
FROM fact_swiggy_orders f 
JOIN dim_date d ON f.date_id = d.date_id
GROUP BY d.year,
d.QUARTER

-- HOW MANY ORDERS HAVE BEEN RECEIVED SO FAR THIS YEAR?
-- TRACKS ANNUAL BUSINESS PROGRESS, MEASURES GROWTH, 
-- AND HELPS COMPARE CURRENT YEAR PERFORMANCE WITH PREVIOUS YEARS.

SELECT 
d.year,
COUNT(*) AS YEAR_TO_DATE_ORDERS
FROM fact_swiggy_orders f 
JOIN dim_date d ON f.date_id = d.date_id
GROUP BY d.year

-- WHICH DAY OF THE WEEK RECEIVES THE HIGHEST NUMBER OF ORDERS?
-- IDENTIFIES CUSTOMER ORDERING PATTERNS TO OPTIMIZE DELIVERY STAFFING, 
-- RESTAURANT OPERATIONS, AND DAY-SPECIFIC PROMOTIONS.

SELECT
    TRIM(TO_CHAR(d.full_date, 'Day')) AS day_name,
    COUNT(*) AS total_orders
FROM fact_swiggy_orders f
JOIN dim_date d
    ON f.date_id = d.date_id
GROUP BY
    TRIM(TO_CHAR(d.full_date, 'Day'))
ORDER BY total_orders DESC;

-- WHICH CITIES GENERATE THE HIGHEST NUMBER OF ORDERS AND REVENUE?
-- HELPS IDENTIFY HIGH-DEMAND AND HIGH-VALUE MARKETS. 
-- THIS SUPPORTS CITY-WISE EXPANSION,TARGETED MARKETING, AND RESOURCE ALLOCATION.

SELECT
l.city,
count(*) AS Total_Orders
FROM fact_swiggy_orders f
JOIN dim_location l on
l.location_id = f.location_id
GROUP BY l.city
ORDER BY total_orders DESC LIMIT 10;

SELECT
l.city,
SUM(price_inr) AS total_revenue
FROM fact_swiggy_orders f
JOIN dim_location l on
l.location_id = f.location_id
GROUP BY l.city
ORDER BY total_revenue DESC LIMIT 10;

-- WHICH STATES CONTRIBUTE THE MOST TO TOTAL REVENUE?
-- EVALUATES REGIONAL BUSINESS PERFORMANCE AND HELPS ALLOCATE RESOURCES,
-- MARKETING BUDGETS, AND OPERATIONAL INVESTMENTS EFFECTIVELY.

SELECT
l.state,
SUM(price_inr) AS total_revenue
FROM fact_swiggy_orders f
JOIN dim_location l on
l.location_id = f.location_id
GROUP BY l.state
ORDER BY total_revenue DESC LIMIT 10;

-- FOOD PERFORMANCE
-- WHICH RESTAURANTS ARE THE BEST PERFORMERS
-- IN TERMS OF ORDER VOLUME AND REVENUE?
-- HELPS IDENTIFY TOP-PERFORMING RESTAURANT PARTNERS FOR PROMOTIONS,
-- STRATEGIC PARTNERSHIPS, AND BUSINESS GROWTH.

SELECT
r.restaurant_name,
count(*) AS Total_Orders,
FROM fact_swiggy_orders f
JOIN dim_restaurant r on
r.restaurant_id = f.location_id
GROUP BY r.restaurant_name
ORDER BY total_orders DESC LIMIT 10;

SELECT
r.restaurant_name,
SUM(price_inr) AS Total_Revenue
FROM fact_swiggy_orders f
JOIN dim_restaurant r on
r.restaurant_id = f.location_id
GROUP BY r.restaurant_name
ORDER BY Total_Revenue DESC;

-- WHICH FOOD CATEGORIES ARE MOST PREFERRED BY CUSTOMERS?
-- HELPS UNDERSTAND CUSTOMER FOOD PREFERENCES, IMPROVE MENU RECOMMENDATIONS,
-- AND IDENTIFY CATEGORIES FOR FUTURE EXPANSION.

SELECT 
    c.category,
    COUNT(*) AS total_orders
FROM fact_swiggy_orders f 
JOIN dim_category c 
ON f.category_id = c.category_id
GROUP BY c.category
ORDER BY total_orders DESC LIMIT 10;

-- WHICH DISHES ARE ORDERED MOST FREQUENTLY?
-- IDENTIFIES CUSTOMER FAVORITES, SUPPORTS PRODUCT RECOMMENDATIONS,
-- COMBO OFFERS, CROSS-SELLING, AND MENU OPTIMIZATION.

SELECT 
    di.dish_name,
    COUNT(*) AS order_count
FROM fact_swiggy_orders f 
JOIN dim_dish di
ON f.dish_id = di.dish_id
GROUP BY di.dish_name
ORDER BY order_count DESC LIMIT 10;

-- WHICH TYPE OF CUISINE ARE BEEN PREFERRED MORE

SELECT
    c.category,
    COUNT(*) AS total_orders,
    ROUND(AVG(F.RATING),2) AS AVERAGE_RATING
FROM fact_swiggy_orders f 
JOIN dim_category c
ON c.category_id = f.category_id
GROUP BY c.category
ORDER BY Total_Orders DESC LIMIT 10;

-- WHICH PRICE RANGE RECEIVES THE HIGHEST NUMBER OF ORDERS?
-- ANALYZES CUSTOMER SPENDING PATTERNS, SUPPORTS PRICING STRATEGIES, 
-- AND HELPS DESIGN TARGETED OFFERS FOR DIFFERENT CUSTOMER SEGMENTS.

SELECT 
    CASE 
        WHEN price_inr < 100 THEN 'Under 100'
        WHEN price_inr BETWEEN 100 AND 199 THEN '100 - 199'
        WHEN price_inr BETWEEN 200 AND 299 THEN '200 - 299'
        WHEN price_inr BETWEEN 300 AND 499 THEN '300 - 499'
        ELSE '500+'
    END AS price_range,
    COUNT(*) AS Total_Orders
FROM fact_swiggy_orders
GROUP BY
    CASE 
        WHEN price_inr < 100 THEN 'Under 100'
        WHEN price_inr BETWEEN 100 AND 199 THEN '100 - 199'
        WHEN price_inr BETWEEN 200 AND 299 THEN '200 - 299'
        WHEN price_inr BETWEEN 300 AND 499 THEN '300 - 499'
        ELSE '500+'
    END
ORDER BY total_orders DESC;

-- RATING COUNT DISTRIBUTION
-- PROVIDES AN OVERALL VIEW OF CUSTOMER SATISFACTION, 
--HELPS IDENTIFY SERVICE QUALITY LEVELS, AND HIGHLIGHTS AREAS REQUIRING IMPROVEMENT.

SELECT 
    rating,
    COUNT(RATING) AS Rating_Count
FROM fact_swiggy_orders
GROUP BY rating
ORDER BY rating_count DESC;