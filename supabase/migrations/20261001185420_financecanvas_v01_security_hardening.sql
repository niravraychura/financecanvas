create schema if not exists extensions;
alter function public.set_updated_at() set search_path = pg_catalog;
alter extension pg_trgm set schema extensions;
revoke execute on function public.rls_auto_enable() from public, anon, authenticated;
revoke execute on function public.set_updated_at() from anon, authenticated;
