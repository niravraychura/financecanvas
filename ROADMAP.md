# FinanceCanvas Roadmap / Deferred Production Work

This file lists items intentionally **not** treated as complete in v0.1 because they depend on the final commercial model, launch jurisdictions, user count, or regulated integrations.

## Already complete in v0.1

- portable FinanceCanvas Skill
- multi-profile/household model
- structured-data-only persistence
- sensitive-upload warnings and backend secret/identifier blocking
- exact and near-duplicate controls
- two-step edits/deletes
- two-step full workspace erasure
- JSON and CSV exports
- Watch rules/findings
- historical-balance queries with running-balance/anchor evidence
- automatic recurring-pattern discovery
- subscription-change/reappearance and spending-anomaly detection
- EMI, annual-fee, reconciliation and allocation-drift Watch rules
- persistent financial preferences and recommendation history
- evidence-aware answers, financial timeline and ownership graph
- source-document SHA-256 duplicate checks
- data-freshness checks
- scoped external API keys
- owner/developer connector-first maintenance
- restricted runtime API path
- compliance/privacy/security documentation
- mandatory security review and CI security gate
- incident-response, threat-model, retention and release checklists

## Deferred until a public/commercial launch is planned

### Identity and tenant authentication
For a public multi-user service, implement production user authentication and workspace membership authorization end-to-end. Do not rely only on an installation key.

### RLS policy model for direct user clients
Current v0.1 deliberately revokes normal direct table access. If direct Supabase Auth clients are ever introduced, design/test workspace-aware RLS policies before enabling them.

### Bank-data connectivity
Only add automated bank aggregation through appropriately authorized providers/Account Aggregator arrangements after legal/security review. No credential scraping.

### Payment execution
No payment initiation/holding of funds in v0.1. Any future payment feature requires a separate regulated-provider and security review.

### Investment-advice functionality
Any personalized securities recommendation feature requires a fresh SEBI/legal review before enabling or marketing it.

### Production notification delivery
Watch rules need an actual scheduler/delivery channel for unattended alerts. Integrate only with explicit user authorization and document the provider/subprocessor.

### Backup/disaster recovery
Define RPO/RTO, backup retention, restore testing and cross-account/project recovery appropriate to the production plan.

### Commercial privacy operations
Finalize:
- operator/legal identity
- production privacy notice/terms
- grievance/privacy contact
- processor/subprocessor contracts
- cross-border review
- data-subject request SLA/workflow
- incident notification workflow

### Security testing
Before public launch:
- penetration test
- abuse-case testing
- authorization/cross-workspace testing
- dependency/SAST review
- restore/erasure testing
- incident-response exercise

## Rule

Do not mark `production_ready=true` until the applicable COMPLIANCE.md and RELEASE_CHECKLIST.md items are complete.
