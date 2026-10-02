# FinanceCanvas Data Retention

FinanceCanvas follows purpose limitation and data minimization.

| Data class | Default approach |
|---|---|
| Source PDFs/images/CSVs/XLSX | Not intentionally persisted by FinanceCanvas |
| Transactions/accounts/loans/assets/etc. | Retain while needed for the user's financial record |
| Duplicate review history | Retain while relevant to integrity/audit |
| Audit log | Default 365 days in current prototype unless user/legal need differs |
| Sensitive-data event metadata | Default 180 days; category/action only, no raw secret |
| Security-event metadata | Default 365 days |
| Privacy requests | Retain as needed to demonstrate request handling |
| Breach incidents | Retain according to applicable legal/security requirements |
| API keys | Store hashes only; revoke/delete when no longer required |

## Deletion

Normal record deletion is soft delete unless permanent deletion is explicitly requested.

Full workspace erasure:
1. recommend export first if appropriate;
2. create a pending erasure request;
3. show the impact;
4. require explicit confirmation;
5. delete the workspace and linked FinanceCanvas records.

Do not promise deletion of independent copies held by the host LLM/chat provider, Supabase platform backups/logs, banks, issuers, or other third parties.

## Legal/security holds

For a future commercial deployment, do not permanently erase records that are subject to a valid legal/regulatory/security retention obligation. This must be implemented before production use if such obligations apply.


## Structured financial document records

Structured records such as `import_entities`, `income_payments` and minimized `tax_records` may be retained as part of the user's FinanceCanvas history until edited/erased according to the normal workspace controls.

They contain structured facts/evidence links only and must not be used to retain reconstructable source-document contents.

Source PDFs/images/spreadsheets remain temporary inputs and are not intentionally persisted in FinanceCanvas storage.
