alter table public.account_balances
 add column if not exists updated_at timestamptz not null default now(),
 add column if not exists deleted_at timestamptz null;

alter table public.account_balances drop constraint if exists account_balances_account_id_balance_date_balance_type_key;
drop index if exists public.account_balances_active_unique;
create unique index account_balances_active_unique on public.account_balances(account_id,balance_date,balance_type) where deleted_at is null;

drop trigger if exists account_balances_set_updated_at on public.account_balances;
create trigger account_balances_set_updated_at before update on public.account_balances
for each row execute function public.set_updated_at();

revoke all on table public.account_balances from anon, authenticated;
