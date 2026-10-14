USE ecommerce;

-- total revenue, profit, orders
SELECT SUM(net_revenue)                                   AS total_revenue,
       SUM(profit)                                        AS total_profit,
       ROUND(100.0 * SUM(profit) / SUM(net_revenue), 2)   AS profit_margin_pct,
       COUNT(DISTINCT order_id)                           AS completed_orders,
       COUNT(DISTINCT customer_id)                        AS customers,
       ROUND(SUM(net_revenue) / COUNT(DISTINCT order_id), 2) AS avg_order_value
FROM vw_sales_fact;

-- monthly revenue and growth
SELECT month, revenue, mom_growth_pct, yoy_growth_pct,
       SUM(revenue) OVER (ORDER BY month) AS running_revenue,
       ROUND(AVG(revenue) OVER (ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS moving_avg_3m
FROM vw_monthly_kpis
ORDER BY month;

-- revenue and margin per category
SELECT category,
       SUM(net_revenue) AS revenue,
       ROUND(100.0 * SUM(net_revenue) / SUM(SUM(net_revenue)) OVER (), 2) AS revenue_share_pct,
       ROUND(100.0 * SUM(profit) / SUM(net_revenue), 2)                   AS margin_pct
FROM vw_sales_fact GROUP BY category ORDER BY revenue DESC;

-- top 3 products in each category
SELECT * FROM (
    SELECT category, product_name, SUM(net_revenue) AS revenue,
           RANK() OVER (PARTITION BY category ORDER BY SUM(net_revenue) DESC) AS rnk
    FROM vw_sales_fact GROUP BY category, product_name
) t WHERE rnk <= 3 ORDER BY category, rnk;

-- how many customers make 80% of revenue
WITH cust AS (
    SELECT customer_id, SUM(net_revenue) AS revenue FROM vw_sales_fact GROUP BY customer_id
), ranked AS (
    SELECT customer_id, revenue,
           SUM(revenue) OVER (ORDER BY revenue DESC) AS cum_revenue,
           SUM(revenue) OVER ()                      AS total_revenue,
           ROW_NUMBER() OVER (ORDER BY revenue DESC) AS rn,
           COUNT(*) OVER ()                          AS n_customers
    FROM cust
)
SELECT MIN(rn) AS customers_for_80pct_revenue,
       ROUND(100.0 * MIN(rn) / MAX(n_customers), 1) AS pct_of_customer_base
FROM ranked WHERE cum_revenue >= 0.8 * total_revenue;

-- customer segments summary
SELECT segment, COUNT(*) AS customers,
       ROUND(SUM(monetary), 2) AS revenue,
       ROUND(AVG(monetary), 2) AS avg_revenue_per_customer,
       ROUND(AVG(recency_days), 0) AS avg_recency_days
FROM vw_customer_rfm GROUP BY segment ORDER BY revenue DESC;

-- retention table
SELECT cohort_month, cohort_size,
       MAX(CASE WHEN month_index = 0 THEN retention_pct END) AS m0,
       MAX(CASE WHEN month_index = 1 THEN retention_pct END) AS m1,
       MAX(CASE WHEN month_index = 2 THEN retention_pct END) AS m2,
       MAX(CASE WHEN month_index = 3 THEN retention_pct END) AS m3,
       MAX(CASE WHEN month_index = 6 THEN retention_pct END) AS m6
FROM vw_cohort_retention GROUP BY cohort_month, cohort_size ORDER BY cohort_month;

-- products bought together
SELECT a.product_name AS product_a, b.product_name AS product_b,
       COUNT(*) AS times_bought_together
FROM vw_sales_fact a
JOIN vw_sales_fact b ON a.order_id = b.order_id AND a.product_id < b.product_id
GROUP BY 1, 2 ORDER BY times_bought_together DESC LIMIT 10;

-- cancel and return rate per payment method
SELECT payment_method, COUNT(*) AS orders,
       ROUND(100.0 * SUM(status = 'Cancelled') / COUNT(*), 2) AS cancel_rate_pct,
       ROUND(100.0 * SUM(status = 'Returned') / COUNT(*), 2) AS return_rate_pct
FROM orders GROUP BY payment_method ORDER BY cancel_rate_pct DESC;

-- revenue per city
SELECT city, COUNT(DISTINCT customer_id) AS customers,
       SUM(net_revenue) AS revenue,
       ROUND(SUM(net_revenue) / COUNT(DISTINCT customer_id), 2) AS revenue_per_customer,
       DENSE_RANK() OVER (ORDER BY SUM(net_revenue) DESC) AS revenue_rank
FROM vw_sales_fact GROUP BY city ORDER BY revenue DESC;

-- effect of discounts
SELECT CASE WHEN discount = 0 THEN '0% (no discount)'
            WHEN discount <= .10 THEN '5-10%'
            ELSE '15-20%' END AS discount_tier,
       SUM(quantity) AS units_sold,
       SUM(net_revenue) AS revenue,
       ROUND(100.0 * SUM(profit) / SUM(net_revenue), 2) AS margin_pct
FROM vw_sales_fact GROUP BY 1 ORDER BY 1;

-- sales per weekday
SELECT DATE_FORMAT(order_date, '%a') AS weekday, WEEKDAY(order_date) + 1 AS dow,
       COUNT(DISTINCT order_id) AS orders, SUM(net_revenue) AS revenue
FROM vw_sales_fact GROUP BY 1, 2 ORDER BY 2;
