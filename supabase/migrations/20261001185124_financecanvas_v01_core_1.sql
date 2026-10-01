-- Applied to FinanceCanvas Supabase as financecanvas_v01_core_1.
create extension if not exists pgcrypto;
create extension if not exists pg_trgm;

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end;
$$;

create table if not exists public.workspaces (
 id uuid primary key default gen_random_uuid(), name text not null,
 base_currency text not null default 'INR' check (char_length(base_currency)=3),
 is_default boolean not null default false, initialized boolean not null default true,
 created_by uuid null references auth.users(id) on delete set null,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create unique index if not exists one_default_workspace on public.workspaces ((is_default)) where is_default=true;

create table if not exists public.workspace_members (
 workspace_id uuid not null references public.workspaces(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 role text not null default 'owner' check (role in ('owner','manager','editor','viewer','advisor')),
 created_at timestamptz not null default now(), primary key(workspace_id,user_id));

create table if not exists public.profiles (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete cascade,
 display_name text not null, relationship text null, is_household boolean not null default false, notes text null,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz null);
create index if not exists profiles_workspace_idx on public.profiles(workspace_id);

create table if not exists public.institutions (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete cascade,
 name text not null, institution_type text null, country_code text null,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz null);

create table if not exists public.accounts (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete cascade,
 institution_id uuid null references public.institutions(id) on delete set null, name text not null,
 account_type text not null check(account_type in ('bank','credit_card','wallet','cash','brokerage','loan','other')),
 currency text not null default 'INR' check(char_length(currency)=3),
 identifier_last4 text null check(identifier_last4 is null or char_length(identifier_last4)<=8),
 current_balance numeric(20,4) null, balance_as_of date null, metadata jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz null);
create index if not exists accounts_workspace_idx on public.accounts(workspace_id);

create table if not exists public.account_owners (
 account_id uuid not null references public.accounts(id) on delete cascade,
 profile_id uuid not null references public.profiles(id) on delete cascade,
 ownership_percent numeric(7,4) null check(ownership_percent is null or ownership_percent between 0 and 100),
 is_primary boolean not null default false, primary key(account_id,profile_id));

create table if not exists public.imports (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete cascade,
 profile_id uuid null references public.profiles(id) on delete set null, account_id uuid null references public.accounts(id) on delete set null,
 source_type text not null, original_filename text null, source_hash text null, statement_start date null, statement_end date null,
 status text not null default 'previewed' check(status in ('previewed','committed','cancelled','failed')),
 record_count integer not null default 0 check(record_count>=0),
 reconciliation_status text null check(reconciliation_status is null or reconciliation_status in ('not_applicable','passed','failed','unverified')),
 reconciliation_difference numeric(20,4) null, metadata jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now(), committed_at timestamptz null);
create unique index if not exists committed_import_hash_unique on public.imports(workspace_id,source_hash) where source_hash is not null and status='committed';

create table if not exists public.transactions (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete cascade,
 profile_id uuid null references public.profiles(id) on delete set null, account_id uuid not null references public.accounts(id) on delete cascade,
 import_id uuid null references public.imports(id) on delete set null, posted_date date not null, transaction_date date null,
 amount numeric(20,4) not null check(amount>=0), currency text not null default 'INR' check(char_length(currency)=3),
 direction text not null check(direction in ('debit','credit','transfer')),
 raw_description text null, merchant_normalized text null, transaction_reference text null, category text null, subcategory text null,
 purpose text null check(purpose is null or purpose in ('personal','business','shared')),
 confidence numeric(6,5) null check(confidence is null or confidence between 0 and 1),
 confirmation_status text not null default 'confirmed' check(confirmation_status in ('confirmed','needs_confirmation','rejected','estimated')),
 raw_values jsonb not null default '{}'::jsonb, normalized_values jsonb not null default '{}'::jsonb,
 base_fingerprint text not null, fingerprint text not null,
 duplicate_of_transaction_id uuid null references public.transactions(id) on delete set null,
 duplicate_override_reason text null, duplicate_override_at timestamptz null,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz null);
create unique index if not exists transactions_fingerprint_active_unique on public.transactions(workspace_id,fingerprint) where deleted_at is null;
create index if not exists transactions_lookup_idx on public.transactions(workspace_id,account_id,posted_date,amount);
create index if not exists transactions_merchant_trgm_idx on public.transactions using gin (merchant_normalized gin_trgm_ops);

create table if not exists public.transaction_splits (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete cascade,
 transaction_id uuid not null references public.transactions(id) on delete cascade, profile_id uuid null references public.profiles(id) on delete set null,
 amount numeric(20,4) not null check(amount>=0), category text null, subcategory text null,
 purpose text null check(purpose is null or purpose in ('personal','business','shared')), note text null, created_at timestamptz not null default now());

create table if not exists public.merchant_aliases (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete cascade,
 raw_pattern text not null, normalized_merchant text not null, category text null, subcategory text null,
 purpose text null check(purpose is null or purpose in ('personal','business','shared')),
 confirmed_by_user boolean not null default true, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(workspace_id,raw_pattern));

create table if not exists public.loans (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete cascade,
 profile_id uuid null references public.profiles(id) on delete set null, institution_id uuid null references public.institutions(id) on delete set null,
 name text not null, loan_type text null, currency text not null default 'INR',
 principal_original numeric(20,4) null, outstanding_principal numeric(20,4) null, interest_rate_annual numeric(10,6) null, emi_amount numeric(20,4) null,
 start_date date null, end_date date null, identifier_last4 text null, metadata jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz null);
