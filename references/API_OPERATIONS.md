# FinanceCanvas Controlled Operations

The Edge Function is an optional restricted runtime adapter. Owner/developer maintenance may use an explicitly authorized Supabase connector, but normal runtime should remain least-privilege.

## Read
- initialization_status
- list_profiles
- list_accounts
- list_records
- search_transactions
- get_financial_summary
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
- no arbitrary SQL from the Skill;
- no critical-secret persistence;
- exact duplicate protection;
- reason-required duplicate overrides;
- two-step edits/deletions/erasure;
- data-minimized audit records;
- no cross-workspace access for scoped runtime keys.


## Financial Inbox records

The controlled generic record operations support `imports`, `extracted_fields`, and `confirmation_queue`.

Transaction batch commits use the database RPC `financecanvas_commit_transaction_batch` so confirmed imports are atomic.
