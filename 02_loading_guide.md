# Loading & Cleaning Guide — Company Insights 360°

## Step 1 — Install PostgreSQL (if not already)
Use pgAdmin or psql CLI, whichever you're comfortable with.

## Step 2 — Create the database
```sql
CREATE DATABASE company_insights_360;
```
Connect to it, then run `01_create_schema.sql` to create all tables.

## Step 3 — Import CSVs

### plans.csv → plans (clean, load directly)
```sql
\copy plans FROM 'data/plans.csv' DELIMITER ',' CSV HEADER;
```

### customers.csv → customers_raw (load RAW first — this file has duplicates + messy data on purpose)
```sql
\copy customers_raw FROM 'data/customers.csv' DELIMITER ',' CSV HEADER;
```

### subscriptions.csv, usage_events.csv, payments.csv → load directly
```sql
\copy subscriptions FROM 'data/subscriptions.csv' DELIMITER ',' CSV HEADER;
\copy usage_events FROM 'data/usage_events.csv' DELIMITER ',' CSV HEADER;
\copy payments FROM 'data/payments.csv' DELIMITER ',' CSV HEADER;
```
(Note: load `subscriptions` only AFTER `customers` is populated — see Step 4 — since it has a foreign key to customers.)

## Step 4 — Clean customers_raw → customers (THIS is your data cleaning showcase)

Write your own cleaning query here. Things to handle:
1. **Duplicate rows** — some customer_ids appear more than once
2. **Inconsistent country casing** — e.g. "INDIA" vs "India"
3. **Null company_size** — decide: drop, or label as 'Unknown'

Starter skeleton (fill in the logic yourself — this is where you show SQL thinking):
```sql
INSERT INTO customers (customer_id, signup_date, country, company_size, acquisition_channel)
SELECT DISTINCT ON (customer_id)
    customer_id,
    signup_date,
    INITCAP(country) AS country,              -- standardizes casing
    COALESCE(company_size, 'Unknown') AS company_size,
    acquisition_channel
FROM customers_raw
ORDER BY customer_id;  -- add tiebreak logic if needed for true duplicates
```
Before running this, **inspect the duplicates yourself**:
```sql
SELECT customer_id, COUNT(*)
FROM customers_raw
GROUP BY customer_id
HAVING COUNT(*) > 1;
```
Write down in your README what you found and how you decided to handle it — this narrative
is worth more in an interview than the query itself.

## Step 5 — Verify row counts
```sql
SELECT 'customers' AS tbl, COUNT(*) FROM customers
UNION ALL SELECT 'plans', COUNT(*) FROM plans
UNION ALL SELECT 'subscriptions', COUNT(*) FROM subscriptions
UNION ALL SELECT 'usage_events', COUNT(*) FROM usage_events
UNION ALL SELECT 'payments', COUNT(*) FROM payments;
```

## Step 6 — You're ready to analyze
Move to drafting your own business questions (not from any reference list) before writing
analysis queries. This is the next thing we'll work on together.
