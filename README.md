# FinanceCanvas

**FinanceCanvas is a portable AI Personal CFO skill backed by a structured, user-controlled financial database.**

FinanceCanvas is designed for individuals, couples, and households that want an AI assistant to understand their financial history without permanently storing source bank statements, bills, receipts, screenshots, or other uploaded documents.

> Status: v0.1 reference implementation.

## What it does

FinanceCanvas can organize and reason over structured data for:

- bank accounts and credit cards
- transactions and split transactions
- income and recurring expenses
- loans and repayments
- insurance
- assets and liabilities
- investments
- subscriptions
- financial goals
- multiple people and shared household finances
- financial alerts and anomaly checks

## Architecture

```text
ChatGPT / compatible AI
        |
        v
FinanceCanvas Skill
        |
        v
Controlled FinanceCanvas API
(Supabase Edge Function)
        |
        v
Supabase Postgres
structured financial data only
```

When an authorized Supabase connector is already available, FinanceCanvas prefers that connector and does not require a local `.env` or user-supplied Supabase secret. The optional Edge Function remains a portable adapter for external clients/LLMs. Database integrity rules live outside `SKILL.md` so editing the Skill cannot silently weaken duplicate, edit, delete, or audit controls.

## Privacy model

Uploaded PDF/JPG/PNG/CSV/XLS/XLSX files are temporary inputs to the AI/chat only.

FinanceCanvas follows:

```text
Upload -> Extract -> Validate -> Review uncertainties
       -> Final confirmation -> Store structured data
```

FinanceCanvas does **not** intentionally persist the original uploaded source file.

Never persist or echo critical secrets such as CVV/CVC, PIN/UPI PIN, OTP, passwords/passcodes, recovery phrases, private keys, API/access/refresh tokens, or internet-banking credentials.

FinanceCanvas also minimizes high-risk identifiers. v0.1 does not intentionally persist Aadhaar/VID, PAN, passport values, full card numbers, or full bank-account numbers. Cards/accounts are represented using masked values or last four digits only.


## Connector-first access

If the owner/developer already has an explicitly authorized Supabase connection, FinanceCanvas may use it for maintenance without duplicating credentials. Normal end-user/LLM runtime access should remain behind the restricted FinanceCanvas API (or an equivalently least-privilege connector), because a project-admin connector can bypass application safeguards.

In that mode:
- do not ask the user to paste Supabase credentials;
- do not create a local secret file just to duplicate an existing authorized connection;
- do not store connector credentials in FinanceCanvas;
- preserve the same confirmation, duplicate, deletion and audit controls.

The Edge Function/API-key mode is optional and intended for external clients that cannot use the authorized connector.

## Multi-person and household support

A workspace can represent one person, a couple, or a household. It may contain multiple financial profiles and shared records.

On first initialization FinanceCanvas asks whether the user wants to configure a named workspace. If declined, it creates an internal default personal workspace that can be renamed later.


## Sensitive upload behavior

When an uploaded statement, screenshot, image, CSV or pasted text contains sensitive information, FinanceCanvas must warn the user in chat before persistence.

Critical secrets are never saved and should not be quoted back. High-risk identifiers are masked/minimized. If exposure may create risk, FinanceCanvas should provide immediate next steps, such as changing a password, rotating a token/key, or contacting the bank/card issuer.

FinanceCanvas does not intentionally retain the source document in its own database. **The chat/LLM host may separately retain an uploaded file under that provider's privacy/retention policy.** FinanceCanvas must not claim it can delete that host copy unless the host provides an explicit deletion capability.

## Import and confirmation

Supported temporary input formats:

- PDF
- JPG/JPEG
- PNG/screenshots
- CSV
- XLS/XLSX
- pasted text

The import workflow:

1. detect document/data type
2. detect likely person/profile and account
3. extract raw financial facts
4. normalize merchants/categories separately
5. calculate confidence
6. reconcile totals when possible
7. detect exact and near duplicates
8. ask only about uncertain/conflicting records
9. ask once for final import confirmation
10. commit structured data

If a spelling/grammar correction changes user-entered or source text materially, FinanceCanvas shows the original and recommendation and asks whether to accept, keep the original, or edit.

## Duplicate protection

### Exact duplicate
An exact transaction fingerprint cannot be inserted silently.

The user can:
- Skip
- Review existing
- Add as a separate valid transaction

Adding separately requires an explicit reason, which is stored in the audit/duplicate review history.

### Near duplicate / changed copy
FinanceCanvas shows a field-by-field difference and asks whether to:
- Keep existing
- Update existing
- Add separately
- Cancel

Update/add-separate requires a reason. Existing financial data is never silently overwritten.

## Edit and delete protection

Edits and deletions use two steps:

1. request/propose the operation
2. explicitly confirm it

Normal deletion is soft deletion. Permanent deletion is supported only after explicit confirmation.

Audit history preserves before/after values and reasons.

## FinanceCanvas Watch

FinanceCanvas Watch can evaluate stored data for:

- unusual/high-value transactions
- potential fraud signals
- unexpected fees, interest, forex markups and surcharges
- possible duplicate charges
- subscription changes
- card utilization/due-date/annual-fee rules
- missing refunds
- loan/EMI changes
- spending anomalies
- goal progress
- investment concentration/allocation drift
- insurance renewals
- reconciliation failures
- stale/missing financial data

An anomaly is **not proof of fraud**. FinanceCanvas should explain why a transaction was flagged and provide practical next steps.

FinanceCanvas cannot detect a transaction that has never been imported or connected.


## Compliance posture

FinanceCanvas v0.1 is currently marked **prototype / not production-ready for a public financial service**.

For a purely personal/domestic installation, India's DPDP Act contains a personal/domestic-purpose exclusion. That should not be relied on once the system is offered commercially, to clients, employees, or the public.

Before public/commercial deployment, complete the checklist in [COMPLIANCE.md](COMPLIANCE.md) and publish an appropriate [privacy notice](PRIVACY.md).

FinanceCanvas is intentionally **not** designed to:
- act as a bank/payment system or hold customer funds;
- collect bank login credentials or scrape authenticated bank portals;
- represent itself as an RBI Account Aggregator;
- provide regulated securities investment-adviser/research-analyst services without the required SEBI registration/compliance review.

## Supabase setup

The reference deployment uses Supabase Free:

- PostgreSQL for structured financial data
- an Edge Function as the controlled API
- RLS enabled as defense in depth
- direct `anon`/`authenticated` table access revoked in v0.1

The Edge Function uses Supabase server-side credentials internally. Optional external-client FinanceCanvas API keys are stored only as SHA-256 hashes, may be scoped to a single workspace, and use explicit `read`, `write`, `watch`, `export`, or `admin` scopes.

### External-client configuration

No local `.env` is needed when an authorized Supabase connector is available.

For an external client that uses the optional FinanceCanvas Edge Function, use local environment variables outside source control:

```
FINANCECANVAS_API_URL=https://YOUR_PROJECT_REF.supabase.co/functions/v1/financecanvas-api
FINANCECANVAS_API_KEY=fc_...
```

Never commit a real key.

## Data portability and erasure

FinanceCanvas supports structured export in **JSON and CSV**.

Full workspace erasure is a separate two-step flow: request erasure, review the impact, then explicitly confirm. Export first when appropriate.

## Repository safety

This public repository intentionally contains no personal financial records and no production credentials.

`.gitignore` excludes common secret files, statement/receipt/export folders, local databases, and Supabase local state.

Before every public contribution, review the diff for secrets and personal data.

## Skill

`SKILL.md` contains the portable FinanceCanvas behavior and safety workflow.

Changing the Skill must not weaken database/API enforcement for duplicates, edit confirmation, deletion confirmation, or audit history.

## Security change policy

**Every FinanceCanvas change requires a security-impact review.**

GitHub CI runs `scripts/security_check.py` on every push and pull request. For backend/schema/API changes, also run the Supabase verification items in [SECURITY_CHECKLIST.md](SECURITY_CHECKLIST.md).

Core security/governance documents:

- [SECURITY.md](SECURITY.md)
- [SECURITY_CHECKLIST.md](SECURITY_CHECKLIST.md)
- [THREAT_MODEL.md](THREAT_MODEL.md)
- [DATA_RETENTION.md](DATA_RETENTION.md)
- [INCIDENT_RESPONSE.md](INCIDENT_RESPONSE.md)
- [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md)
- [COMPLIANCE.md](COMPLIANCE.md)
- [PRIVACY.md](PRIVACY.md)

A change marked **BLOCKED** by the checklist must not be treated as released/complete.

## Security

See [SECURITY.md](SECURITY.md).

## Disclaimer

FinanceCanvas organizes and analyzes financial information. AI interpretations can be wrong. High-impact financial, tax, insurance, investment, fraud, and legal decisions should be independently verified when appropriate.

## License

No open-source license has been selected yet. Public repository visibility does not itself grant permission to copy, modify, or redistribute the project.
