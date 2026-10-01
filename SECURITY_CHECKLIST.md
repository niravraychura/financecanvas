# FinanceCanvas Security Change Checklist

This checklist is **mandatory after every code, schema, Skill, infrastructure, dependency, or documentation change that can affect behavior or security**.

A change is not considered complete until the relevant checks pass.

## 1. Repository safety

- [ ] No real credentials, API keys, tokens, passwords, private keys, or local secret files are committed.
- [ ] No real bank/card statements, receipts, screenshots, exports, database dumps, or personal financial records are committed.
- [ ] Test fixtures contain fictional/synthetic data only.
- [ ] New files are covered by `.gitignore` where appropriate.
- [ ] GitHub CI/security checks pass.

## 2. Access control

- [ ] Normal runtime access remains least-privilege.
- [ ] Owner/developer Supabase admin access is not exposed to normal users/LLMs.
- [ ] Runtime keys are workspace-scoped where possible.
- [ ] Runtime keys have only required scopes: read/write/watch/export/admin.
- [ ] Direct anon/authenticated table access has not been accidentally enabled.
- [ ] RLS remains enabled on FinanceCanvas data tables.

## 3. Sensitive-data controls

- [ ] Critical secrets cannot be persisted or echoed.
- [ ] Full card/account identifiers are rejected, masked, or reduced to final four digits.
- [ ] Government identity identifiers remain blocked unless a separately reviewed feature explicitly requires them.
- [ ] Audit/security logs do not contain raw secrets.
- [ ] Source documents are not intentionally persisted by FinanceCanvas.
- [ ] User-facing warnings explain that the host chat/LLM may have its own retention policy.

## 4. Data integrity

- [ ] Exact duplicate protection still works.
- [ ] Near-duplicate review still works.
- [ ] Duplicate overrides require a reason.
- [ ] Edits remain two-step.
- [ ] Permanent deletion remains two-step.
- [ ] Workspace erasure requires explicit confirmation.
- [ ] Audit records remain data-minimized.
- [ ] Older imports cannot move data-freshness dates backward.

## 5. Financial safety

- [ ] FinanceCanvas does not initiate payments or hold funds.
- [ ] FinanceCanvas does not collect banking login credentials.
- [ ] FinanceCanvas does not scrape authenticated banking portals.
- [ ] Investment functionality remains within the documented SEBI boundary unless separately reviewed.
- [ ] Fraud/anomaly findings are presented as signals, not proof.

## 6. Privacy/compliance

- [ ] Data collection is necessary for a documented purpose.
- [ ] Retention/deletion behavior is defined for any new data category.
- [ ] Export/correction/deletion behavior remains possible where applicable.
- [ ] Any new third party/subprocessor is documented and reviewed.
- [ ] Any new country/region or commercial use triggers a compliance review.
- [ ] COMPLIANCE.md and PRIVACY.md are updated when required.

## 7. Supabase/backend verification

After database/API-affecting changes:

- [ ] Run Supabase security advisors.
- [ ] Review performance advisors for meaningful new issues.
- [ ] Confirm Edge Function is ACTIVE.
- [ ] Confirm expected migration(s) are applied.
- [ ] Confirm anon/authenticated direct DML privileges remain blocked.
- [ ] Confirm no unexpected active API keys exist.
- [ ] Confirm production_ready remains false until the production gate is completed.

## 8. Release decision

Record one result in the PR/release notes:

- **PASS** — all relevant checks completed.
- **PASS WITH ACCEPTED RISK** — document the risk, owner, reason and remediation date.
- **BLOCKED** — do not release.

## Permanent project rule

**Every FinanceCanvas change must be followed by a security-impact review.**

For trivial prose-only changes, CI plus a quick checklist review may be sufficient.  
For Skill behavior, database, API, authentication, import, alert, privacy, or financial-decision changes, perform the full relevant checklist and Supabase verification.
