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


## Historical account balance

For a question such as "What was the balance on 15 March 2026?":

1. Prefer a confirmed statement running balance (`balance_after`) on the target date.
2. When multiple same-day rows exist, use the confirmed `source_sequence` to identify the final statement row.
3. Otherwise reconstruct from the closest confirmed account-balance anchor plus/minus all confirmed transactions between the anchor and target date.
4. For ordinary bank/cash/wallet accounts: credits increase balance and debits decrease it.
5. For credit-card balances representing amount owed: debits/purchases increase the owed balance and credits/payments decrease it.
6. Prefer a reconciled statement covering the target date as evidence.
7. If transaction coverage/order cannot be proven, return "insufficient/ambiguous data" rather than guessing.

Label the result:
- exact from statement running balance;
- reconstructed from a confirmed/reconciled anchor; or
- insufficient/ambiguous.
