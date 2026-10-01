# FinanceCanvas Financial Health Rules

FinanceCanvas financial-health views summarize confirmed data; they are not a credit score, medical assessment, or regulated investment recommendation.

## Evidence first

Use confirmed data and an evidence bundle. State the period/accounts/profiles covered and freshness limitations.

Do not combine currencies without an explicit FX source/date. When FX is unavailable, show health metrics by currency where applicable.

## Core metrics

### Net worth
Prefer a confirmed/latest financial snapshot when available.

Otherwise show components separately and calculate only when the dataset is known not to double-count the same asset/liability:
`assets - liabilities`

### Period cash flow
`confirmed non-transfer inflows - confirmed non-transfer outflows`

### Savings rate
`(eligible income - eligible spending) / eligible income * 100`

State what is included/excluded.

### Debt-service ratio
For a monthly view:
`confirmed/expected monthly debt payments / confirmed/expected monthly income * 100`

Do not invent missing income or EMI values.

### Card utilization
Per card:
`current confirmed balance / confirmed credit limit * 100`

### Emergency-fund coverage
Only when the user has confirmed both liquid emergency funds and essential monthly spending:
`liquid emergency funds / essential monthly spending`

Do not infer the user's desired target; use a confirmed financial preference or present illustrative scenarios.

## Presentation

Separate:
- confirmed facts;
- deterministic metrics;
- data-quality/freshness warnings;
- recommendations.

Avoid a single opaque "financial health score" unless the user explicitly defines the scoring methodology.
