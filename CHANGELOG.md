# Changelog

## 0.1.0 - 2026-10-01

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
