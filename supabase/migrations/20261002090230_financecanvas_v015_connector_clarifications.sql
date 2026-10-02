-- Approved owner-connector adapter. No public client access or source-file storage.
create or replace function financecanvas_private.preview_transaction_clarifications(
  p_workspace_id uuid,
  p_rows jsonb,
  p_aliases jsonb default '[]'::jsonb,
  p_memories jsonb default '[]'::jsonb
)
returns jsonb language plpgsql security invoker
set search_path = pg_catalog, public, financecanvas_private
as $$
declare
  r jsonb;
  v public.transactions%rowtype;
  results jsonb := '[]'::jsonb;
begin
  if p_workspace_id is null or not exists(select 1 from public.workspaces where id=p_workspace_id) then
    raise exception 'WORKSPACE_NOT_FOUND';
  end if;
  if p_rows is null or p_aliases is null or p_memories is null
     or jsonb_typeof(p_rows)<>'array' or jsonb_typeof(p_aliases)<>'array'
     or jsonb_typeof(p_memories)<>'array' then
    raise exception 'rows, aliases and memories must be arrays';
  end if;
  if jsonb_array_length(p_rows)>1000 then raise exception 'BATCH_TOO_LARGE'; end if;
  perform financecanvas_private.assert_import_payload_safe(
    jsonb_build_object('rows',p_rows,'aliases',p_aliases,'memories',p_memories));
  if exists(select 1 from jsonb_array_elements(p_rows) x
            group by x->>'transaction_id' having count(*)>1) then
    raise exception 'DUPLICATE_TRANSACTION_ID';
  end if;
  for r in select value from jsonb_array_elements(p_rows) loop
    select * into v from public.transactions
    where id=(r->>'transaction_id')::uuid and workspace_id=p_workspace_id and deleted_at is null;
    if not found then raise exception 'CROSS_WORKSPACE_REFERENCE: transaction unavailable'; end if;
    if nullif(btrim(r->>'context_note'),'') is null then raise exception 'context_note is required'; end if;
    if coalesce(r->>'scope','transaction') not in ('transaction','month','date_range','global') then
      raise exception 'invalid clarification scope';
    end if;
    if r ? 'expected_updated_at' and (r->>'expected_updated_at')::timestamptz is distinct from v.updated_at then
      raise exception 'STALE_PREVIEW: transaction changed; preview again';
    end if;
    results := results || jsonb_build_array(jsonb_build_object(
      'transaction_id',v.id,'expected_updated_at',v.updated_at,
      'existing',jsonb_build_object('posted_date',v.posted_date,'amount',v.amount,'direction',v.direction,
        'merchant_normalized',v.merchant_normalized,'category',v.category,'subcategory',v.subcategory,'purpose',v.purpose),
      'proposed',r - 'expected_updated_at'));
  end loop;
  return jsonb_build_object('results',results,'aliases',p_aliases,'memories',p_memories,'final_confirmation_required',true);
end;
$$;
revoke all on function financecanvas_private.preview_transaction_clarifications(uuid,jsonb,jsonb,jsonb)
from public, anon, authenticated;

create or replace function financecanvas_private.commit_transaction_clarifications(
  p_workspace_id uuid,
  p_rows jsonb,
  p_aliases jsonb default '[]'::jsonb,
  p_memories jsonb default '[]'::jsonb,
  p_final_confirmation boolean default false
)
returns jsonb language plpgsql security invoker
set search_path = pg_catalog, public, financecanvas_private
as $$
declare v_preview jsonb;
begin
  if p_final_confirmation is distinct from true then raise exception 'FINAL_CONFIRMATION_REQUIRED'; end if;
  -- Lock the matching transactions before revalidation and atomic mutation.
  perform 1 from public.transactions where workspace_id=p_workspace_id
    and id in(select (x->>'transaction_id')::uuid from jsonb_array_elements(p_rows) x)
    order by id for update;
  v_preview := financecanvas_private.preview_transaction_clarifications(p_workspace_id,p_rows,p_aliases,p_memories);
  return public.financecanvas_commit_transaction_clarifications(p_workspace_id,p_rows,p_aliases,p_memories)
    || jsonb_build_object('atomic_commit',true,'single_source_of_truth',true);
end;
$$;
revoke all on function financecanvas_private.commit_transaction_clarifications(uuid,jsonb,jsonb,jsonb,boolean)
from public, anon, authenticated;

create or replace function financecanvas_private.apply_transaction_aliases(p_workspace_id uuid,p_rows jsonb)
returns jsonb language plpgsql security invoker
set search_path = pg_catalog, public, financecanvas_private
as $$
declare r jsonb; a public.merchant_aliases%rowtype; result jsonb := '[]'::jsonb;
begin
  if p_workspace_id is null or not exists(select 1 from public.workspaces where id=p_workspace_id) then
    raise exception 'WORKSPACE_NOT_FOUND';
  end if;
  if p_rows is null or jsonb_typeof(p_rows)<>'array' then raise exception 'rows must be an array'; end if;
  perform financecanvas_private.assert_import_payload_safe(p_rows);
  for r in select value from jsonb_array_elements(p_rows) loop
    select * into a from public.merchant_aliases
    where workspace_id=p_workspace_id and deleted_at is null and confirmed_by_user
      and nullif(btrim(raw_pattern),'') is not null
      and strpos(financecanvas_private.norm_text(coalesce(r->>'raw_description','')||' '||coalesce(r->>'merchant_normalized','')),
                 financecanvas_private.norm_text(raw_pattern))>0
    order by length(raw_pattern) desc, raw_pattern limit 1;
    if found then
      r := r || jsonb_build_object('merchant_normalized',a.normalized_merchant);
      if nullif(btrim(r->>'category'),'') is null and a.category is not null then r := r || jsonb_build_object('category',a.category); end if;
      if nullif(btrim(r->>'subcategory'),'') is null and a.subcategory is not null then r := r || jsonb_build_object('subcategory',a.subcategory); end if;
      if nullif(btrim(r->>'purpose'),'') is null and a.purpose is not null then r := r || jsonb_build_object('purpose',a.purpose); end if;
      r := r || jsonb_build_object('normalized_values',coalesce(r->'normalized_values','{}'::jsonb) ||
        jsonb_build_object('financecanvas_alias',jsonb_build_object('matched_pattern',a.raw_pattern,'confirmed_by_user',true)));
    end if;
    result := result || jsonb_build_array(r);
  end loop;
  return result;
end;
$$;
revoke all on function financecanvas_private.apply_transaction_aliases(uuid,jsonb)
from public, anon, authenticated;
