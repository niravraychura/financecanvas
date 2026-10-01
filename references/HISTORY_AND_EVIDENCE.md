# FinanceCanvas History and Evidence

## Evidence-aware answers

For historical or aggregate financial questions, prefer `get_evidence_bundle` or another controlled query that exposes the exact records used.

When material, an answer should state:
- period covered;
- profile/account scope;
- data freshness;
- transaction/record count;
- whether the answer is exact, calculated, reconstructed, estimated, or a recommendation;
- reconciliation/coverage limitations.

Do not claim completeness if an account is stale or the requested period is not covered by confirmed data.

## Historical balance

Use `get_historical_balance`.

Preferred evidence order:
1. confirmed running balance on the requested date plus statement sequence;
2. deterministic reconstruction from a confirmed account-balance anchor;
3. no answer if order/coverage is insufficient.

Never infer a historical bank balance from the current balance alone.

## Financial timeline

Use `get_financial_timeline` to build a chronological history from:
- transactions;
- balance observations;
- loan payments;
- insurance premiums;
- investment events;
- credit-card statements;
- financial snapshots.

The timeline is a view of stored evidence, not a separate source of truth.

## Ownership graph

Use `get_ownership_graph` to explain who owns/is responsible for accounts, assets, liabilities and loans and how profiles belong to households.

Do not infer an ownership edge that is not stored/confirmed.
