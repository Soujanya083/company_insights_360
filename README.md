# Company Insights 360°

A SQL-driven analysis of a SaaS subscription business — churn drivers, revenue
trends, and usage patterns — built on a custom-designed 5-table relational
schema in PostgreSQL.

## Why this project

Most portfolio SQL projects use a single flat CSV and answer someone else's
pre-written question list. This one is different on purpose:

- **Custom relational schema** — 5 related tables (customers, plans,
  subscriptions, usage_events, payments) with proper primary/foreign keys,
  not one flat table
- **Original business questions** — framed and investigated as if I were
  the company's founder, not copied from a tutorial
- **Real data cleaning** — the raw customer data has duplicates and
  inconsistent formatting, handled via a staging table + cleaning query
- **Self-corrected analysis** — Question 5 below shows a case where my
  first query was misleading due to a statistical bias, and how I caught
  and fixed it

## Schema

```
customers (customer_id PK)
    |
    | 1---1                        plans (plan_id PK)
    v                                  |
subscriptions (subscription_id PK) ----+
    |                    |
    | 1---N               N---1
    v
payments (payment_id PK)

customers (customer_id PK)
    |
    | 1---N
    v
usage_events (event_id PK)
```

See `01_create_schema.sql` for full DDL with constraints and indexes.

## Data Cleaning

Raw customer data was loaded into a `customers_raw` staging table containing
intentional real-world messiness: duplicate rows and inconsistent country
name casing (e.g. "INDIA" vs "India"). Cleaned via:

```sql
INSERT INTO customers (customer_id, signup_date, country, company_size, acquisition_channel)
SELECT DISTINCT ON (customer_id)
    customer_id, signup_date, INITCAP(country), COALESCE(company_size, 'Unknown'), acquisition_channel
FROM customers_raw
ORDER BY customer_id;
```

Full details in `02_loading_guide.md`.

---

## Business Questions & Findings

### 1. Which plan tier retains customers best?

```sql
SELECT p.plan_name, COUNT(*) AS total_customers,
       SUM(CASE WHEN s.status = 'churned' THEN 1 ELSE 0 END) AS churned_customers,
       ROUND(100.0 * SUM(CASE WHEN s.status = 'churned' THEN 1 ELSE 0 END) / COUNT(*), 2) AS churn_rate_pct
FROM subscriptions s
JOIN plans p ON s.plan_id = p.plan_id
GROUP BY p.plan_name
ORDER BY churn_rate_pct DESC;
```

| Plan | Customers | Churn Rate |
|---|---|---|
| Basic | 326 | 57.06% |
| Pro | 305 | 44.59% |
| Enterprise | 175 | 37.71% |

**Finding:** Churn rate drops sharply as plan tier rises. Basic customers
churn at over 1.5x the rate of Enterprise customers.

**Why it matters:** Suggests either a commitment effect (bigger spend = more
serious usage) or a fit effect (Basic attracts lower-intent trial users).

**Recommendation:** Investigate whether Basic users who upgrade to Pro within
their first month retain meaningfully better — this would clarify whether the
issue is the tier itself or who lands there.

---

### 2. Are certain acquisition channels bringing in lower-quality (higher-churn) customers?

```sql
SELECT c.acquisition_channel, COUNT(*) AS total_customers,
       SUM(CASE WHEN s.status = 'churned' THEN 1 ELSE 0 END) AS churned_customers,
       ROUND(100.0 * SUM(CASE WHEN s.status = 'churned' THEN 1 ELSE 0 END) / COUNT(*), 2) AS churn_rate_pct
FROM customers c
JOIN subscriptions s ON c.customer_id = s.customer_id
GROUP BY c.acquisition_channel
ORDER BY churn_rate_pct DESC;
```

| Channel | Customers | Churn Rate |
|---|---|---|
| Social Media | 108 | 62.04% |
| Cold Outreach | 60 | 61.67% |
| Paid Ads | 165 | 52.73% |
| Organic Search | 255 | 45.10% |
| Referral | 151 | 38.41% |
| Partner | 67 | 35.82% |

**Finding:** Paid/outbound channels (Social Media, Cold Outreach, Paid Ads)
churn ~55-60%, versus ~35-45% for organic/earned channels (Organic Search,
Referral, Partner).

**Why it matters:** This has direct marketing ROI implications — if paid
channels are also expensive per acquisition, the company may be losing money
on these customers once churn is factored in.

**Recommendation:** Calculate CAC payback period by channel; consider
shifting budget toward referral incentive programs given their strong
retention.

---

### 3. Does product usage predict churn?

```sql
WITH customer_usage AS (
    SELECT customer_id, COUNT(*) AS total_events, SUM(session_count) AS total_sessions
    FROM usage_events GROUP BY customer_id
)
SELECT s.status, COUNT(*) AS num_customers,
       ROUND(AVG(COALESCE(cu.total_events, 0)), 1) AS avg_usage_events,
       ROUND(AVG(COALESCE(cu.total_sessions, 0)), 1) AS avg_sessions
FROM subscriptions s
LEFT JOIN customer_usage cu ON s.customer_id = cu.customer_id
GROUP BY s.status;
```

| Status | Customers | Avg Usage Events | Avg Sessions |
|---|---|---|---|
| Active | 418 | 35.8 | 107.5 |
| Churned | 388 | 8.8 | 26.7 |

**Finding:** Active customers generate ~4x more usage events and sessions
than churned customers. This is the strongest signal in the entire dataset.

**Why it matters:** Usage is a leading indicator, not just a symptom —
disengagement likely precedes cancellation, meaning it's detectable and
actionable before a customer actually leaves.

**Recommendation:** Build an early-warning system — flag customers whose
usage drops sharply (e.g. 50%+ over 2 weeks) for proactive customer success
outreach before they churn.

---

### 4. What's the MRR trend, and is growth healthy?

```sql
SELECT DATE_TRUNC('month', payment_date) AS month, SUM(amount) AS mrr,
       COUNT(DISTINCT subscription_id) AS paying_subscriptions
FROM payments
WHERE payment_status = 'success'
GROUP BY DATE_TRUNC('month', payment_date)
ORDER BY month;
```

**Finding:** MRR grew from ₹1,402 (Jan 2024) to ₹31,297 (Aug 2026) — roughly
22x growth over 2.5 years, mostly steady. However, the most recent two months
show early flattening: Feb 2026 dipped (₹28,273 → ₹24,977) and Aug 2026 dipped
again (₹31,866 → ₹31,297) alongside a drop in subscriber count (421 → 399).

**Why it matters:** Early-stage SaaS companies live and die by whether growth
is accelerating or plateauing. A recent dip is the most business-critical
signal in the trend.

**Recommendation:** Cross-reference with Question 3 — since usage decline
precedes churn, check whether active users in Jul-Aug show early disengagement,
which would suggest this MRR dip is the start of a churn wave rather than noise.

---

### 5. Are failed payments a churn driver?

**First attempt (misleading — kept here deliberately to show the correction):**

Raw failed-payment counts showed active customers with *more* failures
(0.78 avg) than churned customers (0.21 avg) — which looked backwards. This
turned out to be an exposure bias: active customers have been paying longer,
so they've had more total opportunities for any payment to fail.

**Corrected query (failure rate, not raw count):**

```sql
WITH payment_health AS (
    SELECT subscription_id, COUNT(*) AS total_payments,
           ROUND(100.0 * SUM(CASE WHEN payment_status = 'failed' THEN 1 ELSE 0 END) / COUNT(*), 2) AS failure_rate_pct
    FROM payments GROUP BY subscription_id
)
SELECT s.status, COUNT(*) AS num_customers, ROUND(AVG(ph.failure_rate_pct), 2) AS avg_failure_rate_pct
FROM subscriptions s
LEFT JOIN payment_health ph ON s.subscription_id = ph.subscription_id
GROUP BY s.status;
```

| Status | Avg Failure Rate |
|---|---|
| Active | 5.17% |
| Churned | 5.76% |

**Finding:** A real but modest effect — churned customers have a slightly
higher failure rate, but the gap is small compared to the usage or channel
findings.

**Why it matters:** Not every hypothesis produces a dramatic result — honestly
reporting a weak signal (rather than overselling it) reflects careful analysis.

**Recommendation:** Payment failures alone aren't a strong churn driver in
this dataset. A follow-up worth exploring: whether *repeated* failures (2+)
matter more than any single failure — this dataset isn't large enough to
confirm that confidently.

---

## Tech Stack

- **PostgreSQL** — schema design, all analysis queries
- **CTEs and window-function-ready design** — built for further extension
  (e.g. cohort retention curves, RFM-style segmentation)

## Files in this repo

- `01_create_schema.sql` — full table definitions, constraints, indexes
- `02_loading_guide.md` — data loading and cleaning steps
- `SCHEMA.md` — entity-relationship documentation
- `data/` — the 5 source CSVs
- `analysis_queries.sql` — all 5 business questions as runnable SQL

## What I'd do next

- Build a churn-risk scoring model on top of the usage-intensity finding
  (natural bridge to a Data Science project)
- Add a Power BI dashboard visualizing these 5 findings for a
  non-technical stakeholder audience
