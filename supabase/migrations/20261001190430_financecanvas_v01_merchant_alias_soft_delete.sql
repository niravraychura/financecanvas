alter table public.merchant_aliases add column if not exists deleted_at timestamptz null;
revoke all on table public.merchant_aliases from anon, authenticated;
