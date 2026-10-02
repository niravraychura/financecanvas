-- Connector-native bootstrap for BYO Supabase projects.
-- This schema is intentionally not exposed to anon/authenticated clients.

create schema if not exists financecanvas_private;
revoke all on schema financecanvas_private from public;
revoke all on schema financecanvas_private from anon, authenticated;

create or replace function financecanvas_private.connector_status()
returns jsonb
language sql
security invoker
set search_path = pg_catalog, public, financecanvas_private
as $$
  select jsonb_build_object(
    'schema_installed', to_regclass('public.financecanvas_schema') is not null,
    'schema_version', (select schema_version from public.financecanvas_schema where singleton=true),
    'workspace_count', (select count(*) from public.workspaces),
    'initialized', exists(select 1 from public.workspaces where initialized=true),
    'source_document_persistence',
      coalesce((select source_document_persistence from public.financecanvas_compliance_settings where singleton=true), false),
    'production_ready',
      coalesce((select production_ready from public.financecanvas_compliance_settings where singleton=true), false)
  );
$$;

revoke all on function financecanvas_private.connector_status() from public, anon, authenticated;

create or replace function financecanvas_private.initialize_workspace(
  p_workspace_name text,
  p_base_currency text,
  p_first_profile_name text
)
returns jsonb
language plpgsql
security invoker
set search_path = pg_catalog, public, financecanvas_private
as $$
declare
  v_workspace public.workspaces%rowtype;
  v_profile public.profiles%rowtype;
  v_workspace_name text := btrim(coalesce(p_workspace_name,''));
  v_profile_name text := btrim(coalesce(p_first_profile_name,''));
  v_currency text := upper(btrim(coalesce(p_base_currency,'')));
  v_created_workspace boolean := false;
  v_created_profile boolean := false;
  v_make_default boolean := false;
begin
  if v_workspace_name = '' or char_length(v_workspace_name) > 200 then
    raise exception 'workspace name must be 1-200 characters';
  end if;
  if v_profile_name = '' or char_length(v_profile_name) > 200 then
    raise exception 'profile name must be 1-200 characters';
  end if;
  if v_currency !~ '^[A-Z]{3}$' then
    raise exception 'base currency must be a 3-letter ISO-style currency code';
  end if;

  select *
    into v_workspace
    from public.workspaces
   where lower(name) = lower(v_workspace_name)
   order by created_at
   limit 1;

  if not found then
    select not exists(select 1 from public.workspaces where is_default=true)
      into v_make_default;

    insert into public.workspaces(name,base_currency,is_default,initialized)
    values(v_workspace_name,v_currency,v_make_default,true)
    returning * into v_workspace;

    v_created_workspace := true;
  elsif v_workspace.base_currency <> v_currency then
    raise exception 'workspace "%" already exists with base currency %', v_workspace.name, v_workspace.base_currency;
  end if;

  select *
    into v_profile
    from public.profiles
   where workspace_id=v_workspace.id
     and deleted_at is null
     and lower(display_name)=lower(v_profile_name)
   order by created_at
   limit 1;

  if not found then
    insert into public.profiles(workspace_id,display_name,relationship,is_household)
    values(v_workspace.id,v_profile_name,'self',false)
    returning * into v_profile;

    v_created_profile := true;
  end if;

  insert into public.audit_log(
    workspace_id,actor_type,action,target_table,target_id,after_snapshot,metadata
  ) values (
    v_workspace.id,
    'supabase_connector',
    'connector_initialize_workspace',
    'workspaces',
    v_workspace.id,
    jsonb_build_object(
      'workspace_id',v_workspace.id,
      'workspace_name',v_workspace.name,
      'base_currency',v_workspace.base_currency,
      'profile_id',v_profile.id,
      'profile_name',v_profile.display_name
    ),
    jsonb_build_object(
      'connector_mode',true,
      'workspace_created',v_created_workspace,
      'profile_created',v_created_profile,
      'data_minimized',true
    )
  );

  return jsonb_build_object(
    'workspace',jsonb_build_object(
      'id',v_workspace.id,
      'name',v_workspace.name,
      'base_currency',v_workspace.base_currency,
      'is_default',v_workspace.is_default,
      'initialized',v_workspace.initialized
    ),
    'profile',jsonb_build_object(
      'id',v_profile.id,
      'display_name',v_profile.display_name,
      'relationship',v_profile.relationship
    ),
    'workspace_created',v_created_workspace,
    'profile_created',v_created_profile,
    'access_mode','supabase_connector'
  );
end;
$$;

revoke all on function financecanvas_private.initialize_workspace(text,text,text)
from public, anon, authenticated;

comment on schema financecanvas_private is
'FinanceCanvas owner-connector helpers. Not exposed to normal anon/authenticated runtime clients.';

comment on function financecanvas_private.connector_status() is
'Read FinanceCanvas installation/initialization status through an authorized Supabase owner connector.';

comment on function financecanvas_private.initialize_workspace(text,text,text) is
'Idempotently initialize a FinanceCanvas workspace/profile through an authorized Supabase owner connector.';
