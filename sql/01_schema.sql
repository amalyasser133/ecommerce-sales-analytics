-- tables for the online store
CREATE DATABASE IF NOT EXISTS ecommerce CHARACTER SET utf8mb4;
USE ecommerce;

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS order_items, orders, products, customers;
SET FOREIGN_KEY_CHECKS = 1;

CREATE TABLE customers (
    customer_id  INT PRIMARY KEY,
    full_name    VARCHAR(100) NOT NULL,
    email        VARCHAR(150) NOT NULL UNIQUE,
    gender       VARCHAR(10),
    city         VARCHAR(50)  NOT NULL,
    signup_date  DATE         NOT NULL,
    CONSTRAINT chk_gender CHECK (gender IN ('Male', 'Female'))
) ENGINE=InnoDB;

CREATE TABLE products (
    product_id    INT PRIMARY KEY,
    product_name  VARCHAR(100) NOT NULL,
    category      VARCHAR(50)  NOT NULL,
    unit_price    DECIMAL(10,2) NOT NULL,
    unit_cost     DECIMAL(10,2) NOT NULL,
    CONSTRAINT chk_price CHECK (unit_price > 0),
    CONSTRAINT chk_cost  CHECK (unit_cost > 0)
) ENGINE=InnoDB;

CREATE TABLE orders (
    order_id        INT PRIMARY KEY,
    customer_id     INT NOT NULL,
    order_date      DATE NOT NULL,
    status          VARCHAR(20) NOT NULL,
    payment_method  VARCHAR(30) NOT NULL,
    CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    CONSTRAINT chk_status CHECK (status IN ('Completed', 'Cancelled', 'Returned'))
) ENGINE=InnoDB;

CREATE TABLE order_items (
    order_item_id  INT PRIMARY KEY,
    order_id       INT NOT NULL,
    product_id     INT NOT NULL,
    quantity       INT NOT NULL,
    unit_price     DECIMAL(10,2) NOT NULL,
    discount       DECIMAL(3,2)  NOT NULL DEFAULT 0,
    CONSTRAINT fk_items_order   FOREIGN KEY (order_id)   REFERENCES orders(order_id),
    CONSTRAINT fk_items_product FOREIGN KEY (product_id) REFERENCES products(product_id),
    CONSTRAINT chk_qty      CHECK (quantity > 0),
    CONSTRAINT chk_discount CHECK (discount BETWEEN 0 AND 1)
) ENGINE=InnoDB;

CREATE INDEX idx_orders_date   ON orders (order_date);
CREATE INDEX idx_orders_status ON orders (status);
-- foreign keys get indexes automatically
