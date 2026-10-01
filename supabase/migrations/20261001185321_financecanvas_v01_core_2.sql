-- Applied to FinanceCanvas Supabase as financecanvas_v01_core_2.
create table if not exists public.loan_payments (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete cascade,
 loan_id uuid not null references public.loans(id) on delete cascade, transaction_id uuid null references public.transactions(id) on delete set null,
 payment_date date not null, amount numeric(20,4) not null check(amount>=0),
 principal_component numeric(20,4) null, interest_component numeric(20,4) null, other_component numeric(20,4) null,
 created_at timestamptz not null default now());

create table if not exists public.insurance_policies (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete cascade,
 profile_id uuid null references public.profiles(id) on delete set null, institution_id uuid null references public.institutions(id) on delete set null,
 policy_type text not null, policy_name text not null, policy_identifier_last4 text null, currency text not null default 'INR',
 premium_amount numeric(20,4) null, premium_frequency text null, coverage_amount numeric(20,4) null,
 start_date date null, end_date date null, renewal_date date null, metadata jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz null);

create table if not exists public.assets (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete cascade,
 profile_id uuid null references public.profiles(id) on delete set null, name text not null, asset_type text null,
 currency text not null default 'INR', value numeric(20,4) null, value_as_of date null, metadata jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz null);

create table if not exists public.liabilities (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete cascade,
 profile_id uuid null references public.profiles(id) on delete set null, name text not null, liability_type text null,
 currency text not null default 'INR', outstanding_amount numeric(20,4) null, amount_as_of date null, metadata jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz null);

create table if not exists public.investments (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete cascade,
 profile_id uuid null references public.profiles(id) on delete set null, account_id uuid null references public.accounts(id) on delete set null,
 name text not null, investment_type text null, symbol text null, currency text not null default 'INR',
 quantity numeric(28,10) null, cost_basis numeric(20,4) null, current_value numeric(20,4) null, value_as_of date null,
 metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz null);

create table if not exists public.investment_transactions (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete cascade,
 investment_id uuid not null references public.investments(id) on delete cascade, transaction_id uuid null references public.transactions(id) on delete set null,
 event_type text not null, event_date date not null, quantity numeric(28,10) null, price numeric(20,6) null,
 amount numeric(20,4) null, fees numeric(20,4) null, created_at timestamptz not null default now());

create table if not exists public.subscriptions (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete cascade,
 profile_id uuid null references public.profiles(id) on delete set null, merchant_name text not null, amount numeric(20,4) null,
 currency text not null default 'INR', frequency text null, next_expected_date date null,
 status text not null default 'active' check(status in ('active','paused','cancelled','unknown')),
 metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz null);

create table if not exists public.goals (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete cascade,
 profile_id uuid null references public.profiles(id) on delete set null, name text not null, goal_type text null,
 currency text not null default 'INR', target_amount numeric(20,4) null, current_amount numeric(20,4) null, target_date date null, priority text null,
 status text not null default 'active' check(status in ('active','paused','completed','cancelled')),
 metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz null);

create table if not exists public.correction_memory (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete cascade,
 correction_type text not null, source_value text not null, normalized_value text null, extra jsonb not null default '{}'::jsonb,
 accepted boolean not null, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(workspace_id,correction_type,source_value));
