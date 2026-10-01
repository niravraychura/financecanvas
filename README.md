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

The Skill never receives Supabase database credentials and never writes raw SQL. Database integrity rules live in the data/API layer so editing `SKILL.md` does not change how data is stored, edited, deleted, or deduplicated.

## Privacy model

Uploaded PDF/JPG/PNG/CSV/XLS/XLSX files are temporary inputs to the AI/chat only.

FinanceCanvas follows:

```text
Upload -> Extract -> Validate -> Review uncertainties
       -> Final confirmation -> Store structured data
```

FinanceCanvas does **not** intentionally persist the original uploaded source file.

Never store:
- CVV
- PIN
- OTP
- banking passwords
- internet-banking credentials
- full card numbers unless a future secure design explicitly requires them

Prefer masked account/card identifiers and last four digits.

## Multi-person and household support

A workspace can represent one person, a couple, or a household. It may contain multiple financial profiles and shared records.

On first initialization FinanceCanvas asks whether the user wants to configure a named workspace. If declined, it creates an internal default personal workspace that can be renamed later.

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

## Supabase setup

The reference deployment uses Supabase Free:

- PostgreSQL for structured financial data
- an Edge Function as the controlled API
- RLS enabled as defense in depth
- direct `anon`/`authenticated` table access revoked in v0.1

The Edge Function uses Supabase server-side credentials internally. FinanceCanvas clients use a separate installation API key beginning with `fc_`; only its SHA-256 hash is stored in the database.

### Environment variables for a client

Copy `.env.example` and set:

```
FINANCECANVAS_API_URL=https://YOUR_PROJECT_REF.supabase.co/functions/v1/financecanvas-api
FINANCECANVAS_API_KEY=fc_...
```

Never commit the real key.

## Repository safety

This public repository intentionally contains no personal financial records and no production credentials.

`.gitignore` excludes common secret files, statement/receipt/export folders, local databases, and Supabase local state.

Before every public contribution, review the diff for secrets and personal data.

## Skill

`SKILL.md` contains the portable FinanceCanvas behavior and safety workflow.

Changing the Skill must not weaken database/API enforcement for duplicates, edit confirmation, deletion confirmation, or audit history.

## Security

See [SECURITY.md](SECURITY.md).

## Disclaimer

FinanceCanvas organizes and analyzes financial information. AI interpretations can be wrong. High-impact financial, tax, insurance, investment, fraud, and legal decisions should be independently verified when appropriate.

## License

No open-source license has been selected yet. Public repository visibility does not itself grant permission to copy, modify, or redistribute the project.
