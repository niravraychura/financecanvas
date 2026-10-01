# FinanceCanvas API

This Edge Function is the controlled data-access layer between FinanceCanvas clients/skills and Supabase Postgres.

## Authentication

Clients authenticate with a FinanceCanvas installation key beginning with `fc_`.

Only the SHA-256 hash of each installation key is stored in `financecanvas_api_keys`.

Supabase server credentials are supplied to the Edge Function by Supabase itself and must never be committed to source control or exposed to the Skill/client.

The function is deployed with platform JWT verification disabled because it implements its own FinanceCanvas API-key authentication. This is intentional.

## Stable write rules

The API independently enforces:
- final confirmation before transaction import
- exact duplicate blocking
- reason-required duplicate overrides
- near-duplicate review
- two-step edits
- two-step deletion
- audit history

These rules remain in force even if `SKILL.md` changes.

## Client configuration

Use environment variables outside source control:

```
FINANCECANVAS_API_URL=https://YOUR_PROJECT_REF.supabase.co/functions/v1/financecanvas-api
FINANCECANVAS_API_KEY=fc_...
```


## Runtime scopes

External-client keys may be restricted to a single FinanceCanvas workspace and to explicit scopes:

- `read` — read/query operations
- `write` — create/import/edit/delete request operations
- `watch` — Watch rule/check operations
- `export` — JSON/CSV exports
- `admin` — key-management/administrative operations

A workspace-scoped key cannot target another workspace.

Owner/developer Supabase admin connectors are for maintenance, not normal end-user/LLM runtime access.

## Data portability and erasure

The API supports:
- `export_workspace_json`
- `export_workspace_csv`
- `request_workspace_erasure`
- `confirm_workspace_erasure`

Workspace erasure is deliberately separate from ordinary record deletion and requires explicit confirmation.

## Dependency pinning

The Edge Function pins `@supabase/supabase-js` to an exact reviewed version. Dependency changes require the FinanceCanvas security checklist.
