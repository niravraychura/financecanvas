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

## Connector-mode runtime rules

An authorized Supabase owner connector is privileged. Treat it as a trusted owner path, not a public application API.

For personal/private connector mode:

- Reads must always be scoped to the selected FinanceCanvas workspace.
- Do not run ad-hoc DDL during normal finance use.
- DDL is allowed only for an explicitly confirmed FinanceCanvas installation/upgrade using bundled migrations.
- Prefer FinanceCanvas database functions/RPCs where they exist.
- Transaction batch commits must use `public.financecanvas_commit_transaction_batch(...)`; never insert a confirmed imported statement row-by-row.
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
