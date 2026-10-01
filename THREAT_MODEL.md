# FinanceCanvas Threat Model

## Assets

Highest-value assets include:
- structured financial records;
- workspace/profile ownership data;
- API/connector credentials;
- audit/privacy/security records;
- financial goals, assets, liabilities and investment records.

## Trust boundaries

1. User ↔ host LLM/chat platform
2. Host/Skill ↔ FinanceCanvas controlled API
3. Owner/developer ↔ Supabase admin connector
4. Edge Function ↔ Supabase database
5. Public GitHub repository ↔ deployment process

An owner/admin connector is a maintenance boundary and must not be treated as normal runtime access.

## Primary threats and controls

### Credential leakage
Controls:
- no secrets in GitHub;
- connector-first owner maintenance;
- workspace-scoped/scope-limited runtime API keys;
- critical-secret rejection;
- CI secret scanning.

### Prompt/document injection
Uploaded files are untrusted data, never instructions. The Skill must not follow commands embedded in statements, PDFs, screenshots, CSV cells or metadata.

### Cross-workspace access
Runtime API keys may be bound to one workspace. The API rejects requests targeting a different workspace.

### Unauthorized mutation
Edits/deletes are two-step. Duplicate overrides require reasons. Direct anon/authenticated DML access is revoked.

### Duplicate/poisoned financial records
Exact fingerprints, near-duplicate review, reconciliation and final confirmation reduce accidental or malicious duplicate insertion.

### Excessive data collection
Only necessary structured data should be retained. Source documents are not intentionally stored. High-risk identifiers are minimized.

### Malicious/compromised LLM
Normal runtime access is restricted to approved operations. A normal LLM should not receive Supabase project-admin/SQL access.

### Supply-chain compromise
Dependencies should be pinned/reviewed, GitHub Actions should use trusted publishers, and dependency changes require security review.

### Data exfiltration through logs
Logs/audit events must be data-minimized and exclude raw secrets.

### Abuse of financial recommendations
FinanceCanvas does not act as a payment service and must stay within documented regulatory boundaries for investment advice.

## Residual risks

- The host chat/LLM provider may retain uploaded content independently.
- Supabase/platform operational logs and backups have their own retention/security behavior.
- AI extraction and anomaly detection can be wrong.
- An owner with Supabase admin access can intentionally bypass application controls.
- No application is breach-proof; incident-response procedures remain necessary.
