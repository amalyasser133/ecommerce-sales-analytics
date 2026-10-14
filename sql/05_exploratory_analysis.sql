USE ecommerce;

-- date range and size
SELECT MIN(order_date) AS first_order, MAX(order_date) AS last_order,
       COUNT(*) AS total_orders, COUNT(DISTINCT customer_id) AS buying_customers
FROM orders;

-- orders by status
SELECT status, COUNT(*) AS orders,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM orders GROUP BY status ORDER BY orders DESC;

-- prices per category
WITH ranked AS (
    SELECT category, unit_price,
           ROW_NUMBER() OVER (PARTITION BY category ORDER BY unit_price) AS rn,
           COUNT(*)     OVER (PARTITION BY category)                     AS cnt
    FROM products
)
SELECT category, COUNT(*) AS products,
       MIN(unit_price) AS min_price,
       ROUND(AVG(unit_price), 2) AS avg_price,
       ROUND(AVG(CASE WHEN rn IN (FLOOR((cnt + 1) / 2), CEIL((cnt + 1) / 2)) THEN unit_price END), 2) AS median_price,
       MAX(unit_price) AS max_price
FROM ranked GROUP BY category ORDER BY avg_price DESC;

-- customers per city
SELECT city, COUNT(*) AS customers,
       ROUND(100.0 * SUM(gender = 'Female') / COUNT(*), 1) AS female_pct
FROM customers GROUP BY city ORDER BY customers DESC;

-- items per order
SELECT items_in_order, COUNT(*) AS orders
FROM (SELECT order_id, COUNT(*) AS items_in_order FROM order_items GROUP BY order_id) t
GROUP BY items_in_order ORDER BY items_in_order;
