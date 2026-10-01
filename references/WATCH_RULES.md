# FinanceCanvas Watch Rules

Watch findings are signals, not proof. They are evaluated only when a check actually runs.

Supported v0.1 rule types include:

## fee_watch
Looks for wording commonly associated with fees, interest, markups, surcharges and similar charges.

## fraud_watch / high_value
Flags confirmed debits at or above a configured amount threshold. This is not a fraud determination.

Example configuration:
```json
{"threshold_amount": 25000}
```

## duplicate_charge
Looks for very similar debits on the same account close together.

## card_due
Uses stored credit-card statement due dates and payment status.

Optional:
```json
{"window_days": 7}
```

## card_utilization
Uses current balance and confirmed credit limit.

Example:
```json
{"threshold_percent": 30}
```

## insurance_renewal
Warns when a stored renewal date is approaching.

## goal_watch
Warns when an active goal is below target near/past the target date.

## budget_watch / spending_watch
Compares confirmed debit transactions with active stored budgets.

## recurring_watch / subscription_watch
Surfaces upcoming expected recurring items/subscriptions.

## investment_concentration
Calculates concentration only within the same currency unless an explicit FX source is supplied.

Example:
```json
{"threshold_percent": 40}
```

This is portfolio analytics, not a buy/sell recommendation.

## refund_watch
Checks for an expected credit by a configured date.

Example:
```json
{"amount": 1999, "currency": "INR", "merchant": "Example Merchant", "expected_by": "2026-10-31"}
```

## cash_flow_watch
Calculates confirmed inflows minus outflows over the lookback window, excluding transfers.

Example:
```json
{"minimum_net_cash_flow": 0, "currency": "INR"}
```

## Data freshness
FinanceCanvas also creates stale-data findings when an account is older than its expected update interval.

## Scheduling

Saving a Watch rule does not create background execution.

If the host has an authorized scheduler/automation, schedule the Watch check at the user-requested cadence. Otherwise state clearly that the rule runs only when FinanceCanvas is invoked.


## subscription_change
Detects material changes between expected recurring/subscription amounts and recent matching debits. It also flags a matching debit for a subscription stored as cancelled.

Example:
```json
{"threshold_percent": 10}
```

## spending_anomaly
Compares recent confirmed category spending with a prior daily baseline and flags material increases.

Example:
```json
{"current_days": 30, "baseline_days": 90, "increase_percent": 50, "minimum_amount": 1000}
```

This is an anomaly signal, not proof of fraud or overspending.

## loan_emi_change
Compares the latest recorded loan payment with the stored EMI, or with the prior payment when no EMI is stored.

## annual_fee_watch
Uses a card's stored annual fee, next fee date and optional waiver-spend threshold. Tracked card spend is informational; issuer eligibility/exclusions must still be verified.

## reconciliation_watch
Flags imports whose stored statement reconciliation status is failed.

## allocation_drift
Compares tracked investment values with user-confirmed allocation targets and tolerance.

This is allocation analytics, not a securities buy/sell recommendation.
