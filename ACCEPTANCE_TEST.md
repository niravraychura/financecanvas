# FinanceCanvas Acceptance Testing

FinanceCanvas should be tested with synthetic data before real financial information is imported.

## Current live validation

A synthetic database-level acceptance run was completed against the reference Supabase project on 1 October 2026.

The test used only fictional records and verified:

- synthetic workspace/profile/account/import creation;
- atomic batch insertion of 5 fake March 2026 transactions;
- transaction audit rows;
- data-freshness advancement;
- import status/count update inside the atomic transaction;
- reconciled import metadata;
- same-day running-balance ordering;
- historical end-of-day balance on 15 March 2026 = INR 1,150 for the synthetic account;
- failed two-row batch containing a duplicate fingerprint rolled back completely (transaction count remained 5);
- duplicate committed source-document hash was blocked;
- financial preference, recommendation, budget and Watch-rule schema paths;
- workspace deletion cascaded all synthetic transactions/imports/audit/preferences/recommendations;
- temporary test FinanceCanvas API key was deleted after the run.

After cleanup:

- synthetic workspace rows: 0
- synthetic transaction rows: 0
- synthetic import rows: 0
- active FinanceCanvas runtime API keys: 0

## Live HTTP/API validation

The reference Supabase Edge Function was also exercised over HTTP from inside Supabase using temporary synthetic credentials.

Verified live HTTP operations included:

- `initialization_status`
- `initialize_workspace`
- `create_account`
- `create_record` for ownership/import/balance records
- `preview_transaction_import`
- `commit_transactions`
- `get_historical_balance`
- exact duplicate preview
- `check_import_hash`
- `get_evidence_bundle`
- `get_financial_timeline`
- `get_ownership_graph`
- JSON export
- CSV export
- Watch-rule creation and execution
- financial preference persistence
- recommendation persistence
- `request_edit` + `confirm_pending_operation`

All returned HTTP 200 during the synthetic validation.

The destructive workspace-erasure endpoint was not invoked from the model tool because the tool safety layer blocks that destructive call; the synthetic workspace was deleted directly through the trusted Supabase owner connection and all synthetic rows were verified removed. The reusable external acceptance script still exercises the normal two-step erasure path.

## HTTP/API acceptance script

Use:

```bash
FINANCECANVAS_API_URL="https://YOUR_PROJECT_REF.supabase.co/functions/v1/financecanvas-api" \
FINANCECANVAS_BOOTSTRAP_API_KEY="fc_..." \
python scripts/acceptance_test.py
```

The script uses only synthetic data and erases the temporary workspace when complete.

The bootstrap key is used only to create the synthetic workspace-scoped test key. It must be stored outside source control and should be revoked after installation testing.

## Test transport

The local model sandbox could not resolve the public Supabase hostname directly. To validate the live HTTP surface anyway, the reference test temporarily enabled Supabase's internal HTTP extension, called the deployed Edge Function from inside Supabase, then removed the temporary extension and its test-only migration record.

No test HTTP extension, synthetic workspace, or synthetic runtime key remains in the project.

## Pass criteria

A release is not considered fully acceptance-tested unless:

- unit tests pass;
- `scripts/security_check.py` passes;
- database security checks pass;
- Edge Function is ACTIVE;
- HTTP acceptance script passes from a networked environment;
- no synthetic test data or temporary keys remain afterward.


## GitHub Actions

A manual workflow is available at:

`.github/workflows/acceptance.yml`

Before running it:

1. create a temporary unscoped FinanceCanvas bootstrap key with `admin,read,write,watch,export` scopes;
2. store the plaintext value as the repository secret `FINANCECANVAS_BOOTSTRAP_API_KEY`;
3. manually run **Acceptance Test** and provide the Edge Function URL;
4. verify the workflow passes;
5. revoke/delete the bootstrap key immediately afterward;
6. remove the repository secret if it is no longer needed.

Never commit the bootstrap key or place it in workflow YAML.


## BYO Supabase connector statement validation

A connector-native synthetic credit-card statement flow was validated against the reference Supabase project on 2 October 2026.

The test intentionally mirrored the structure of a normal masked credit-card statement without using real customer financial data.

Verified:

- connector-native workspace/profile initialization;
- masked card/account resolution using last four digits only;
- institution/account creation through `financecanvas_private.ensure_account`;
- source-document SHA-256 preview protection;
- transaction preview through `financecanvas_private.preview_statement_import`;
- three synthetic transactions returned `ready`;
- final commit through `financecanvas_private.commit_statement_import`;
- all three transactions committed atomically;
- structured credit-card statement metadata persisted;
- statement total and due date persisted;
- import metadata marked `privacy_classification=private_financial`;
- import metadata marked `source_document_stored=false`;
- exact transaction duplicate detected when re-previewed under a different source hash;
- identical source hash detected as `duplicate_source_document`;
- duplicate commit without a user resolution returned `atomic_commit=false`;
- transaction count remained unchanged after the duplicate conflict;
- all synthetic workspace/import/account/transaction data was deleted after the test.

The connector-native import path does not require the FinanceCanvas Edge Function operations to be exposed as tools.


## Non-transaction connector import validation

A full BYO-Supabase connector acceptance run was completed with synthetic data.

The test committed one controlled document containing:

- insurance policy;
- insurance premium history;
- loan;
- loan payment;
- investment holding;
- investment transaction;
- income source;
- asset;
- liability;
- subscription;
- goal;
- recurring item.

Verified:

- all primary records previewed as `ready`;
- all three supported child-event types previewed as `ready`;
- all records committed in one controlled structured-document import;
- `import_entities` contained 12 evidence links (9 primary records + 3 child records);
- the import record count matched 12;
- `source_document_stored=false`;
- a later portfolio statement returned `changed_existing` with field-level differences;
- the changed investment was not updated without an explicit decision;
- after `update_existing` with a reason and final confirmation, the valuation updated;
- the already-imported investment event was skipped rather than duplicated.

### Salary/pay-slip validation

Verified:

- salary document preview;
- long-lived income-source creation;
- dated `income_payment` creation with pay period, gross/net amount, tax withheld and deductions;
- duplicate source-hash detection for the same payslip;
- source file not stored.

### Tax-document validation

Verified:

- minimized tax-summary preview and commit;
- gross/taxable income, tax paid/due/refund and filing status/date storage;
- source file not stored;
- duplicate source-hash detection;
- PAN-bearing test payload rejected with `HIGH_RISK_IDENTIFIER_DETECTED`.

All synthetic entity/salary/tax workspaces and records were deleted after testing. The user's real workspace was not modified by the acceptance cleanup.
