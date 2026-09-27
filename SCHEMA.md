# Schema — Company Insights 360° (SaaS Subscription Dataset)

Synthetic but realistic multi-table SaaS dataset. Designed to require proper
relational thinking (not a single flat CSV) and to contain genuine,
discoverable business patterns.

## Tables & Relationships

```
customers (customer_id PK)
    |
    | 1---1
    v
subscriptions (subscription_id PK, customer_id FK, plan_id FK)
    |                           |
    | 1---N                    N---1
    v                           v
payments (payment_id PK,    plans (plan_id PK)
          subscription_id FK)

customers (customer_id PK)
    |
    | 1---N
    v
usage_events (event_id PK, customer_id FK)
```

## Table Details

### customers
| column | type | notes |
|---|---|---|
| customer_id | INT PK | |
| signup_date | DATE | seasonal spikes in Jan/Jun/Sep |
| country | TEXT | **~4% inconsistent casing** e.g. "INDIA" — clean this |
| company_size | TEXT | 1-10, 11-50, 51-200, 201-500, 500+ — **~2% nulls** |
| acquisition_channel | TEXT | Organic Search, Paid Ads, Referral, Social Media, Cold Outreach, Partner |

**Note:** contains 6 intentional duplicate rows — practice de-duplication.

### plans
| column | type | notes |
|---|---|---|
| plan_id | INT PK | |
| plan_name | TEXT | Basic / Pro / Enterprise |
| monthly_price | INT | 15 / 49 / 199 |

### subscriptions
| column | type | notes |
|---|---|---|
| subscription_id | INT PK | |
| customer_id | INT FK | |
| plan_id | INT FK | |
| start_date | DATE | = customer signup_date |
| end_date | DATE | NULL if still active |
| status | TEXT | active / churned |

### usage_events
| column | type | notes |
|---|---|---|
| event_id | INT PK | |
| customer_id | INT FK | |
| event_date | DATE | |
| feature_used | TEXT | Dashboard, Reports, API Access, Integrations, Team Collaboration, Automation, Export Data, Custom Fields |
| session_count | INT | sessions in that event window |

### payments
| column | type | notes |
|---|---|---|
| payment_id | INT PK | |
| subscription_id | INT FK | |
| payment_date | DATE | monthly |
| amount | INT | 0 if payment failed |
| payment_status | TEXT | success / failed (~5% failure rate) |

## Known Patterns (don't peek before you analyze — verify these yourself!)

- Enterprise plan customers churn less than Basic plan customers
- Referral / Organic Search acquisition channels retain better than Cold Outreach / Social Media
- Higher usage_events activity correlates with lower churn
- Signups spike seasonally (Jan, Jun, Sep)
- Overall churn rate is roughly 48%

## Suggested First Steps

1. Load all 5 CSVs into PostgreSQL (or SQLite) as separate tables
2. Write data cleaning queries: dedupe customers, standardize country casing, handle null company_size
3. Draft your OWN business questions before looking at the "Known Patterns" above —
   then verify what you find against them
