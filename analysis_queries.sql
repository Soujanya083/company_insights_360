-- ============================================================
-- Company Insights 360° — Business Analysis Queries
-- Run after schema creation and data loading are complete.
-- ============================================================

-- ------------------------------------------------------------
-- Q1: Which plan tier retains customers best?
-- ------------------------------------------------------------
SELECT
    p.plan_name,
    COUNT(*) AS total_customers,
    SUM(CASE WHEN s.status = 'churned' THEN 1 ELSE 0 END) AS churned_customers,
    ROUND(100.0 * SUM(CASE WHEN s.status = 'churned' THEN 1 ELSE 0 END) / COUNT(*), 2) AS churn_rate_pct
FROM subscriptions s
JOIN plans p ON s.plan_id = p.plan_id
GROUP BY p.plan_name
ORDER BY churn_rate_pct DESC;


-- ------------------------------------------------------------
-- Q2: Are certain acquisition channels bringing in higher-churn customers?
-- ------------------------------------------------------------
SELECT
    c.acquisition_channel,
    COUNT(*) AS total_customers,
    SUM(CASE WHEN s.status = 'churned' THEN 1 ELSE 0 END) AS churned_customers,
    ROUND(100.0 * SUM(CASE WHEN s.status = 'churned' THEN 1 ELSE 0 END) / COUNT(*), 2) AS churn_rate_pct
FROM customers c
JOIN subscriptions s ON c.customer_id = s.customer_id
GROUP BY c.acquisition_channel
ORDER BY churn_rate_pct DESC;


-- ------------------------------------------------------------
-- Q3: Does product usage predict churn?
-- ------------------------------------------------------------
WITH customer_usage AS (
    SELECT
        customer_id,
        COUNT(*) AS total_events,
        SUM(session_count) AS total_sessions
    FROM usage_events
    GROUP BY customer_id
)
SELECT
    s.status,
    COUNT(*) AS num_customers,
    ROUND(AVG(COALESCE(cu.total_events, 0)), 1) AS avg_usage_events,
    ROUND(AVG(COALESCE(cu.total_sessions, 0)), 1) AS avg_sessions
FROM subscriptions s
LEFT JOIN customer_usage cu ON s.customer_id = cu.customer_id
GROUP BY s.status;


-- ------------------------------------------------------------
-- Q4: What's the MRR trend over time?
-- ------------------------------------------------------------
SELECT
    DATE_TRUNC('month', payment_date) AS month,
    SUM(amount) AS mrr,
    COUNT(DISTINCT subscription_id) AS paying_subscriptions
FROM payments
WHERE payment_status = 'success'
GROUP BY DATE_TRUNC('month', payment_date)
ORDER BY month;


-- ------------------------------------------------------------
-- Q5: Are failed payments a churn driver?
-- ------------------------------------------------------------

-- First attempt (kept for documentation — shows an exposure-time bias):
-- Raw counts make active customers look "worse" simply because they've
-- been paying longer and had more chances for any single failure.
--
-- SELECT s.status, ROUND(AVG(failed_payments), 2) AS avg_failed_payments
-- FROM subscriptions s
-- LEFT JOIN (
--     SELECT subscription_id, SUM(CASE WHEN payment_status = 'failed' THEN 1 ELSE 0 END) AS failed_payments
--     FROM payments GROUP BY subscription_id
-- ) ph ON s.subscription_id = ph.subscription_id
-- GROUP BY s.status;

-- Corrected version — uses failure RATE, not raw count, to control for
-- how many total payments each customer had a chance to fail on:
WITH payment_health AS (
    SELECT
        subscription_id,
        COUNT(*) AS total_payments,
        ROUND(100.0 * SUM(CASE WHEN payment_status = 'failed' THEN 1 ELSE 0 END) / COUNT(*), 2) AS failure_rate_pct
    FROM payments
    GROUP BY subscription_id
)
SELECT
    s.status,
    COUNT(*) AS num_customers,
    ROUND(AVG(ph.failure_rate_pct), 2) AS avg_failure_rate_pct
FROM subscriptions s
LEFT JOIN payment_health ph ON s.subscription_id = ph.subscription_id
GROUP BY s.status;
