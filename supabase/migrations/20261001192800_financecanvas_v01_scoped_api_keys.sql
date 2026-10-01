alter table public.financecanvas_api_keys
 add column if not exists workspace_id uuid null references public.workspaces(id) on delete cascade,
 add column if not exists scopes text[] not null default array['read','write','watch','export']::text[];

alter table public.financecanvas_api_keys drop constraint if exists financecanvas_api_keys_scopes_check;
alter table public.financecanvas_api_keys add constraint financecanvas_api_keys_scopes_check
check(scopes <@ array['read','write','watch','export','admin']::text[] and cardinality(scopes) > 0);

create index if not exists financecanvas_api_keys_workspace_idx
on public.financecanvas_api_keys(workspace_id) where active=true;

revoke all on table public.financecanvas_api_keys from anon, authenticated;
