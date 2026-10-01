alter table public.transactions add column if not exists balance_after numeric(20,4) null;
alter table public.accounts add column if not exists annual_fee_next_date date null;

create table if not exists public.income_sources (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete cascade,
 profile_id uuid null references public.profiles(id) on delete set null, account_id uuid null references public.accounts(id) on delete set null,
 name text not null, income_type text not null, currency text not null default 'INR' check(char_length(currency)=3),
 expected_amount numeric(20,4) null, frequency text null, next_expected_date date null,
 status text not null default 'active' check(status in ('active','paused','ended','unknown')),
 metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(), deleted_at timestamptz null);

create table if not exists public.insurance_premiums (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete cascade,
 policy_id uuid not null references public.insurance_policies(id) on delete cascade,
 transaction_id uuid null references public.transactions(id) on delete set null, premium_date date not null,
 amount numeric(20,4) not null check(amount>=0), currency text not null default 'INR' check(char_length(currency)=3),
 premium_type text null, created_at timestamptz not null default now());

create table if not exists public.financial_preferences (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete cascade,
 profile_id uuid null references public.profiles(id) on delete set null, preference_key text not null,
 preference_group text not null default 'general', preference_value jsonb not null,
 source text not null default 'user_confirmed' check(source in ('user_confirmed','imported','derived')),
 confidence numeric(6,5) null check(confidence is null or confidence between 0 and 1), confirmed boolean not null default true,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz null);
create unique index if not exists financial_preferences_unique_active
 on public.financial_preferences(workspace_id,coalesce(profile_id,'00000000-0000-0000-0000-000000000000'::uuid),preference_key)
 where deleted_at is null;

create table if not exists public.recommendations (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete cascade,
 profile_id uuid null references public.profiles(id) on delete set null, recommendation_type text not null,
 title text not null, summary text not null, rationale text null, evidence jsonb not null default '{}'::jsonb,
 assumptions jsonb not null default '{}'::jsonb, confidence numeric(6,5) null check(confidence is null or confidence between 0 and 1),
 status text not null default 'active' check(status in ('active','accepted','rejected','dismissed','completed','expired')),
 generated_at timestamptz not null default now(), valid_until timestamptz null,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz null);

create table if not exists public.investment_allocation_targets (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete cascade,
 profile_id uuid null references public.profiles(id) on delete set null,
 dimension text not null check(dimension in ('investment','investment_type','symbol')),
 investment_id uuid null references public.investments(id) on delete cascade, dimension_value text null,
 currency text not null default 'INR' check(char_length(currency)=3),
 target_percent numeric(7,4) not null check(target_percent between 0 and 100),
 tolerance_percent numeric(7,4) not null default 5 check(tolerance_percent between 0 and 100),
 active boolean not null default true, created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(), deleted_at timestamptz null,
 check((dimension='investment' and investment_id is not null) or (dimension in ('investment_type','symbol') and dimension_value is not null)));

do $$
declare t text;
begin
 foreach t in array array['income_sources','financial_preferences','recommendations','investment_allocation_targets']
 loop
  execute format('drop trigger if exists %I_set_updated_at on public.%I',t,t);
  execute format('create trigger %I_set_updated_at before update on public.%I for each row execute function public.set_updated_at()',t,t);
 end loop;
 foreach t in array array['income_sources','insurance_premiums','financial_preferences','recommendations','investment_allocation_targets']
 loop
  execute format('alter table public.%I enable row level security',t);
  execute format('revoke all on table public.%I from anon, authenticated',t);
 end loop;
end $$;

create index if not exists income_sources_workspace_idx on public.income_sources(workspace_id,status,next_expected_date);
create index if not exists insurance_premiums_workspace_idx on public.insurance_premiums(workspace_id,policy_id,premium_date desc);
create index if not exists recommendations_workspace_idx on public.recommendations(workspace_id,status,generated_at desc);
create index if not exists allocation_targets_workspace_idx on public.investment_allocation_targets(workspace_id,active,profile_id);
revoke all on table public.transactions from anon, authenticated;
revoke all on table public.accounts from anon, authenticated;
