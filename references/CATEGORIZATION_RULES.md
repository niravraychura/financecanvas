# FinanceCanvas Categorization Rules

FinanceCanvas uses a standard hierarchy plus user-defined categories.

## Suggested top-level categories

Income:
- Salary/Professional Income
- Business Income
- Freelance Income
- Interest/Dividend
- Refund/Reversal
- Other Income

Spending:
- Housing
- Utilities
- Groceries
- Dining
- Transport
- Fuel
- Travel
- Shopping
- Health
- Insurance
- Education
- Entertainment
- Software/Subscriptions
- Taxes/Fees
- Family/Transfers
- Charity
- Business Expense
- Other

Financial:
- Loan Payment
- Credit Card Payment
- Investment
- Savings Transfer
- Internal Transfer

## Rules

- Preserve the raw source description separately from normalized merchant/category values.
- Do not silently recategorize a user-confirmed category.
- User-confirmed merchant aliases override generic categorization.
- If confidence is insufficient, ask rather than guess.
- A transaction may be split across categories/profiles/purposes.
- Personal, business and shared purpose are separate from merchant/category.
- Internal transfers should normally be excluded from spending/income analytics.
- Refunds/reversals should be linked to the original purchase when evidence supports it.
- Fees, interest, taxes and forex markups should remain distinguishable from the underlying purchase.

Custom categories are allowed. If a user rejects a spelling/normalization recommendation, preserve the chosen wording.
