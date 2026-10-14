USE ecommerce;

-- rows in each table
SELECT 'customers' AS tbl, COUNT(*) AS row_count FROM customers
UNION ALL SELECT 'products',    COUNT(*) FROM products
UNION ALL SELECT 'orders',      COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items;

-- duplicate emails
SELECT email, COUNT(*) FROM customers GROUP BY email HAVING COUNT(*) > 1;

-- orders with no items
SELECT o.order_id FROM orders o
LEFT JOIN order_items oi ON oi.order_id = o.order_id
WHERE oi.order_id IS NULL;

-- orders placed before the customer signed up
SELECT o.order_id, o.order_date, c.signup_date
FROM orders o JOIN customers c ON c.customer_id = o.customer_id
WHERE o.order_date < c.signup_date;

-- order price different from product price
SELECT oi.order_item_id, oi.unit_price, p.unit_price AS master_price
FROM order_items oi JOIN products p ON p.product_id = oi.product_id
WHERE oi.unit_price <> p.unit_price;

-- items sold below cost
SELECT oi.order_item_id, oi.unit_price * (1 - oi.discount) AS net_price, p.unit_cost
FROM order_items oi JOIN products p ON p.product_id = oi.product_id
WHERE oi.unit_price * (1 - oi.discount) < p.unit_cost;

-- future dates and nulls
SELECT COUNT(*) AS future_orders FROM orders WHERE order_date > CURRENT_DATE;
SELECT COUNT(*) AS null_customer_fields FROM customers WHERE city IS NULL OR signup_date IS NULL;
