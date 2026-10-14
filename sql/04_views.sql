USE ecommerce;

-- main view: one row per item sold (completed orders only)
CREATE OR REPLACE VIEW vw_sales_fact AS
SELECT oi.order_item_id,
       o.order_id,
       o.order_date,
       o.customer_id,
       c.city,
       o.payment_method,
       p.product_id,
       p.product_name,
       p.category,
       oi.quantity,
       oi.unit_price,
       oi.discount,
       ROUND(oi.quantity * oi.unit_price * (1 - oi.discount), 2)                 AS net_revenue,
       ROUND(oi.quantity * (oi.unit_price * (1 - oi.discount) - p.unit_cost), 2) AS profit
FROM order_items oi
JOIN orders    o ON o.order_id    = oi.order_id
JOIN customers c ON c.customer_id = o.customer_id
JOIN products  p ON p.product_id  = oi.product_id
WHERE o.status = 'Completed';

-- monthly numbers and growth
CREATE OR REPLACE VIEW vw_monthly_kpis AS
WITH monthly AS (
    SELECT CAST(DATE_FORMAT(order_date, '%Y-%m-01') AS DATE) AS month,
           SUM(net_revenue)            AS revenue,
           SUM(profit)                 AS profit,
           COUNT(DISTINCT order_id)    AS orders,
           COUNT(DISTINCT customer_id) AS active_customers
    FROM vw_sales_fact
    GROUP BY CAST(DATE_FORMAT(order_date, '%Y-%m-01') AS DATE)
)
SELECT month, revenue, profit, orders, active_customers,
       ROUND(revenue / orders, 2) AS avg_order_value,
       ROUND(100.0 * (revenue - LAG(revenue)     OVER w) / NULLIF(LAG(revenue)     OVER w, 0), 2) AS mom_growth_pct,
       ROUND(100.0 * (revenue - LAG(revenue, 12) OVER w) / NULLIF(LAG(revenue, 12) OVER w, 0), 2) AS yoy_growth_pct
FROM monthly
WINDOW w AS (ORDER BY month);

-- customer segments (RFM)
CREATE OR REPLACE VIEW vw_customer_rfm AS
WITH snapshot AS (SELECT MAX(order_date) AS d FROM vw_sales_fact),
rfm AS (
    SELECT f.customer_id,
           DATEDIFF(s.d, MAX(f.order_date)) AS recency_days,
           COUNT(DISTINCT f.order_id)       AS frequency,
           SUM(f.net_revenue)               AS monetary
    FROM vw_sales_fact f CROSS JOIN snapshot s
    GROUP BY f.customer_id, s.d
),
scored AS (
    SELECT customer_id, recency_days, frequency, monetary,
           NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
           NTILE(5) OVER (ORDER BY frequency)         AS f_score,
           NTILE(5) OVER (ORDER BY monetary)          AS m_score
    FROM rfm
)
SELECT customer_id, recency_days, frequency, monetary, r_score, f_score, m_score,
       CASE WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
            WHEN r_score >= 3 AND f_score >= 3                  THEN 'Loyal Customers'
            WHEN r_score >= 4 AND f_score <= 2                  THEN 'New / Promising'
            WHEN r_score <= 2 AND f_score >= 3                  THEN 'At Risk'
            WHEN r_score <= 2 AND f_score <= 2                  THEN 'Lost'
            ELSE 'Need Attention'
       END AS segment
FROM scored;

-- retention by signup month
CREATE OR REPLACE VIEW vw_cohort_retention AS
WITH first_order AS (
    SELECT customer_id, CAST(DATE_FORMAT(MIN(order_date), '%Y-%m-01') AS DATE) AS cohort_month
    FROM vw_sales_fact GROUP BY customer_id
),
activity AS (
    SELECT DISTINCT f.customer_id, fo.cohort_month,
           (YEAR(f.order_date) - YEAR(fo.cohort_month)) * 12
         + (MONTH(f.order_date) - MONTH(fo.cohort_month)) AS month_index
    FROM vw_sales_fact f
    JOIN first_order fo ON fo.customer_id = f.customer_id
),
cohort_size AS (SELECT cohort_month, COUNT(*) AS size FROM first_order GROUP BY cohort_month)
SELECT a.cohort_month, a.month_index, cs.size AS cohort_size,
       COUNT(*) AS active_customers,
       ROUND(100.0 * COUNT(*) / cs.size, 1) AS retention_pct
FROM activity a
JOIN cohort_size cs ON cs.cohort_month = a.cohort_month
GROUP BY a.cohort_month, a.month_index, cs.size;
