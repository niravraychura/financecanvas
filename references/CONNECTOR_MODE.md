# FinanceCanvas BYO Supabase Connector Mode

FinanceCanvas uses a **bring-your-own-Supabase (BYO Supabase)** model and is **not** tied to one shared Supabase project.

Each user may connect their own Supabase account/project through the AI host's authorized Supabase connector. Financial data stays in the project that user selected.

## Non-negotiable portability rule

Never hardcode or assume:

- a Supabase project reference;
- a Supabase project URL;
- an organization ID;
- the FinanceCanvas author's Supabase account/project;
- a service-role/secret key.

Discover the connected user's projects at runtime.

## Project selection

When an authorized Supabase connector is available:

1. List the user's accessible Supabase projects.
2. Keep only usable/healthy projects when status is available.
3. If exactly one suitable project exists, use it.
4. If multiple suitable projects exist and the user has not already selected one, ask which project should store FinanceCanvas data.
5. Do not choose merely because a project happens to be named `FinanceCanvas`.
6. Prefer a dedicated project for FinanceCanvas because it gives clearer isolation, backups and lifecycle management.
7. Never copy the selected project ID into the public FinanceCanvas repository.

The selected project is the user's data store. Another FinanceCanvas user may select a completely different Supabase project.

## Detecting whether FinanceCanvas is installed

Before using FinanceCanvas tables, run a read-only schema check through the connector, for example:

```sql
select
  to_regclass('public.financecanvas_schema') as financecanvas_schema,
  to_regprocedure('financecanvas_private.connector_status()') as connector_status;
```

If `public.financecanvas_schema` is absent, the FinanceCanvas schema is not installed in that project.

If the user wants persistent FinanceCanvas storage, ask one concise confirmation before installing the bundled migrations.

Apply the bundled files under `supabase/migrations/` **in filename order** to the selected project.

After installation, run Supabase security advisors and the FinanceCanvas security checks.

The Edge Function is optional for connector-only personal use. Deploy it when an external/non-connector runtime needs the restricted FinanceCanvas HTTP API.

## Connector status

After the schema is installed, use the connector-native status routine:

```sql
select financecanvas_private.connector_status();
```

This returns the schema version, workspace count, initialization state, source-document-persistence flag and production-ready flag.

Do not require the HTTP/Edge `initialization_status` operation when the host already has an authorized Supabase connector.

## First workspace initialization

When the user has confirmed:

- workspace name;
- base currency;
- first profile name;

call the connector-native bootstrap routine through the authorized Supabase connector:

```sql
select financecanvas_private.initialize_workspace(
  '<workspace name>',
  '<3-letter currency>',
  '<profile name>'
);
```

Use parameterized/query-tool arguments when the connector supports them. Do not interpolate untrusted document text into SQL.

The routine is idempotent for the same workspace/profile names and records an audit entry.

**Important:** If `initialize_workspace` is not exposed as an HTTP/API tool but an authorized Supabase connector exists, do **not** stop. Use this private connector routine.

## Statement import in connector mode

When the AI host can read a local statement/PDF **and** has an authorized Supabase connector, do not stop merely because the HTTP operations `preview_transaction_import` or `commit_transactions` are not exposed as tools.

Use the connector-native routines below.

### 1. Resolve/create the financial account

After the user/profile is known, call:

```sql
select financecanvas_private.ensure_account(
  '<workspace uuid>',
  '<profile uuid>',
  '<institution name>',
  '<account display name>',
  '<bank|credit_card|wallet|cash|brokerage|loan|other>',
  '<currency>',
  '<masked last4>',
  <credit limit or null>
);
```

For an already-masked card such as `4035XXXXXXXX8007`, store only `8007` in `identifier_last4`.

If the routine returns material differences for an existing account (for example a changed credit limit/currency), show the difference and ask before editing the existing account. Do not silently overwrite it.

### 2. Hash the source file locally

If source bytes are accessible, compute SHA-256 locally and retain only the digest for duplicate protection.

Do not upload/store the source PDF in Supabase.

### 3. Extract and classify

Ordinary statement fields are allowed structured finance data, including:

- profile/full name;
- masked card/account identifier;
- transactions and merchant names;
- statement dates;
- balances/limits;
- total/minimum due;
- due date;
- rewards and finance-related summary values.

Exclude unnecessary address/contact/marketing/barcode data by default.

Critical secrets and full restricted identifiers remain prohibited/minimized according to `IMPORT_RULES.md`.

### 4. Preview through the connector

Call:

```sql
select financecanvas_private.preview_statement_import(
  '<workspace uuid>',
  '<profile uuid>',
  '<account uuid>',
  '<sha256 digest or null>',
  <transactions jsonb>
);
```

The preview performs:

- source-document duplicate check;
- exact transaction duplicate check;
- near-duplicate check;
- deterministic connector fingerprinting;
- validation of required transaction fields.

If conflicts/uncertain rows exist, show only those items and collect the user's decision/reason.

### 5. Final confirmation

Before persistence, summarize:

- account/profile;
- statement period;
- transaction count;
- duplicate decisions;
- statement totals/reconciliation when available;
- fields excluded/masked;
- confirmation that the source document itself will not be stored.

Ask for one explicit final confirmation.

### 6. Commit atomically through the connector

After confirmation call:

```sql
select financecanvas_private.commit_statement_import(
  '<workspace uuid>',
  '<profile uuid>',
  '<account uuid>',
  <import metadata jsonb>,
  <transactions jsonb>,
  <duplicate resolutions jsonb>,
  true
);
```

This procedure:

- rechecks exact/near duplicates at commit time;
- blocks unresolved duplicates;
- stores duplicate-review decisions/reasons;
- creates structured import metadata only;
- atomically commits the transaction batch;
- creates credit-card statement metadata when applicable;
- records audit/freshness data;
- never stores the source file.

If `atomic_commit=false`, do not claim the statement was imported.

### Passing untrusted JSON safely through an SQL-only connector

If the Supabase connector exposes only a raw `execute_sql` string interface, **do not paste document text directly into SQL string literals**.

Encode the JSON payload to Base64 locally, then decode it inside SQL:

```sql
convert_from(
  decode('<base64 of UTF-8 JSON>', 'base64'),
  'UTF8'
)::jsonb
```

Use this expression for transaction/import/resolution JSON arguments.

This keeps merchant descriptions or other untrusted document text from becoming executable SQL.

## Connector-mode runtime rules

An authorized Supabase owner connector is privileged. Treat it as a trusted owner path, not a public application API.

For personal/private connector mode:

- Reads must always be scoped to the selected FinanceCanvas workspace.
- Do not run ad-hoc DDL during normal finance use.
- DDL is allowed only for an explicitly confirmed FinanceCanvas installation/upgrade using bundled migrations.
- Prefer FinanceCanvas database functions/RPCs where they exist.
- Connector statement imports must use `financecanvas_private.preview_statement_import(...)` followed by `financecanvas_private.commit_statement_import(...)`; never insert a confirmed imported statement row-by-row. The public atomic batch RPC is an internal implementation detail of the connector commit routine.
- Exact/near duplicate review remains mandatory before commit.
- Edits and permanent deletes must preserve FinanceCanvas's request/confirmation/audit workflow.
- Sensitive-data minimization rules remain mandatory.
- Never expose or persist Supabase admin credentials.
- Never query or modify non-FinanceCanvas application tables in a shared Supabase project.
- Run the post-change security review after schema/API changes.

The Skill may execute narrowly scoped SQL through the authorized connector only when it follows this document. It must not execute arbitrary SQL merely because the connector has admin access.

## External API mode

If no authorized Supabase connector is available but a FinanceCanvas API URL/key is configured, use the controlled Edge Function operations documented in `references/API_OPERATIONS.md`.

External runtime clients should use workspace-scoped least-privilege FinanceCanvas keys and should not receive Supabase admin credentials.

## No persistent backend

If neither an authorized Supabase connector nor a configured FinanceCanvas API is available:

- the Skill is still installed;
- FinanceCanvas may analyze temporary user-provided data;
- clearly state that persistent storage/history is not configured;
- do not pretend data was saved.

## Multi-user distribution model

A public installation of the FinanceCanvas Skill should look like:

```text
User A + FinanceCanvas Skill → User A's Supabase project
User B + FinanceCanvas Skill → User B's Supabase project
User C + FinanceCanvas Skill → User C's Supabase project
```

There is no requirement for those users to share the author's Supabase project.

This BYO-Supabase model reduces central data custody, but each user/operator is still responsible for securing their Supabase account/project and for any legal obligations arising from their use.


## Non-transaction financial documents

When the host can read a local financial document and has an authorized Supabase connector, do not require the Edge Function/API operations to be exposed.

### Structured entity documents

For insurance, loans, investment/holding statements, assets, liabilities, subscriptions, goals and recurring items:

1. Extract only the allowed structured fields.
2. Compute the local source SHA-256 when bytes are available.
3. Call:

```sql
select financecanvas_private.preview_financial_document(
  '<workspace uuid>',
  '<profile uuid>',
  '<sha256 or null>',
  '<document type>',
  <records jsonb>
);
```

Each record uses:

```json
{
  "client_id": "record-1",
  "entity_type": "insurance_policy | loan | investment | income_source | asset | liability | subscription | goal | recurring_item",
  "data": {},
  "children": []
}
```

Supported child events:

- `insurance_premium`
- `loan_payment`
- `investment_transaction`

If preview returns `changed_existing`, show the field-level differences and ask:

**Keep existing / Update existing / Add as separate**

`update_existing` and `add_separate` require a reason.

For an exact duplicate child event, ask:

**Skip / Add as separate**

Adding separately requires a reason.

After explicit final confirmation, call:

```sql
select financecanvas_private.commit_financial_document(
  '<workspace uuid>',
  '<profile uuid>',
  '<sha256 or null>',
  '<document type>',
  '<original filename or null>',
  <records jsonb>,
  <resolutions jsonb>,
  true
);
```

The commit is atomic for the controlled document write set, records import/entity links and audit history, and stores no source bytes.

### Salary/pay slips

Salary slips preserve both the long-lived income source and dated pay-period history.

Preview:

```sql
select financecanvas_private.preview_salary_document(
  '<workspace uuid>',
  '<profile uuid>',
  '<sha256 or null>',
  <income_source jsonb>,
  <payment jsonb>
);
```

Commit after final confirmation:

```sql
select financecanvas_private.commit_salary_document(
  '<workspace uuid>',
  '<profile uuid>',
  '<sha256 or null>',
  '<filename or null>',
  <income_source jsonb>,
  <payment jsonb>,
  <resolutions jsonb>,
  true
);
```

The pay-period record is stored in `income_payments`; source payslip bytes are not stored.

### Tax documents

Tax imports are intentionally minimized. Persist financial totals/status only; never persist PAN, Aadhaar/VID, passport/tax identifiers, passwords, OTPs, or similar credentials.

Preview:

```sql
select financecanvas_private.preview_tax_document(
  '<workspace uuid>',
  '<profile uuid>',
  '<sha256 or null>',
  <tax_record jsonb>
);
```

Commit after final confirmation:

```sql
select financecanvas_private.commit_tax_document(
  '<workspace uuid>',
  '<profile uuid>',
  '<sha256 or null>',
  '<filename or null>',
  <tax_record jsonb>,
  '<decision or null>',
  '<reason or null>',
  true
);
```

Changed existing tax records require the same explicit **Keep / Update / Add separate** decision, with a reason for Update/Add.

### Document routing summary

```text
Bank/card/wallet/brokerage transaction statement
  -> preview_statement_import / commit_statement_import

Insurance/loan/investment/asset/liability/subscription/goal document
  -> preview_financial_document / commit_financial_document

Salary/pay slip
  -> preview_salary_document / commit_salary_document

Tax summary/return
  -> preview_tax_document / commit_tax_document
```

If one document contains both entity data and transaction rows, route each portion through its appropriate controlled importer rather than bypassing duplicate/confirmation rules.
