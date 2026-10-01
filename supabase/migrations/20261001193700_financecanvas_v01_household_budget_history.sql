create table if not exists public.households (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete cascade,
 name text not null, notes text null, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz null);

create table if not exists public.household_members (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete cascade,
 household_id uuid not null references public.households(id) on delete cascade, profile_id uuid not null references public.profiles(id) on delete cascade,
 role text null, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz null,
 unique(household_id,profile_id));

create table if not exists public.profile_relationships (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete cascade,
 profile_id uuid not null references public.profiles(id) on delete cascade, related_profile_id uuid not null references public.profiles(id) on delete cascade,
 relationship_type text not null, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz null,
 check(profile_id <> related_profile_id));

create table if not exists public.asset_owners (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete cascade,
 asset_id uuid not null references public.assets(id) on delete cascade, profile_id uuid not null references public.profiles(id) on delete cascade,
 ownership_percent numeric(7,4) null check(ownership_percent is null or ownership_percent between 0 and 100),
 is_primary boolean not null default false, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz null,
 unique(asset_id,profile_id));

create table if not exists public.liability_owners (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete cascade,
 liability_id uuid not null references public.liabilities(id) on delete cascade, profile_id uuid not null references public.profiles(id) on delete cascade,
 responsibility_percent numeric(7,4) null check(responsibility_percent is null or responsibility_percent between 0 and 100),
 is_primary boolean not null default false, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz null,
 unique(liability_id,profile_id));

create table if not exists public.loan_borrowers (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete cascade,
 loan_id uuid not null references public.loans(id) on delete cascade, profile_id uuid not null references public.profiles(id) on delete cascade,
 borrower_role text not null default 'borrower' check(borrower_role in ('borrower','co_borrower','guarantor')),
 responsibility_percent numeric(7,4) null check(responsibility_percent is null or responsibility_percent between 0 and 100),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz null,
 unique(loan_id,profile_id,borrower_role));

create table if not exists public.account_balances (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete cascade,
 account_id uuid not null references public.accounts(id) on delete cascade, import_id uuid null references public.imports(id) on delete set null,
 balance_date date not null, balance numeric(20,4) not null, currency text not null default 'INR' check(char_length(currency)=3),
 balance_type text not null default 'closing' check(balance_type in ('opening','closing','available','current','statement')),
 confidence numeric(6,5) null check(confidence is null or confidence between 0 and 1), confirmed boolean not null default true,
 created_at timestamptz not null default now(), unique(account_id,balance_date,balance_type));

create table if not exists public.credit_card_statements (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete cascade,
 account_id uuid not null references public.accounts(id) on delete cascade, import_id uuid null references public.imports(id) on delete set null,
 statement_start date null, statement_end date not null, due_date date null, currency text not null default 'INR' check(char_length(currency)=3),
 statement_balance numeric(20,4) null, minimum_due numeric(20,4) null, total_due numeric(20,4) null,
 fees_total numeric(20,4) null, interest_total numeric(20,4) null,
 payment_status text not null default 'unknown' check(payment_status in ('unknown','unpaid','partial','paid')),
 metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 deleted_at timestamptz null, unique(account_id,statement_end));

create table if not exists public.budgets (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete cascade,
 profile_id uuid null references public.profiles(id) on delete set null, name text not null, category text null, subcategory text null,
 currency text not null default 'INR' check(char_length(currency)=3), amount numeric(20,4) not null check(amount>=0),
 period text not null check(period in ('weekly','monthly','quarterly','annual','custom')), start_date date not null, end_date date null,
 status text not null default 'active' check(status in ('active','paused','completed','cancelled')),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz null);

create table if not exists public.recurring_items (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete cascade,
 profile_id uuid null references public.profiles(id) on delete set null, account_id uuid null references public.accounts(id) on delete set null,
 item_type text not null check(item_type in ('income','expense','transfer','subscription','loan_payment','insurance_premium','investment')),
 name text not null, merchant_name text null, amount numeric(20,4) null, currency text not null default 'INR' check(char_length(currency)=3),
 frequency text not null, category text null, subcategory text null, next_expected_date date null,
 expected_day integer null check(expected_day is null or expected_day between 1 and 31), enabled boolean not null default true,
 metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 deleted_at timestamptz null);

create table if not exists public.financial_snapshots (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete cascade,
 profile_id uuid null references public.profiles(id) on delete set null, snapshot_date date not null,
 base_currency text not null default 'INR' check(char_length(base_currency)=3), assets_total numeric(20,4) null,
 liabilities_total numeric(20,4) null, net_worth numeric(20,4) null, cash_total numeric(20,4) null, investments_total numeric(20,4) null,
 metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 deleted_at timestamptz null, unique(workspace_id,profile_id,snapshot_date));

do $$
declare t text;
begin
 foreach t in array array['households','household_members','profile_relationships','asset_owners','liability_owners','loan_borrowers','credit_card_statements','budgets','recurring_items','financial_snapshots']
 loop execute format('create trigger %I_set_updated_at before update on public.%I for each row execute function public.set_updated_at()',t,t); end loop;
 foreach t in array array['households','household_members','profile_relationships','asset_owners','liability_owners','loan_borrowers','account_balances','credit_card_statements','budgets','recurring_items','financial_snapshots']
 loop execute format('alter table public.%I enable row level security',t); execute format('revoke all on table public.%I from anon, authenticated',t); end loop;
end $$;

create index if not exists households_workspace_idx on public.households(workspace_id);
create index if not exists household_members_workspace_idx on public.household_members(workspace_id,household_id);
create index if not exists profile_relationships_workspace_idx on public.profile_relationships(workspace_id,profile_id);
create index if not exists asset_owners_workspace_idx on public.asset_owners(workspace_id,asset_id);
create index if not exists liability_owners_workspace_idx on public.liability_owners(workspace_id,liability_id);
create index if not exists loan_borrowers_workspace_idx on public.loan_borrowers(workspace_id,loan_id);
create index if not exists account_balances_workspace_idx on public.account_balances(workspace_id,account_id,balance_date desc);
create index if not exists credit_card_statements_workspace_idx on public.credit_card_statements(workspace_id,account_id,statement_end desc);
create index if not exists budgets_workspace_idx on public.budgets(workspace_id,status,start_date);
create index if not exists recurring_items_workspace_idx on public.recurring_items(workspace_id,enabled,next_expected_date);
create index if not exists financial_snapshots_workspace_idx on public.financial_snapshots(workspace_id,snapshot_date desc);
