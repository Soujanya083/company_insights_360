-- ============================================================
-- Company Insights 360° — Schema Creation (PostgreSQL)
-- ============================================================
-- Run these in order (tables reference each other via FKs)

-- 1. PLANS (no dependencies)
CREATE TABLE plans (
    plan_id        INTEGER PRIMARY KEY,
    plan_name      VARCHAR(50) NOT NULL,
    monthly_price  NUMERIC(10,2) NOT NULL
);

-- 2. CUSTOMERS (no dependencies)
-- Note: raw import will have duplicates + messy casing on purpose — clean AFTER loading raw data,
-- or load into a staging table first (see Step 3 below).
CREATE TABLE customers_raw (
    customer_id           INTEGER,
    signup_date           DATE,
    country                VARCHAR(100),
    company_size          VARCHAR(20),
    acquisition_channel   VARCHAR(50)
);

-- Final clean customers table (populate this via a cleaning query, not direct import)
CREATE TABLE customers (
    customer_id           INTEGER PRIMARY KEY,
    signup_date           DATE NOT NULL,
    country                VARCHAR(100),
    company_size          VARCHAR(20),
    acquisition_channel   VARCHAR(50)
);

-- 3. SUBSCRIPTIONS (depends on customers, plans)
CREATE TABLE subscriptions (
    subscription_id  INTEGER PRIMARY KEY,
    customer_id      INTEGER NOT NULL REFERENCES customers(customer_id),
    plan_id          INTEGER NOT NULL REFERENCES plans(plan_id),
    start_date       DATE NOT NULL,
    end_date         DATE,              -- NULL = still active
    status           VARCHAR(20) NOT NULL CHECK (status IN ('active','churned'))
);

-- 4. USAGE_EVENTS (depends on customers)
CREATE TABLE usage_events (
    event_id        INTEGER PRIMARY KEY,
    customer_id     INTEGER NOT NULL REFERENCES customers(customer_id),
    event_date      DATE NOT NULL,
    feature_used    VARCHAR(50),
    session_count   INTEGER
);

-- 5. PAYMENTS (depends on subscriptions)
CREATE TABLE payments (
    payment_id        INTEGER PRIMARY KEY,
    subscription_id   INTEGER NOT NULL REFERENCES subscriptions(subscription_id),
    payment_date      DATE NOT NULL,
    amount            NUMERIC(10,2),
    payment_status    VARCHAR(20) CHECK (payment_status IN ('success','failed'))
);

-- ============================================================
-- Helpful indexes (add after loading data, speeds up joins)
-- ============================================================
CREATE INDEX idx_subscriptions_customer ON subscriptions(customer_id);
CREATE INDEX idx_subscriptions_plan ON subscriptions(plan_id);
CREATE INDEX idx_usage_customer ON usage_events(customer_id);
CREATE INDEX idx_payments_subscription ON payments(subscription_id);
