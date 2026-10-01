# FinanceCanvas Calculation Rules

Prefer deterministic arithmetic over AI estimation.

## Core formulas

### Net worth
`total assets - total liabilities`

Do not combine currencies unless an explicit FX source/date is provided. Otherwise present totals by currency.

### Cash flow
`cash inflows - cash outflows` for the requested period.

Transfers between the user's own accounts should not be counted as income/expense unless the user intentionally classifies them that way.

### Savings rate
Default:
`(income - eligible spending) / income * 100`

State the exact numerator/denominator and whether loan principal, investments, taxes, transfers or business flows were included.

### Credit-card utilization
`statement/current balance / credit limit * 100`

Use the appropriate balance date and do not infer a credit limit that is not confirmed.

### Debt-to-income
State whether the calculation is monthly or annual and which debt payments/income sources are included.

### EMI
For reducing-balance loans use the standard amortization formula when principal, periodic rate and number of periods are confirmed. If rate type/compounding is unknown, state the assumption before calculating.

### Reconciliation
Use the source document's sign convention. Typical bank relationship:
`opening balance + credits - debits = expected closing balance`

Do not mark a statement reconciled when a material unexplained difference remains.

## Rounding

- Preserve stored precision.
- Display money using the currency's normal precision unless the source requires more.
- Round only at the presentation/final-calculation boundary where practical.
- Never hide a reconciliation difference through aggressive rounding.

## Estimates

Label estimates clearly and list assumptions. Estimated/simulated values must not become confirmed financial records unless the user later confirms the real event.
