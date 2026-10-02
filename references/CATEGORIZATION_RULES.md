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

## Permanent user clarifications

Apply approved historical corrections using the preview/commit clarification workflow. Canonical merchant/category/subcategory/purpose live on transactions; transaction_clarifications preserve explanation; merchant_aliases and correction_memory retain reusable knowledge.

Use transaction/month/date-range scope for context-specific meaning. For people who lend/borrow for varying purposes, normalize identity and remember relationship without globally assigning an IPO purpose. Do not turn a generic bank descriptor into a permanent merchant mapping based on one purchase.

Preserve user-confirmed categories during later enrichment. Exclude internal/P2P lending transfers and card repayments from new spending; show investments and cash withdrawals separately when their final spending purpose is unknown.
