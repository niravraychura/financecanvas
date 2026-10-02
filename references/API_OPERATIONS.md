# FinanceCanvas Controlled Operations

The Edge Function is an optional restricted runtime adapter.

For personal/private **BYO Supabase connector mode**, an explicitly authorized Supabase connector may be the runtime data path when it follows `CONNECTOR_MODE.md`. External/non-connector runtimes should use the restricted Edge Function/API.

## Read
- initialization_status
- list_profiles
- list_accounts
- list_records
- search_transactions
- get_financial_summary
- get_historical_balance
- get_financial_timeline
- get_ownership_graph
- get_evidence_bundle
- detect_recurring_patterns
- check_import_hash
- list_watch_rules
- list_watch_findings

## Write
- initialize_workspace
- create_profile
- create_account
- create_record
- preview_transaction_import
- commit_transactions
- request_edit
- request_delete
- confirm_pending_operation
- request_workspace_erasure
- confirm_workspace_erasure
- upsert_financial_preference
- record_recommendation

## Watch
- create_watch_rule
- run_watch_checks

## Export
- export_workspace_json
- export_workspace_csv

## Administration
- create_api_key
- revoke_api_key

External API keys should be bound to a workspace whenever practical and limited to the minimum scopes required.

## Invariants

Regardless of access path:
- no arbitrary/ad-hoc SQL from the Skill; connector mode may use only the approved SQL/RPC procedures documented in `CONNECTOR_MODE.md`;
- no critical-secret persistence;
- exact duplicate protection;
- reason-required duplicate overrides;
- two-step edits/deletions/erasure;
- data-minimized audit records;
- no cross-workspace access for scoped runtime keys.


## Financial Inbox records

The controlled generic record operations support `imports`, `extracted_fields`, and `confirmation_queue`.

Transaction batch commits use the database RPC `financecanvas_commit_transaction_batch` so confirmed imports are atomic.


## Evidence and history operations

`get_historical_balance` returns an exact statement running balance when available; otherwise it reconstructs from a confirmed anchor and returns evidence/confidence.

`get_evidence_bundle` returns the exact transaction/account/import/freshness records used for evidence-aware financial answers.

`get_financial_timeline` returns dated financial events across transactions, balances, loan payments, insurance premiums, investment events, statements and snapshots.

`get_ownership_graph` returns profile/household/account/asset/liability/loan nodes and ownership/relationship edges.

`detect_recurring_patterns` discovers recurring transaction patterns but does not persist them without user confirmation.

`check_import_hash` checks a SHA-256 source-document digest without storing the source file.


## Connector-native bootstrap

When an authorized Supabase connector is available, the Skill does not need the HTTP `initialization_status` or `initialize_workspace` operations to be exposed as tools.

Use:

```sql
select financecanvas_private.connector_status();
```

and:

```sql
select financecanvas_private.initialize_workspace(
  '<workspace name>',
  '<base currency>',
  '<profile name>'
);
```

These routines operate in the user-selected Supabase project and are not granted to `anon` or `authenticated`.

Never hardcode the repository author's Supabase project reference/URL.


## Connector-native statement import

When an authorized Supabase connector is available, the HTTP import operations do not need to be exposed as tools.

Use the private connector routines:

- `financecanvas_private.ensure_account(...)`
- `financecanvas_private.preview_statement_import(...)`
- `financecanvas_private.commit_statement_import(...)`

The connector commit routine requires explicit final confirmation, rechecks exact/near duplicates, writes duplicate-review decisions, commits transactions atomically through the FinanceCanvas batch RPC, creates structured import/credit-card statement metadata, and never stores source document bytes.

Ordinary private financial fields are importable. Critical secrets and full high-risk identifiers remain prohibited/minimized.

See `CONNECTOR_MODE.md` for safe Base64 transport of untrusted JSON when the connector only accepts SQL strings.
