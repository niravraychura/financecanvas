# FinanceCanvas Agent Instructions

These rules apply to any AI/coding agent modifying this repository.

## Mandatory after every change

1. Read `SECURITY_CHECKLIST.md`.
2. Run:
   ```
   python -m unittest discover -s tests -v
   python scripts/security_check.py
   ```
3. If database/API/auth/Skill behavior changed, also perform the Supabase checks in `SECURITY_CHECKLIST.md`.
4. Do not call the work complete if the security result is BLOCKED.

## Never commit

- real credentials or local secret files;
- personal financial records;
- source statements/receipts/screenshots/exports;
- production database dumps;
- real account/card/government identity values.

Use synthetic data in tests/examples.

## Architecture rules

- Owner/developer Supabase admin connectors are for maintenance only.
- Normal runtime access must be least-privilege.
- Do not weaken exact/near duplicate controls.
- Do not bypass two-step edit/delete/workspace-erasure confirmation.
- Do not persist critical secrets or blocked identifiers.
- Do not give a normal LLM arbitrary SQL/database-admin access.
- Keep source-document persistence disabled unless a future reviewed design explicitly changes it.
- FinanceCanvas remains prototype/not production-ready until the production gate is completed.

## Before adding a financial feature

Check:
- `SKILL.md`
- `COMPLIANCE.md`
- `THREAT_MODEL.md`
- `DATA_RETENTION.md`
- relevant files under `references/`

If a feature changes regulated activity, data collection, third parties, identity/access, or jurisdiction, update the compliance/threat/security documents before release.
