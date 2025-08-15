-- ==========================================
-- Food Delivery Pro - Demo & Test Queries
-- ==========================================

USE FoodDeliveryPro;

-- -------------------------------
-- 1️⃣ Top 5 Best-Selling Menu Items
-- -------------------------------
SELECT 'Top 5 Best-Selling Menu Items' AS Section_Header;
SELECT mi.item_name, SUM(od.quantity) AS total_sold
FROM Order_Details od
JOIN Menu_Items mi ON od.item_id = mi.item_id
GROUP BY mi.item_name
ORDER BY total_sold DESC
LIMIT 5;

-- -------------------------------
-- 2️⃣ Sales Summary by Restaurant
-- -------------------------------
SELECT 'Sales Summary by Restaurant' AS Section_Header;
SELECT r.name AS restaurant, SUM(o.total_amount) AS total_sales, COUNT(o.order_id) AS total_orders
FROM Orders o
JOIN Restaurants r ON o.restaurant_id = r.restaurant_id
WHERE o.status = 'Delivered'
GROUP BY r.name
ORDER BY total_sales DESC;

-- -------------------------------
-- 3️⃣ Customer Lifetime Value
-- -------------------------------
SELECT 'Customer Lifetime Value (LTV)' AS Section_Header;
SELECT c.full_name, SUM(o.total_amount) AS lifetime_value, COUNT(o.order_id) AS orders_count
FROM Customers c
JOIN Orders o ON c.customer_id = o.customer_id
WHERE o.status = 'Delivered'
GROUP BY c.customer_id, c.full_name
ORDER BY lifetime_value DESC;

-- -------------------------------
-- 4️⃣ Average Delivery Time for Delivered Orders
-- -------------------------------
SELECT 'Average Delivery Time (minutes)' AS Section_Header;
SELECT o.order_id, TIMESTAMPDIFF(MINUTE, MIN(h.changed_at), MAX(h.changed_at)) AS delivery_time_minutes
FROM Order_Status_History h
JOIN Orders o ON h.order_id = o.order_id
WHERE o.status = 'Delivered'
GROUP BY o.order_id;

-- -------------------------------
-- 5️⃣ Rewards Points Activity
-- -------------------------------
SELECT 'Rewards Points Activity' AS Section_Header;
SELECT c.full_name, r.points_change, r.reason, r.created_at
FROM Rewards_Ledger r
JOIN Customers c ON r.customer_id = c.customer_id
ORDER BY r.created_at DESC;

-- -------------------------------
-- 6️⃣ Coupon Usage Report
-- -------------------------------
SELECT 'Coupon Usage Report' AS Section_Header;
SELECT o.coupon_code, COUNT(o.order_id) AS used_count, SUM(o.total_amount) AS total_sales
FROM Orders o
WHERE o.coupon_code IS NOT NULL
GROUP BY o.coupon_code
ORDER BY used_count DESC;

-- End of Demo Script
