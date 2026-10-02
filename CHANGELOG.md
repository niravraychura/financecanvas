# Changelog

## 0.1.3

- Extended BYO-Supabase connector imports beyond bank/credit-card transactions
- Added controlled imports for insurance policies, loans, portfolio/holding records, income sources, assets, liabilities, subscriptions, goals and recurring items
- Added child/history import support for insurance premiums, loan payments and investment events
- Added salary/pay-slip import with dated income-payment history
- Added minimized tax-summary/return import without PAN/Aadhaar/passport/tax identifiers
- Added field-level changed-existing preview and explicit Keep / Update / Add-separate decisions with reasons
- Added atomic structured-document import evidence links through `import_entities`
- Added source-hash format enforcement and last-four identifier constraints
- Added cross-workspace child-record guards
- Added acceptance coverage for all supported non-transaction financial document classes

## 0.1.2

- Added connector-native statement account resolution, duplicate preview and atomic import for Codex/Claude/Cursor environments with authorized Supabase connectors
- Ordinary statement data (name, masked identifiers, transactions, balances, limits, due dates, totals and rewards) is now explicitly classified as private-but-importable rather than import-blocking
- Critical secrets and full high-risk identifiers remain blocked/minimized
- Connector imports now create structured import/card-statement metadata while never storing the source PDF
- Added commit-time duplicate recheck and source-document hash protection for connector mode
- Added Base64 guidance for safely passing untrusted extracted JSON through SQL-only connectors
- Added database-side masked/full-card privacy enforcement for connector imports

## 0.1.1

- Fixed Codex/connector initialization when the FinanceCanvas HTTP operation is not exposed as a tool
- Added bring-your-own-Supabase architecture: every user selects their own connected Supabase project
- Added private connector-native `connector_status` and idempotent `initialize_workspace` RPCs
- Removed any architectural dependency on the author's Supabase project
- Made the Edge Function optional for connector-only personal/private use
- Added CI guards against hardcoded real Supabase project URLs
- Added connector-mode documentation and project-selection rules

## 0.1.0

- Added one-command Agent Skills installer for Claude Code, Cursor, Codex and compatible agents
- Added upload bundle builder for ChatGPT Skills
- Added Apache-2.0 license, NOTICE, CITATION metadata and third-party notice
- Added cross-agent install CI and skills.sh discoverability badge - 2026-10-01

Initial FinanceCanvas release:
- Security review gate required after every change
- Automated repository secret/sensitive-file/runtime-guardrail scanner in CI
- Threat model, retention policy, incident-response and release checklists
- Workspace-scoped and scope-limited external API keys
- JSON/CSV structured export and two-step workspace erasure
- Exact runtime dependency pinning
- portable SKILL.md
- multi-profile/workspace data model
- Joint ownership/borrower/household relationship model
- Account balance history and credit-card statement metadata
- Budgets, recurring items and financial snapshots
- Expanded Watch checks for due dates, utilization, renewals, goals, budgets, recurring items, concentration, refunds and cash flow
- Added historical balance reconstruction with statement running balances and source sequence
- Added recurring-pattern discovery and source-document SHA-256 duplicate checks
- Added subscription change/reappearance, spending anomaly, EMI, annual fee, reconciliation and allocation-drift alerts
- Added persistent financial preferences and recommendation history
- Added evidence bundles, financial timeline and ownership graph
- Cross-workspace reference validation on controlled writes
- structured-data-only persistence
- exact and near-duplicate protection
- two-step edit and permanent-delete confirmation
- audit history
- FinanceCanvas Watch rules and findings
- data freshness tracking
- Supabase migrations and controlled Edge Function API
- public-repository secret protection and CI checks
