# FinanceCanvas Data Model

FinanceCanvas separates authentication, workspace/household identity, accounts, ownership, financial records, imports, alerts, privacy/security records and audit history.

## Identity and household

- workspaces
- workspace_members
- profiles
- households
- household_members
- profile_relationships

Do not assume a login identity is the same thing as a financial profile.

## Accounts and ownership

- institutions
- accounts
- account_owners
- account_balances
- credit_card_statements
- transaction running balances/order via transactions.balance_after/source_sequence

Account/card identifiers are masked/final-four only.

## Transactions and imports

- imports
- extracted_fields
- confirmation_queue
- transactions
- transaction_splits
- merchant_aliases
- correction_memory
- duplicate_reviews

Source files are temporary inputs and are not intentionally persisted by FinanceCanvas.

## Debt and insurance

- loans
- loan_borrowers
- loan_payments
- liabilities
- liability_owners
- insurance_policies
- insurance_premiums

## Assets and investments

- assets
- asset_owners
- investments
- investment_transactions
- financial_snapshots

Ownership percentages can represent joint assets/liabilities/loans.

## Planning and recurring finance

- goals
- budgets
- income_sources
- subscriptions
- recurring_items

## Monitoring

- watch_rules
- watch_findings
- data_freshness
- investment_allocation_targets

## Change safety and privacy

- pending_operations
- audit_log
- processing_consents
- privacy_requests
- sensitive_data_events
- security_events
- breach_incidents
- financecanvas_compliance_settings
- financial_preferences
- recommendations

## Workspace invariant

Records with a workspace_id must belong to the current workspace. Relationship/reference writes through the controlled API validate that referenced records belong to the same workspace.

Normal runtime clients must not receive arbitrary project-admin database access.
