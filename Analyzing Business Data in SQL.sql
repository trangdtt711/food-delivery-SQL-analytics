
---- Create Data Tables
DROP TABLE IF EXISTS "meals";
CREATE TABLE meals (
  meal_id INT,
  eatery TEXT,
  meal_price FLOAT,
  meal_cost FLOAT
);

DROP TABLE IF EXISTS "orders";
CREATE TABLE orders (
  order_date DATE,
  user_id INT,
  order_id INT,
  meal_id INT,
  order_quantity INT
);

DROP TABLE IF EXISTS "stock";
CREATE TABLE stock (
  stocking_date DATE,
  meal_id INT,
  stocked_quantity INT
);

COPY meals
FROM PROGRAM 'curl "https://assets.datacamp.com/production/repositories/4016/datasets/732c094b30a2e794d0b12b12547587a903126f68/meals.csv"' (DELIMITER ',', FORMAT CSV);

COPY orders
FROM PROGRAM 'curl "https://assets.datacamp.com/production/repositories/4016/datasets/606e6e9165c25477db078996fa7e0a3e994b93d3/orders.csv"' (DELIMITER ',', FORMAT CSV);

COPY stock
FROM PROGRAM 'curl "https://assets.datacamp.com/production/repositories/4016/datasets/10d9ad146a85010d836cfc93870aa464951f0640/stock.csv"' (DELIMITER ',', FORMAT CSV);



-- Calculate revenue for customer ID 15
SELECT sum(meals.meal_price*orders.order_quantity) AS revenue
  FROM meals
  JOIN orders ON meals.meal_id = orders.meal_id
WHERE orders.user_id = 15 



-- Calculate revenue for the records in each week in June 2018
SELECT DATE_TRUNC('week', order_date) :: DATE AS delivr_week,
       sum(meals.meal_price * orders.order_quantity) AS revenue
  FROM meals
  JOIN orders ON meals.meal_id = orders.meal_id
WHERE DATE_TRUNC('month', order_date) = '2018-06-01'
GROUP BY delivr_week
ORDER BY delivr_week ASC;



-- Calculate cost per meal ID, Only the top 5 meal IDs by purchase cost
SELECT
  meals.meal_id,
  SUM(meals.meal_cost * stock.stocked_quantity) AS cost
FROM meals
JOIN stock ON meals.meal_id = stock.meal_id
GROUP BY meals.meal_id
ORDER BY cost DESC
LIMIT 5;



-- Declare a CTE (Common Table Expression) named monthly_cost then calculate the average monthly cost before September
WITH monthly_cost AS (
  SELECT
    DATE_TRUNC('month', stocking_date)::DATE AS delivr_month,
    SUM(meal_cost * stocked_quantity) AS cost
  FROM meals
  JOIN stock ON meals.meal_id = stock.meal_id
  GROUP BY delivr_month)

SELECT
  AVG(cost)
FROM monthly_cost
WHERE delivr_month < '2018-09-01' ;



-- Calculate profit per eatery through CTEs
WITH revenue AS (
  -- Calculate revenue per eatery
  SELECT meals.eatery,
         SUM(meals.meal_price*orders.order_quantity) AS revenue
    FROM meals
    JOIN orders ON meals.meal_id = orders.meal_id
   GROUP BY eatery),

  cost AS (
  -- Calculate cost per eatery
  SELECT meals.eatery,
         SUM(meals.meal_cost*stock.stocked_quantity) AS cost
    FROM meals
    JOIN stock ON meals.meal_id = stock.meal_id
   GROUP BY eatery)

   SELECT revenue.eatery,
          revenue.revenue - cost.cost AS profit
     FROM revenue
     JOIN cost ON revenue.eatery = cost.eatery
    ORDER BY profit DESC;



-- Calculate profit per delivery month through CTEs
-- Set up the revenue CTE
WITH revenue AS ( 
	SELECT
		DATE_TRUNC('month', order_date) :: DATE AS delivr_month,
		SUM(meals.meal_price*orders.order_quantity) AS revenue
	FROM meals
	JOIN orders ON meals.meal_id = orders.meal_id
	GROUP BY delivr_month),
-- Set up the cost CTE
   cost AS (
 	SELECT
		DATE_TRUNC('month', stocking_date) :: DATE AS delivr_month,
		SUM(meals.meal_cost*stock.stocked_quantity) AS cost
	FROM meals
    JOIN stock ON meals.meal_id = stock.meal_id
	GROUP BY delivr_month)
-- Calculate profit by joining the CTEs
SELECT
	revenue.delivr_month,
	revenue.revenue - cost.cost AS profit
FROM revenue
JOIN cost ON revenue.delivr_month = cost.delivr_month
ORDER BY revenue.delivr_month ASC;



-- Count the unique user IDs by registration month
WITH reg_dates AS (
  SELECT
    user_id,
    MIN(order_date) AS reg_date
  FROM orders
  GROUP BY user_id)

SELECT
  DATE_TRUNC('month', reg_date) :: DATE AS delivr_month,
  COUNT (DISTINCT user_id) AS regs
FROM reg_dates
GROUP BY delivr_month
ORDER BY delivr_month ASC; 



-- Count the Monthly Active Users (MAU)
SELECT
  DATE_TRUNC('month', order_date) :: DATE AS delivr_month,
  COUNT (DISTINCT user_id) AS mau
FROM orders
GROUP BY delivr_month
ORDER BY delivr_month ASC;



-- Calculate the registrations running total by month
WITH reg_dates AS (
  SELECT
    user_id,
    MIN(order_date) AS reg_date
  FROM orders
  GROUP BY user_id),

  regs AS (
  SELECT
    DATE_TRUNC('month', reg_date) :: DATE AS delivr_month,
    COUNT(DISTINCT user_id) AS regs
  FROM reg_dates
  GROUP BY delivr_month)

SELECT
  delivr_month,
  SUM(regs) OVER (ORDER BY delivr_month ASC) AS regs_rt
FROM regs
ORDER BY delivr_month ASC; 

-- Calculate each month's delta of MAUs
-- Calculate MAU and lastMAU
WITH mau AS (
  SELECT
    DATE_TRUNC('month', order_date) :: DATE AS delivr_month,
    COUNT(DISTINCT user_id) AS mau
  FROM orders
  GROUP BY delivr_month)

SELECT
  delivr_month,
  mau,
  COALESCE( LAG(mau) OVER (ORDER BY delivr_month ASC),
  0) AS last_mau
FROM mau
ORDER BY delivr_month ASC;

WITH mau AS (
  SELECT
    DATE_TRUNC('month', order_date) :: DATE AS delivr_month,
    COUNT(DISTINCT user_id) AS mau
  FROM orders
  GROUP BY delivr_month),

  mau_with_lag AS (
  SELECT
    delivr_month,
    mau,
    -- Fetch the previous month's MAU
    COALESCE(
      LAG(mau) OVER (ORDER BY delivr_month ASC),
    0) AS last_mau
  FROM mau)

SELECT
  delivr_month,
  mau - last_mau AS mau_delta
FROM mau_with_lag
-- Order by month in ascending order
ORDER BY delivr_month ASC;



-- Calculate the MoM MAU growth rates
WITH mau AS (
  SELECT
    DATE_TRUNC('month', order_date) :: DATE AS delivr_month,
    COUNT(DISTINCT user_id) AS mau
  FROM orders
  GROUP BY delivr_month),

  mau_with_lag AS (
  SELECT
    delivr_month,
    mau,
    GREATEST(
      LAG(mau) OVER (ORDER BY delivr_month ASC),
    1) AS last_mau --avoid divide by 0
  FROM mau)

SELECT
  delivr_month,
  ROUND(
    (mau - last_mau) :: NUMERIC /last_mau,
  2) AS growth
FROM mau_with_lag
-- Order by month in ascending order
ORDER BY delivr_month ASC;



-- Calculate the MoM order growth rate
WITH orders AS (
  SELECT
    DATE_TRUNC('month', order_date) :: DATE AS delivr_month,
    --  Count the unique order IDs
    COUNT (DISTINCT order_id) AS orders
  FROM orders
  GROUP BY delivr_month),

  orders_with_lag AS (
  SELECT
    delivr_month,
    -- Fetch each month's current and previous orders
    orders,
    COALESCE(
      LAG(orders) OVER (ORDER BY delivr_month ASC) ,
    1) AS last_orders
  FROM orders)

SELECT
  delivr_month,
  ROUND(
    (orders - last_orders) :: NUMERIC / last_orders,
  2) AS growth
FROM orders_with_lag
ORDER BY delivr_month ASC;



-- Calculate the MoM retention rates
WITH user_monthly_activity AS (
  SELECT DISTINCT
    DATE_TRUNC('month', order_date) :: DATE AS delivr_month,
    user_id
  FROM orders)

SELECT
  previous.delivr_month,
  ROUND(
    COUNT (DISTINCT current.user_id) :: NUMERIC /
    GREATEST (COUNT (DISTINCT previous.user_id),1),
  2) AS retention_rate
FROM user_monthly_activity AS previous
LEFT JOIN user_monthly_activity AS current
ON previous.user_id = current.user_id
AND previous.delivr_month = (current.delivr_month - INTERVAL '1 month')
GROUP BY previous.delivr_month
ORDER BY previous.delivr_month ASC;



-- Calculate Average Revenue Per User (ARPU)
WITH kpi AS (
  SELECT
    user_id,
    SUM(m.meal_price * o.order_quantity) AS revenue
  FROM meals AS m
  JOIN orders AS o ON m.meal_id = o.meal_id
  GROUP BY user_id)
  
SELECT ROUND(AVG(revenue) :: NUMERIC, 2) AS arpu
FROM kpi;



-- Calculate Average Revenue Per User (ARPU) by Week
WITH kpi AS (
  SELECT
    -- Select the week, revenue, and count of users
    DATE_TRUNC('week', order_date) :: DATE AS delivr_week,
    SUM(m.meal_price * o.order_quantity) AS revenue,
    COUNT (DISTINCT o.user_id) AS users
  FROM meals AS m
  JOIN orders AS o ON m.meal_id = o.meal_id
  GROUP BY delivr_week)

SELECT
  delivr_week,
  -- Calculate ARPU
  ROUND(
    revenue :: NUMERIC / users,
  2) AS arpu
FROM kpi
-- Order by week in ascending order
ORDER BY delivr_week ASC;

-- The frequency table of revenues by user
WITH user_revenues AS (
  SELECT
    -- Select the user ID and revenue
    o.user_id,
    SUM(m.meal_price * o.order_quantity) AS revenue
  FROM meals AS m
  JOIN orders AS o ON m.meal_id = o.meal_id
  GROUP BY user_id)

SELECT
  ROUND(revenue :: NUMERIC, -2) AS revenue_100,
  COUNT (user_id) AS users
FROM user_revenues
GROUP BY revenue_100
ORDER BY revenue_100 ASC;



-- Frequency table of orders by user
WITH user_orders AS (
  SELECT
    user_id,
    COUNT(DISTINCT order_id) AS orders
  FROM orders
  GROUP BY user_id)

SELECT
  orders,
  COUNT (user_id) AS users
FROM user_orders
GROUP BY orders
ORDER BY orders ASC;



-- Bucketing users by revenue
WITH user_revenues AS (
  SELECT
    o.user_id,
    SUM(m.meal_price * o.order_quantity) AS revenue
  FROM meals AS m
  JOIN orders AS o ON m.meal_id = o.meal_id
  GROUP BY user_id)

SELECT
  CASE
    WHEN revenue < 150 THEN 'Low-revenue users'
    WHEN revenue >= 150 AND revenue <300 THEN 'Mid-revenue users'
    ELSE 'High-revenue users'
  END AS revenue_group,
  COUNT(user_id) AS users
FROM user_revenues
GROUP BY revenue_group;



-- Calculate the mean, the first, second, and third quartile of revenue
WITH user_revenues AS (
  SELECT
    o.user_id,
    SUM(m.meal_price * o.order_quantity) AS revenue
  FROM meals AS m
  JOIN orders AS o ON m.meal_id = o.meal_id
  GROUP BY user_id)

SELECT
  ROUND(
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY revenue ASC) :: NUMERIC,
  2) AS revenue_p25,
  ROUND(
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY revenue ASC) :: NUMERIC,
  2) AS revenue_p50,
  ROUND(
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY revenue ASC) :: NUMERIC,
  2) AS revenue_p75,
  ROUND(AVG(revenue) :: NUMERIC, 2) AS avg_revenue
FROM user_revenues;



-- Count the number of users in the IQR
WITH user_revenues AS (
  SELECT
    user_id,
    SUM(m.meal_price * o.order_quantity) AS revenue
  FROM meals AS m
  JOIN orders AS o ON m.meal_id = o.meal_id
  GROUP BY user_id),

  quartiles AS (
  SELECT
    ROUND(
      PERCENTILE_CONT(0.25) WITHIN GROUP
      (ORDER BY revenue ASC) :: NUMERIC,
    2) AS revenue_p25,
    ROUND(
      PERCENTILE_CONT(0.75) WITHIN GROUP
      (ORDER BY revenue ASC) :: NUMERIC,
    2) AS revenue_p75
  FROM user_revenues)

SELECT
  COUNT (DISTINCT user_id) AS users
FROM user_revenues
CROSS JOIN quartiles
WHERE user_revenues.revenue :: NUMERIC >= quartiles.revenue_p25
  AND user_revenues.revenue :: NUMERIC <= quartiles.revenue_p75;



-- Select user ID, and rank user ID by count_orders
WITH user_count_orders AS (
  SELECT
    user_id,
    COUNT(DISTINCT order_id) AS count_orders
  FROM orders
  -- Only keep orders in August 2018
  WHERE DATE_TRUNC('month', order_date) = '2018-08-01'
  GROUP BY user_id)

SELECT
  user_id,
  count_orders,
  RANK() OVER (ORDER BY count_orders DESC) AS count_orders_rank
FROM user_count_orders
ORDER BY count_orders_rank ASC;



-- Create a crosstab table of orders by users in each month
-- Import tablefunc
CREATE EXTENSION IF NOT EXISTS tablefunc;

SELECT * FROM CROSSTAB($$
  SELECT
    user_id,
    DATE_TRUNC('month', order_date) :: DATE AS delivr_month,
    SUM(meal_price * order_quantity) :: FLOAT AS revenue
  FROM meals
  JOIN orders ON meals.meal_id = orders.meal_id
 WHERE user_id IN (0, 1, 2, 3, 4)
   AND order_date < '2018-09-01'
 GROUP BY user_id, delivr_month
 ORDER BY user_id, delivr_month;
$$)
-- Select user ID and the months from June to August 2018
AS ct (user_id INT,
       "2018-06-01" FLOAT,
       "2018-07-01" FLOAT,
       "2018-08-01" FLOAT)
ORDER BY user_id ASC;



-- Create a crosstab table of costs by eatery for each month
-- Import tablefunc
CREATE EXTENSION IF NOT EXISTS tablefunc;

SELECT * FROM CROSSTAB($$
  SELECT
    -- Select eatery and calculate total cost
    eatery,
    DATE_TRUNC('month', stocking_date) :: DATE AS delivr_month,
    SUM(meal_cost * stocked_quantity) :: FLOAT AS cost
  FROM meals
  JOIN stock ON meals.meal_id = stock.meal_id
  -- Keep only the records after October 2018
  WHERE DATE_TRUNC('month', stocking_date) > '2018-10-01'
  GROUP BY eatery, delivr_month
  ORDER BY eatery, delivr_month;
$$)

-- Select the eatery and November and December 2018 as columns
AS ct (eatery TEXT,
       "2018-11-01" FLOAT,
       "2018-12-01" FLOAT)
ORDER BY eatery ASC;


-- Executive report
-- Import tablefunc
CREATE EXTENSION IF NOT EXISTS tablefunc;

-- Pivot the previous query by quarter
SELECT * FROM CROSSTAB($$
  WITH eatery_users AS  (
    SELECT
      eatery,
      -- Format the order date so "2018-06-01" becomes "Q2 2018"
      TO_CHAR(order_date, '"Q"Q YYYY') AS delivr_quarter,
      -- Count unique users
      COUNT(DISTINCT user_id) AS users
    FROM meals
    JOIN orders ON meals.meal_id = orders.meal_id
    GROUP BY eatery, delivr_quarter
    ORDER BY delivr_quarter, users)

  SELECT
    -- Select eatery and quarter
    eatery,
    delivr_quarter,
    -- Rank rows, partition by quarter and order by users
    RANK() OVER
      (PARTITION BY delivr_quarter
       ORDER BY users DESC) :: INT AS users_rank
  FROM eatery_users
  ORDER BY eatery, delivr_quarter;
$$)
-- Select the columns of the pivoted table
AS  ct (eatery TEXT,
        "Q2 2018" INT,
        "Q3 2018" INT,
        "Q4 2018" INT)
ORDER BY "Q4 2018";
