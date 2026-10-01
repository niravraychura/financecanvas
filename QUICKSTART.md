# FinanceCanvas Quick Start

## Personal setup with an authorized Supabase connector

1. Clone the repository.
2. Load the repository's `SKILL.md` and `references/` into your AI project/Skill system.
3. Connect/authorize the Supabase project for owner maintenance.
4. Apply `supabase/migrations/` in filename order.
5. Deploy `supabase/functions/financecanvas-api/index.ts`.
6. Run the tests/security gate.
7. Run the synthetic acceptance test.
8. Ask FinanceCanvas to initialize your workspace.
9. Only then begin importing real statements.

No local Supabase admin `.env` is needed when the authorized connector already supplies owner access.

## Required post-change check

```bash
python -m unittest discover -s tests -v
python scripts/security_check.py
```

For backend/schema/auth/Skill changes, also complete `SECURITY_CHECKLIST.md`.

For detailed setup, read [INSTALL.md](INSTALL.md).
