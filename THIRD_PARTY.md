# Third-Party Software

FinanceCanvas does not vendor third-party library source code in this repository.

The deployed Edge Function imports:

- `@supabase/supabase-js@2.117.2` — MIT License, Copyright (c) 2020 Supabase.

Third-party products and services may have their own terms, privacy policies and
licenses. Installing FinanceCanvas does not grant rights in third-party names,
trademarks, services or software beyond those provided by their respective
owners.

The FinanceCanvas project itself is licensed under Apache-2.0; see `LICENSE`.

Development-only regression dependencies: `@electric-sql/pglite` 0.3.14 and TypeScript 5.9.3, both Apache-2.0. Versions/integrity are pinned in package-lock.json; these tools do not connect to user databases or ship as runtime financial services.
