# 🍔 Food Delivery Pro – SQL Database Project

## About
**Food Delivery Pro** is a fully functional SQL-based database project designed to manage and analyze an online food ordering and delivery system.  
It includes **realistic schema**, **mock data**, **stored procedures**, **triggers**, **functions**, **views**, and **analytical queries** to simulate real-world operations.


<img width="1269" height="758" alt="Screenshot 2025-08-15 192934" src="https://github.com/user-attachments/assets/abfbfb08-1d12-423d-ad68-3024c9bb0dd5" />

## 🚀 Features

### **Core Functionalities**
- **Customer Management** – Stores personal info, contact details, and reward points.
- **Restaurant Management** – Keeps track of multiple restaurants, locations, and ratings.
- **Menu Items** – Categorized items with prices and availability.
- **Orders & Order Details** – Handles order creation, status updates, and item details.
- **Delivery Partners** – Manages riders/drivers and assigned orders.
- **Payments** – Tracks payment methods, amounts, and statuses.

### **Extended Features**
- **Coupons** – Supports discounts with validity periods.
- **Rewards System** – Points earned & redeemed for orders.
- **Reviews** – Customer feedback with auto rating updates via triggers.
- **Order Status History** – Logs each change in order status.
- **Analytics Views** – Predefined views for sales, top items, and customer lifetime value.

---

## 📂 Database Structure

**Main Tables**
- `Customers`
- `Restaurants`
- `Menu_Items`
- `Orders`
- `Order_Details`
- `Delivery_Partners`
- `Payments`

**Extended Tables**
- `Coupons`
- `Rewards_Accounts`
- `Rewards_Ledger`
- `Reviews`
- `Order_Status_History`

---

## ⚙️ Technical Highlights
- **Stored Procedures** for order creation, item addition, coupon application, and payment finalization.
- **Triggers** for auto reward point allocation and restaurant rating updates.
- **Functions** for calculating order subtotal and final payable amount.
- **Views** for quick analytics like top items and sales reports.
- **Sample Data** for immediate testing.

---

## 📊 Demo Analytics Queries
Includes **6 pre-written queries** for:
1. Top-selling items
2. Sales summary by restaurant
3. Customer Lifetime Value (LTV)
4. Average delivery time
5. Rewards points activity
6. Coupon usage report

---

## 🛠 How to Run

### **1. Setup Database**
Run:
```sql
SOURCE FoodDeliveryPro_Main.sql;
