# FinanceCanvas upgrades

Skill reinstall and database upgrade are separate actions. Installing this repository replaces the local Skill files, not the user's financial database. Discover the selected user's project; never hardcode the author's project.

## Existing project

1. Read connector_status / initialization_status and migration history before writing.
2. Compare bundled migration names and definitions with applied migrations. Historical connector deployments used different timestamps from the early GitHub files. A timestamp mismatch alone does not mean a feature is absent.
3. For verified equivalent live migrations, reconcile migration history through the Supabase-supported migration repair workflow; do not execute their SQL again merely to change the filename timestamp. Review CLI --help and the exact affected versions first. Never blindly mark an unapplied migration as applied.
4. Apply only genuinely missing bundled migrations in filename order using the user's authorized upgrade scope. Do not db reset/drop tables, create a second workspace, re-import statements or copy private data into source control.
5. Redeploy the bundled financecanvas-api when the installed API is older. It uses its own hashed FinanceCanvas key authentication; preserve verify_jwt=false only after reviewing that authentication. Keys remain external to the repository. A connector-only installation does not need an HTTP key.
6. Verify schema 0.1.5, new routines/tables, privacy controls, RLS/direct grants and existing counts. Treat readiness and category coverage separately.

## Restored live migration equivalents

The following source migrations contain the SQL of already-deployed versions. New source timestamps keep the historical GitHub dependency order intact. Use the explicit mapping to avoid replaying equivalent migrations on a previously repaired project.

| Bundled file | Deployed version |
|---|---|
| `20261002090217_financecanvas_v014_database_first_analysis.sql` | `20261002074704` |
| `20261002090219_financecanvas_v014_atomic_analysis_ready_transaction_commit.sql` | `20261002074916` |
| `20261002090221_financecanvas_v014_atomic_transaction_analysis_repair.sql` | `20261002075016` |
| `20261002090224_financecanvas_v014_repair_by_statement_reference.sql` | `20261002080353` |
| `20261002090226_financecanvas_v014_safe_direction_repair.sql` | `20261002081602` |
| `20261002090228_financecanvas_v015_transaction_clarification_memory.sql` | `20261002084828` |

The additional `financecanvas_v015_import_adapter_parity` migration requires narration for every transaction import and resolves stored aliases at the common commit boundary. `financecanvas_v015_connector_clarifications` introduces owner-connector correction adapters and alias resolution; verify it separately. It does not copy any user's clarifications into the repository.

## Fresh project

Apply all bundled migrations in filename order to the newly selected project. Create a workspace only through the normal initialization workflow. The repository contains schema/API code and synthetic test data only, never an existing user's statements, merchant memory, credentials or financial rows.
