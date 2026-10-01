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

## HTTP/API acceptance script

Use:

```bash
FINANCECANVAS_API_URL="https://YOUR_PROJECT_REF.supabase.co/functions/v1/financecanvas-api" \
FINANCECANVAS_BOOTSTRAP_API_KEY="fc_..." \
python scripts/acceptance_test.py
```

The script uses only synthetic data and erases the temporary workspace when complete.

The bootstrap key is used only to create the synthetic workspace-scoped test key. It must be stored outside source control and should be revoked after installation testing.

## Environment limitation of the reference run

The model execution sandbox used for the reference implementation cannot resolve the public Supabase function hostname, so the HTTP script could not be invoked from that sandbox.

This is why the project keeps both:

1. live Supabase database/integrity validation; and
2. a reusable external HTTP acceptance script.

A successful Edge Function deployment confirms the function compiles, but it is not a substitute for running the HTTP acceptance script from a networked environment.

## Pass criteria

A release is not considered fully acceptance-tested unless:

- unit tests pass;
- `scripts/security_check.py` passes;
- database security checks pass;
- Edge Function is ACTIVE;
- HTTP acceptance script passes from a networked environment;
- no synthetic test data or temporary keys remain afterward.
