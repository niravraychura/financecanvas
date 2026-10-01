# Security Policy

FinanceCanvas is designed for sensitive personal financial data.

## Never commit sensitive information

Do not commit real:
- .env files or API keys
- Supabase secret/service-role keys
- access tokens
- bank/card statements
- receipts, bills, screenshots or uploaded financial documents
- transaction exports
- personal account/card numbers
- production database dumps

## Credential model

The FinanceCanvas client/Skill talks only to the controlled FinanceCanvas Edge Function using an installation API key. Only its SHA-256 hash is stored in the FinanceCanvas database.

The Edge Function owns server-side Supabase access. Supabase secret/server keys bypass RLS and must never be exposed to a client, prompt, public log, or source repository.

v0.1 enables RLS and revokes direct anon and authenticated privileges on FinanceCanvas data tables; the controlled Edge Function is the data gateway.

## Data integrity

- exact duplicates are blocked
- duplicate overrides require a reason
- edits are two-step
- permanent deletes are two-step
- soft delete is the default
- audit history records material changes
- uploaded documents are treated as untrusted input

## Vulnerability reporting

Do not open a public issue containing secrets, personal financial data, or exploit details that could expose a live installation.


## Sensitive-data handling

FinanceCanvas classifies uploaded information before persistence.

Critical authentication/payment secrets must never be persisted or repeated back to the user. If detected, FinanceCanvas warns the user, excludes the value from storage and audit records, and gives appropriate remediation guidance.

High-risk government/payment identifiers are minimized. v0.1 stores only masked or final-four account/card identifiers and does not intentionally persist government identity numbers.

## Connector-first security

When an explicitly authorized Supabase connector is available, use it instead of asking the user to duplicate database credentials into a local file. Connector credentials must never be copied into repository files, FinanceCanvas records, audit data, or chat output.

## Incident response

For suspected personal or financial data exposure: contain access, rotate affected credentials where applicable, preserve only necessary evidence, avoid placing raw secrets in incident records, determine notification obligations, and follow COMPLIANCE.md before production use.
