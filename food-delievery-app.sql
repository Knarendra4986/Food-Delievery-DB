-- ==========================================
-- Food Delivery Pro - Final Functional Version
-- ==========================================

DROP DATABASE IF EXISTS FoodDeliveryPro;
CREATE DATABASE FoodDeliveryPro;
USE FoodDeliveryPro;

-- ==========================================
-- 1) Core Tables
-- ==========================================

CREATE TABLE Customers (
    customer_id INT PRIMARY KEY AUTO_INCREMENT,
    full_name VARCHAR(80) NOT NULL,
    phone VARCHAR(15) UNIQUE,
    email VARCHAR(120) UNIQUE,
    address VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE Restaurants (
    restaurant_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(80) NOT NULL,
    location VARCHAR(100),
    rating DECIMAL(3,2) DEFAULT 0.00 CHECK (rating >= 0 AND rating <= 5),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE Menu_Items (
    item_id INT PRIMARY KEY AUTO_INCREMENT,
    restaurant_id INT NOT NULL,
    item_name VARCHAR(100) NOT NULL,
    category VARCHAR(40),
    price DECIMAL(8,2) NOT NULL CHECK (price >= 0),
    available TINYINT(1) DEFAULT 1,
    FOREIGN KEY (restaurant_id) REFERENCES Restaurants(restaurant_id)
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Delivery_Partners (
    partner_id INT PRIMARY KEY AUTO_INCREMENT,
    full_name VARCHAR(80) NOT NULL,
    phone VARCHAR(15) UNIQUE,
    vehicle_type VARCHAR(30)
);

CREATE TABLE Orders (
    order_id INT PRIMARY KEY AUTO_INCREMENT,
    customer_id INT NOT NULL,
    restaurant_id INT NOT NULL,
    partner_id INT NULL,
    order_date DATETIME NOT NULL,
    status VARCHAR(20) NOT NULL CHECK (status IN ('Pending','Preparing','OutForDelivery','Delivered','Cancelled')),
    coupon_code VARCHAR(30) NULL,
    total_amount DECIMAL(10,2) DEFAULT 0.00,
    FOREIGN KEY (customer_id) REFERENCES Customers(customer_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (restaurant_id) REFERENCES Restaurants(restaurant_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (partner_id) REFERENCES Delivery_Partners(partner_id)
        ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE TABLE Order_Details (
    order_id INT NOT NULL,
    item_id INT NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    PRIMARY KEY (order_id, item_id),
    FOREIGN KEY (order_id) REFERENCES Orders(order_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (item_id) REFERENCES Menu_Items(item_id)
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Payments (
    payment_id INT PRIMARY KEY AUTO_INCREMENT,
    order_id INT NOT NULL,
    payment_method VARCHAR(20) NOT NULL CHECK (payment_method IN ('Cash','Card','UPI','Wallet')),
    payment_status VARCHAR(20) NOT NULL CHECK (payment_status IN ('Pending','Completed','Failed','Refunded')),
    amount DECIMAL(10,2) NOT NULL CHECK (amount >= 0),
    paid_at DATETIME NULL,
    FOREIGN KEY (order_id) REFERENCES Orders(order_id)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- ==========================================
-- 2) Extensions
-- ==========================================

CREATE TABLE Reviews (
    review_id INT PRIMARY KEY AUTO_INCREMENT,
    order_id INT NOT NULL UNIQUE,
    restaurant_id INT NOT NULL,
    customer_id INT NOT NULL,
    rating TINYINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment VARCHAR(500),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES Orders(order_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (restaurant_id) REFERENCES Restaurants(restaurant_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (customer_id) REFERENCES Customers(customer_id)
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Coupons (
    coupon_code VARCHAR(30) PRIMARY KEY,
    description VARCHAR(200),
    discount_pct DECIMAL(5,2) NOT NULL CHECK (discount_pct BETWEEN 0 AND 100),
    max_discount DECIMAL(10,2) DEFAULT 0.00,
    valid_from DATE,
    valid_to DATE,
    active TINYINT(1) DEFAULT 1
);

CREATE TABLE Rewards_Accounts (
    customer_id INT PRIMARY KEY,
    current_points INT NOT NULL DEFAULT 0,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES Customers(customer_id)
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Rewards_Ledger (
    ledger_id INT PRIMARY KEY AUTO_INCREMENT,
    customer_id INT NOT NULL,
    order_id INT NULL,
    points_change INT NOT NULL,
    reason VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES Customers(customer_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (order_id) REFERENCES Orders(order_id)
        ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE TABLE Order_Status_History (
    hist_id INT PRIMARY KEY AUTO_INCREMENT,
    order_id INT NOT NULL,
    old_status VARCHAR(20),
    new_status VARCHAR(20) NOT NULL,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES Orders(order_id)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- ==========================================
-- 3) Indexes
-- ==========================================
CREATE INDEX idx_orders_date ON Orders(order_date);
CREATE INDEX idx_orders_restaurant ON Orders(restaurant_id);
CREATE INDEX idx_menu_restaurant ON Menu_Items(restaurant_id);

-- ==========================================
-- 4) Functions
-- ==========================================
DELIMITER $$
CREATE FUNCTION fn_order_subtotal(p_order_id INT)
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    DECLARE v_sub DECIMAL(10,2);
    SELECT IFNULL(SUM(od.quantity * mi.price),0)
      INTO v_sub
      FROM Order_Details od
      JOIN Menu_Items mi ON mi.item_id = od.item_id
     WHERE od.order_id = p_order_id;
    RETURN v_sub;
END$$
DELIMITER ;

DELIMITER $$
CREATE FUNCTION fn_order_final_amount(p_order_id INT)
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    DECLARE v_sub DECIMAL(10,2) DEFAULT 0.00;
    DECLARE v_coupon VARCHAR(30);
    DECLARE v_disc_pct DECIMAL(5,2) DEFAULT 0.00;
    DECLARE v_max_disc DECIMAL(10,2) DEFAULT 0.00;
    DECLARE v_discount DECIMAL(10,2) DEFAULT 0.00;
    DECLARE v_tax DECIMAL(10,2) DEFAULT 0.00;
    DECLARE v_rewards_redeemed DECIMAL(10,2) DEFAULT 0.00;

    SET v_sub = fn_order_subtotal(p_order_id);
    SELECT coupon_code INTO v_coupon FROM Orders WHERE order_id = p_order_id;

    IF v_coupon IS NOT NULL THEN
        SELECT discount_pct, IFNULL(max_discount,0) INTO v_disc_pct, v_max_disc
        FROM Coupons
        WHERE coupon_code = v_coupon
          AND active = 1
          AND (valid_from IS NULL OR valid_from <= CURDATE())
          AND (valid_to IS NULL OR valid_to >= CURDATE());
        IF v_disc_pct IS NULL THEN SET v_disc_pct = 0.00; END IF;
        SET v_discount = ROUND(LEAST(v_sub * (v_disc_pct/100.0), v_max_disc),2);
    END IF;

    SELECT IFNULL(SUM(-points_change),0) INTO v_rewards_redeemed
    FROM Rewards_Ledger
    WHERE order_id = p_order_id AND points_change < 0;

    SET v_tax = ROUND(0.05 * (v_sub - v_discount - v_rewards_redeemed),2);
    RETURN GREATEST(ROUND(v_sub - v_discount - v_rewards_redeemed + v_tax,2),0.00);
END$$
DELIMITER ;

-- ==========================================
-- 5) Triggers
-- ==========================================
DELIMITER $$
CREATE TRIGGER trg_review_after_insert
AFTER INSERT ON Reviews
FOR EACH ROW
BEGIN
    UPDATE Restaurants
    SET rating = (
        SELECT ROUND(AVG(rating),2) FROM Reviews WHERE restaurant_id = NEW.restaurant_id
    )
    WHERE restaurant_id = NEW.restaurant_id;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER trg_order_status_change
AFTER UPDATE ON Orders
FOR EACH ROW
BEGIN
    IF OLD.status <> NEW.status THEN
        INSERT INTO Order_Status_History(order_id, old_status, new_status)
        VALUES (NEW.order_id, OLD.status, NEW.status);
    END IF;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER trg_rewards_on_delivery
AFTER UPDATE ON Orders
FOR EACH ROW
BEGIN
    IF NEW.status = 'Delivered' AND OLD.status <> 'Delivered' THEN
        INSERT INTO Rewards_Ledger(customer_id, order_id, points_change, reason)
        VALUES (NEW.customer_id, NEW.order_id, ROUND(0.05 * NEW.total_amount), 'Delivery Reward');
        UPDATE Rewards_Accounts
        SET current_points = current_points + ROUND(0.05 * NEW.total_amount)
        WHERE customer_id = NEW.customer_id;
    END IF;
END$$
DELIMITER ;

-- ==========================================
-- 6) Procedures
-- ==========================================
DELIMITER $$
CREATE PROCEDURE sp_place_order(
    IN p_order_id INT,
    IN p_customer_id INT,
    IN p_restaurant_id INT,
    IN p_order_date DATETIME
)
BEGIN
    DECLARE v_order_id INT;

    START TRANSACTION;
    IF p_order_id IS NULL THEN
        INSERT INTO Orders(customer_id, restaurant_id, order_date, status)
        VALUES(p_customer_id, p_restaurant_id, p_order_date, 'Pending');
        SET v_order_id = LAST_INSERT_ID();
    ELSE
        INSERT INTO Orders(order_id, customer_id, restaurant_id, order_date, status)
        VALUES(p_order_id, p_customer_id, p_restaurant_id, p_order_date, 'Pending');
        SET v_order_id = p_order_id;
    END IF;

    INSERT INTO Order_Status_History(order_id, old_status, new_status)
    VALUES (v_order_id, NULL, 'Pending');
    COMMIT;
END$$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE sp_add_item(IN p_order_id INT, IN p_item_id INT, IN p_qty INT)
BEGIN
    INSERT INTO Order_Details(order_id, item_id, quantity)
    VALUES(p_order_id, p_item_id, p_qty)
    ON DUPLICATE KEY UPDATE quantity = quantity + p_qty;
END$$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE sp_apply_coupon(IN p_order_id INT, IN p_coupon VARCHAR(30))
BEGIN
    UPDATE Orders SET coupon_code = p_coupon WHERE order_id = p_order_id;
END$$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE sp_redeem_points(IN p_order_id INT, IN p_customer_id INT, IN p_points INT)
BEGIN
    UPDATE Rewards_Accounts
    SET current_points = current_points - p_points
    WHERE customer_id = p_customer_id AND current_points >= p_points;
    INSERT INTO Rewards_Ledger(customer_id, order_id, points_change, reason)
    VALUES(p_customer_id, p_order_id, -p_points, 'Points Redeemed');
END$$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE sp_finalize_order(IN p_order_id INT, IN p_partner_id INT, IN p_method VARCHAR(20), IN p_status VARCHAR(20))
BEGIN
    DECLARE v_amount DECIMAL(10,2);
    SET v_amount = fn_order_final_amount(p_order_id);
    UPDATE Orders SET partner_id = p_partner_id, total_amount = v_amount, status = 'Preparing'
    WHERE order_id = p_order_id;
    INSERT INTO Payments(order_id, payment_method, payment_status, amount, paid_at)
    VALUES(p_order_id, p_method, p_status, v_amount, NOW());
END$$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE sp_mark_status(IN p_order_id INT, IN p_status VARCHAR(20))
BEGIN
    UPDATE Orders SET status = p_status WHERE order_id = p_order_id;
END$$
DELIMITER ;

-- ==========================================
-- 7) Views
-- ==========================================
CREATE VIEW v_Daily_Sales AS
SELECT DATE(order_date) AS order_day, restaurant_id, SUM(total_amount) AS total_sales
FROM Orders
WHERE status = 'Delivered'
GROUP BY DATE(order_date), restaurant_id;

CREATE VIEW v_Top_Items AS
SELECT mi.item_name, SUM(od.quantity) AS total_sold
FROM Order_Details od
JOIN Menu_Items mi ON mi.item_id = od.item_id
GROUP BY mi.item_name
ORDER BY total_sold DESC;

CREATE VIEW v_Customer_LTV AS
SELECT c.customer_id, c.full_name, SUM(o.total_amount) AS lifetime_value
FROM Customers c
JOIN Orders o ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.full_name;

-- ==========================================
-- 8) Sample Data
-- ==========================================
-- (🚀 This is where I’ll insert 50+ customers, restaurants, menu items, orders, payments, reviews, coupons, rewards, and status history)

-- I’ll put that section in the **next message** because of length.
-- ==========================================
-- 8) Sample Data (Small Realistic Demo)
-- ==========================================

-- Customers
INSERT INTO Customers(full_name, phone, email, address) VALUES
('Ravi Kumar','9876543210','ravi@example.com','Hyderabad'),
('Priya Sharma','9876543211','priya@example.com','Bangalore'),
('Amit Verma','9876543212','amit@example.com','Pune'),
('Sneha Reddy','9876543213','sneha@example.com','Chennai'),
('Vikram Singh','9876543214','vikram@example.com','Delhi'),
('Kiran Rao','9876543215','kiran@example.com','Mumbai'),
('Anjali Mehta','9876543216','anjali@example.com','Hyderabad'),
('Rohit Yadav','9876543217','rohit@example.com','Pune'),
('Neha Kapoor','9876543218','neha@example.com','Chennai'),
('Arjun Das','9876543219','arjun@example.com','Delhi');

-- Restaurants
INSERT INTO Restaurants(name, location, rating) VALUES
('Biryani House','Hyderabad',4.5),
('Pizza Planet','Bangalore',4.2),
('Curry Point','Pune',4.0),
('Veggie Delight','Chennai',4.3),
('Tandoori Tales','Delhi',4.4);

-- Menu Items
INSERT INTO Menu_Items(restaurant_id, item_name, category, price) VALUES
(1,'Chicken Biryani','Main Course',250),
(1,'Veg Biryani','Main Course',200),
(2,'Margherita Pizza','Pizza',300),
(2,'Pepperoni Pizza','Pizza',350),
(3,'Butter Chicken','Main Course',280),
(3,'Paneer Butter Masala','Main Course',240),
(4,'Veg Thali','Combo',180),
(4,'Masala Dosa','Breakfast',120),
(5,'Tandoori Chicken','Starter',300),
(5,'Dal Makhani','Main Course',220);

-- Delivery Partners
INSERT INTO Delivery_Partners(full_name, phone, vehicle_type) VALUES
('Suresh Kumar','9000000001','Bike'),
('Manoj Reddy','9000000002','Scooter'),
('Pavan Sharma','9000000003','Bike');

-- Coupons
INSERT INTO Coupons VALUES
('DISC10','10% Off',10,100,'2025-08-01','2025-08-31',1),
('FREEDLV','Free Delivery',5,50,'2025-08-01','2025-09-01',1);

-- Rewards Accounts
INSERT INTO Rewards_Accounts(customer_id, current_points) VALUES
(1,50),(2,30),(3,20),(4,10),(5,5),(6,15),(7,25),(8,35),(9,0),(10,12);

-- Orders
INSERT INTO Orders(customer_id, restaurant_id, partner_id, order_date, status, coupon_code, total_amount) VALUES
(1,1,1,'2025-08-10 12:30:00','Delivered','DISC10',450),
(2,2,2,'2025-08-11 14:10:00','Delivered',NULL,300),
(3,3,1,'2025-08-12 19:00:00','OutForDelivery','FREEDLV',280),
(4,4,3,'2025-08-13 08:50:00','Preparing',NULL,180),
(5,5,2,'2025-08-14 20:15:00','Cancelled',NULL,0);

-- Order Details
INSERT INTO Order_Details VALUES
(1,1,1),(1,2,1), -- Order 1
(2,3,1), -- Order 2
(3,5,1), -- Order 3
(4,7,1), -- Order 4
(5,9,1); -- Order 5

-- Payments
INSERT INTO Payments(order_id, payment_method, payment_status, amount, paid_at) VALUES
(1,'Cash','Completed',450,'2025-08-10 12:40:00'),
(2,'UPI','Completed',300,'2025-08-11 14:15:00'),
(3,'Card','Pending',280,NULL),
(4,'Wallet','Pending',180,NULL);

-- Reviews
INSERT INTO Reviews(order_id, restaurant_id, customer_id, rating, comment) VALUES
(1,1,1,5,'Excellent biryani!'),
(2,2,2,4,'Pizza was tasty'),
(3,3,3,4,'Good food, delivery was a bit late');

-- Rewards Ledger
INSERT INTO Rewards_Ledger(customer_id, order_id, points_change, reason) VALUES
(1,1,23,'Delivery Reward'),
(2,2,15,'Delivery Reward'),
(3,3,-10,'Points Redeemed');

-- Order Status History
INSERT INTO Order_Status_History(order_id, old_status, new_status, changed_at) VALUES
(1,NULL,'Pending','2025-08-10 12:00:00'),
(1,'Pending','Preparing','2025-08-10 12:10:00'),
(1,'Preparing','OutForDelivery','2025-08-10 12:20:00'),
(1,'OutForDelivery','Delivered','2025-08-10 12:35:00'),
(2,NULL,'Pending','2025-08-11 14:00:00'),
(2,'Pending','Preparing','2025-08-11 14:05:00'),
(2,'Preparing','OutForDelivery','2025-08-11 14:08:00'),
(2,'OutForDelivery','Delivered','2025-08-11 14:12:00');


/*
-- Top 5 Best-Selling Menu Items ---
SELECT mi.item_name, SUM(od.quantity) AS total_sold
FROM Order_Details od
JOIN Menu_Items mi ON od.item_id = mi.item_id
GROUP BY mi.item_name
ORDER BY total_sold DESC
LIMIT 5;

-- Sales Summary by Restaurant
SELECT r.name AS restaurant, SUM(o.total_amount) AS total_sales, COUNT(o.order_id) AS total_orders
FROM Orders o
JOIN Restaurants r ON o.restaurant_id = r.restaurant_id
WHERE o.status = 'Delivered'
GROUP BY r.name
ORDER BY total_sales DESC;

-- Customer Lifetime Value (LTV)
SELECT c.full_name, SUM(o.total_amount) AS lifetime_value, COUNT(o.order_id) AS orders_count
FROM Customers c
JOIN Orders o ON c.customer_id = o.customer_id
WHERE o.status = 'Delivered'
GROUP BY c.customer_id, c.full_name
ORDER BY lifetime_value DESC;

-- Average Delivery Time for Completed Orders
SELECT o.order_id, TIMESTAMPDIFF(MINUTE, MIN(h.changed_at), MAX(h.changed_at)) AS delivery_time_minutes
FROM Order_Status_History h
JOIN Orders o ON h.order_id = o.order_id
WHERE o.status = 'Delivered'
GROUP BY o.order_id;

-- Rewards Points Activity
SELECT c.full_name, r.points_change, r.reason, r.created_at
FROM Rewards_Ledger r
JOIN Customers c ON r.customer_id = c.customer_id
ORDER BY r.created_at DESC;

-- Coupon Usage Report
SELECT o.coupon_code, COUNT(o.order_id) AS used_count, SUM(o.total_amount) AS total_sales
FROM Orders o
WHERE o.coupon_code IS NOT NULL
GROUP BY o.coupon_code
ORDER BY used_count DESC;

*/