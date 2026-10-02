-- Connector-native structured document imports for non-transaction finance data.
-- Supports insurance, loans, investments/holdings, income, assets, liabilities,
-- subscriptions, goals, recurring items and their supported child events.

create table if not exists public.import_entities (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  import_id uuid not null references public.imports(id) on delete cascade,
  entity_type text not null check(entity_type in (
    'insurance_policy','loan','investment','income_source','asset',
    'liability','subscription','goal','recurring_item',
    'insurance_premium','loan_payment','investment_transaction'
  )),
  entity_id uuid not null,
  parent_entity_id uuid null,
  client_id text null,
  action text not null check(action in ('created','updated','reused','skipped_duplicate','added_duplicate')),
  reason text null,
  created_at timestamptz not null default now()
);

alter table public.import_entities enable row level security;
revoke all on table public.import_entities from anon, authenticated;

create index if not exists import_entities_import_idx
  on public.import_entities(workspace_id,import_id,entity_type);

create index if not exists import_entities_entity_idx
  on public.import_entities(workspace_id,entity_type,entity_id);

create or replace function financecanvas_private.jsonb_field_differences(
  p_existing jsonb,
  p_incoming jsonb,
  p_fields text[]
)
returns jsonb
language plpgsql
immutable
security invoker
set search_path = pg_catalog
as $$
declare
  v_key text;
  v_diff jsonb := '{}'::jsonb;
begin
  foreach v_key in array p_fields
  loop
    if p_incoming ? v_key
       and (p_existing->v_key) is distinct from (p_incoming->v_key) then
      v_diff := v_diff || jsonb_build_object(
        v_key,
        jsonb_build_object(
          'existing',p_existing->v_key,
          'incoming',p_incoming->v_key
        )
      );
    end if;
  end loop;
  return v_diff;
end;
$$;

revoke all on function financecanvas_private.jsonb_field_differences(jsonb,jsonb,text[])
from public, anon, authenticated;

create or replace function financecanvas_private.ensure_institution(
  p_workspace_id uuid,
  p_name text,
  p_institution_type text default 'financial_institution'
)
returns uuid
language plpgsql
security invoker
set search_path = pg_catalog, public, financecanvas_private
as $$
declare
  v_id uuid;
  v_name text := btrim(coalesce(p_name,''));
begin
  if v_name='' then return null; end if;

  select id into v_id
  from public.institutions
  where workspace_id=p_workspace_id
    and deleted_at is null
    and lower(name)=lower(v_name)
  order by created_at
  limit 1;

  if v_id is null then
    insert into public.institutions(workspace_id,name,institution_type)
    values(p_workspace_id,v_name,coalesce(nullif(btrim(p_institution_type),''),'financial_institution'))
    returning id into v_id;
  end if;

  return v_id;
end;
$$;

revoke all on function financecanvas_private.ensure_institution(uuid,text,text)
from public, anon, authenticated;

create or replace function financecanvas_private.preview_entity_record(
  p_workspace_id uuid,
  p_profile_id uuid,
  p_record jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = pg_catalog, public, financecanvas_private, extensions
as $$
declare
  v_type text := lower(btrim(coalesce(p_record->>'entity_type','')));
  d jsonb := coalesce(p_record->'data','{}'::jsonb);
  v_client text := coalesce(nullif(p_record->>'client_id',''),'record');
  v_existing jsonb;
  v_existing_id uuid;
  v_diff jsonb := '{}'::jsonb;
  v_result jsonb;
  v_children jsonb := '[]'::jsonb;
  ch jsonb;
  cd jsonb;
  v_child_client text;
  v_child_type text;
  v_child_existing_id uuid;
  v_institution_name text := nullif(btrim(d->>'institution_name'),'');
  v_account_id uuid := nullif(d->>'account_id','')::uuid;
begin
  perform financecanvas_private.assert_import_payload_safe(p_record);

  if v_type not in (
    'insurance_policy','loan','investment','income_source','asset',
    'liability','subscription','goal','recurring_item'
  ) then
    return jsonb_build_object(
      'client_id',v_client,'entity_type',v_type,'status','invalid',
      'message','Unsupported entity_type'
    );
  end if;

  if p_profile_id is not null and not exists(
    select 1 from public.profiles
    where id=p_profile_id and workspace_id=p_workspace_id and deleted_at is null
  ) then
    return jsonb_build_object(
      'client_id',v_client,'entity_type',v_type,'status','invalid',
      'message','Profile is not in workspace'
    );
  end if;

  if v_account_id is not null and not exists(
    select 1 from public.accounts
    where id=v_account_id and workspace_id=p_workspace_id and deleted_at is null
  ) then
    return jsonb_build_object(
      'client_id',v_client,'entity_type',v_type,'status','invalid',
      'message','Account is not in workspace'
    );
  end if;

  if v_type='insurance_policy' then
    if nullif(btrim(d->>'policy_name'),'') is null
       or nullif(btrim(d->>'policy_type'),'') is null then
      return jsonb_build_object('client_id',v_client,'entity_type',v_type,'status','invalid','message','policy_name and policy_type are required');
    end if;

    select p.id,
      jsonb_build_object(
        'policy_name',p.policy_name,'policy_type',p.policy_type,
        'policy_identifier_last4',p.policy_identifier_last4,'currency',p.currency,
        'premium_amount',p.premium_amount,'premium_frequency',p.premium_frequency,
        'coverage_amount',p.coverage_amount,'start_date',p.start_date,
        'end_date',p.end_date,'renewal_date',p.renewal_date,
        'institution_name',i.name
      )
    into v_existing_id,v_existing
    from public.insurance_policies p
    left join public.institutions i on i.id=p.institution_id
    where p.workspace_id=p_workspace_id
      and p.deleted_at is null
      and (
        (nullif(d->>'policy_identifier_last4','') is not null
         and p.policy_identifier_last4=d->>'policy_identifier_last4')
        or
        (nullif(d->>'policy_identifier_last4','') is null
         and lower(p.policy_name)=lower(d->>'policy_name')
         and lower(p.policy_type)=lower(d->>'policy_type')
         and (v_institution_name is null or lower(coalesce(i.name,''))=lower(v_institution_name)))
      )
    order by p.created_at
    limit 1;

    if v_existing_id is not null then
      v_diff := financecanvas_private.jsonb_field_differences(
        v_existing,d,
        array['policy_name','policy_type','policy_identifier_last4','currency','premium_amount',
              'premium_frequency','coverage_amount','start_date','end_date','renewal_date','institution_name']
      );
    end if;

  elsif v_type='loan' then
    if nullif(btrim(d->>'name'),'') is null then
      return jsonb_build_object('client_id',v_client,'entity_type',v_type,'status','invalid','message','loan name is required');
    end if;

    select l.id,
      jsonb_build_object(
        'name',l.name,'loan_type',l.loan_type,'currency',l.currency,
        'principal_original',l.principal_original,'outstanding_principal',l.outstanding_principal,
        'interest_rate_annual',l.interest_rate_annual,'emi_amount',l.emi_amount,
        'start_date',l.start_date,'end_date',l.end_date,
        'identifier_last4',l.identifier_last4,'institution_name',i.name
      )
    into v_existing_id,v_existing
    from public.loans l
    left join public.institutions i on i.id=l.institution_id
    where l.workspace_id=p_workspace_id
      and l.deleted_at is null
      and (
        (nullif(d->>'identifier_last4','') is not null and l.identifier_last4=d->>'identifier_last4')
        or
        (nullif(d->>'identifier_last4','') is null
         and lower(l.name)=lower(d->>'name')
         and lower(coalesce(l.loan_type,''))=lower(coalesce(d->>'loan_type',''))
         and (v_institution_name is null or lower(coalesce(i.name,''))=lower(v_institution_name)))
      )
    order by l.created_at
    limit 1;

    if v_existing_id is not null then
      v_diff := financecanvas_private.jsonb_field_differences(
        v_existing,d,
        array['name','loan_type','currency','principal_original','outstanding_principal',
              'interest_rate_annual','emi_amount','start_date','end_date','identifier_last4','institution_name']
      );
    end if;

  elsif v_type='investment' then
    if nullif(btrim(d->>'name'),'') is null then
      return jsonb_build_object('client_id',v_client,'entity_type',v_type,'status','invalid','message','investment name is required');
    end if;

    select i.id,
      jsonb_build_object(
        'name',i.name,'investment_type',i.investment_type,'symbol',i.symbol,
        'currency',i.currency,'quantity',i.quantity,'cost_basis',i.cost_basis,
        'current_value',i.current_value,'value_as_of',i.value_as_of,'account_id',i.account_id
      )
    into v_existing_id,v_existing
    from public.investments i
    where i.workspace_id=p_workspace_id
      and i.deleted_at is null
      and (
        (nullif(d->>'symbol','') is not null
         and lower(coalesce(i.symbol,''))=lower(d->>'symbol')
         and i.account_id is not distinct from v_account_id)
        or
        (nullif(d->>'symbol','') is null
         and lower(i.name)=lower(d->>'name')
         and lower(coalesce(i.investment_type,''))=lower(coalesce(d->>'investment_type',''))
         and i.account_id is not distinct from v_account_id)
      )
    order by i.created_at
    limit 1;

    if v_existing_id is not null then
      v_diff := financecanvas_private.jsonb_field_differences(
        v_existing,d,
        array['name','investment_type','symbol','currency','quantity','cost_basis',
              'current_value','value_as_of','account_id']
      );
    end if;

  elsif v_type='income_source' then
    if nullif(btrim(d->>'name'),'') is null or nullif(btrim(d->>'income_type'),'') is null then
      return jsonb_build_object('client_id',v_client,'entity_type',v_type,'status','invalid','message','name and income_type are required');
    end if;

    select i.id,
      jsonb_build_object(
        'name',i.name,'income_type',i.income_type,'currency',i.currency,
        'expected_amount',i.expected_amount,'frequency',i.frequency,
        'next_expected_date',i.next_expected_date,'status',i.status,'account_id',i.account_id
      )
    into v_existing_id,v_existing
    from public.income_sources i
    where i.workspace_id=p_workspace_id
      and i.deleted_at is null
      and i.profile_id is not distinct from p_profile_id
      and lower(i.name)=lower(d->>'name')
      and lower(i.income_type)=lower(d->>'income_type')
    order by i.created_at
    limit 1;

    if v_existing_id is not null then
      v_diff := financecanvas_private.jsonb_field_differences(
        v_existing,d,
        array['name','income_type','currency','expected_amount','frequency','next_expected_date','status','account_id']
      );
    end if;

  elsif v_type='asset' then
    if nullif(btrim(d->>'name'),'') is null then
      return jsonb_build_object('client_id',v_client,'entity_type',v_type,'status','invalid','message','asset name is required');
    end if;

    select a.id,
      jsonb_build_object(
        'name',a.name,'asset_type',a.asset_type,'currency',a.currency,
        'value',a.value,'value_as_of',a.value_as_of
      )
    into v_existing_id,v_existing
    from public.assets a
    where a.workspace_id=p_workspace_id
      and a.deleted_at is null
      and a.profile_id is not distinct from p_profile_id
      and lower(a.name)=lower(d->>'name')
      and lower(coalesce(a.asset_type,''))=lower(coalesce(d->>'asset_type',''))
    order by a.created_at
    limit 1;

    if v_existing_id is not null then
      v_diff := financecanvas_private.jsonb_field_differences(
        v_existing,d,array['name','asset_type','currency','value','value_as_of']
      );
    end if;

  elsif v_type='liability' then
    if nullif(btrim(d->>'name'),'') is null then
      return jsonb_build_object('client_id',v_client,'entity_type',v_type,'status','invalid','message','liability name is required');
    end if;

    select l.id,
      jsonb_build_object(
        'name',l.name,'liability_type',l.liability_type,'currency',l.currency,
        'outstanding_amount',l.outstanding_amount,'amount_as_of',l.amount_as_of
      )
    into v_existing_id,v_existing
    from public.liabilities l
    where l.workspace_id=p_workspace_id
      and l.deleted_at is null
      and l.profile_id is not distinct from p_profile_id
      and lower(l.name)=lower(d->>'name')
      and lower(coalesce(l.liability_type,''))=lower(coalesce(d->>'liability_type',''))
    order by l.created_at
    limit 1;

    if v_existing_id is not null then
      v_diff := financecanvas_private.jsonb_field_differences(
        v_existing,d,array['name','liability_type','currency','outstanding_amount','amount_as_of']
      );
    end if;

  elsif v_type='subscription' then
    if nullif(btrim(d->>'merchant_name'),'') is null then
      return jsonb_build_object('client_id',v_client,'entity_type',v_type,'status','invalid','message','merchant_name is required');
    end if;

    select s.id,
      jsonb_build_object(
        'merchant_name',s.merchant_name,'amount',s.amount,'currency',s.currency,
        'frequency',s.frequency,'next_expected_date',s.next_expected_date,'status',s.status
      )
    into v_existing_id,v_existing
    from public.subscriptions s
    where s.workspace_id=p_workspace_id
      and s.deleted_at is null
      and s.profile_id is not distinct from p_profile_id
      and lower(s.merchant_name)=lower(d->>'merchant_name')
      and upper(s.currency)=upper(coalesce(nullif(d->>'currency',''),s.currency))
    order by s.created_at
    limit 1;

    if v_existing_id is not null then
      v_diff := financecanvas_private.jsonb_field_differences(
        v_existing,d,array['merchant_name','amount','currency','frequency','next_expected_date','status']
      );
    end if;

  elsif v_type='goal' then
    if nullif(btrim(d->>'name'),'') is null then
      return jsonb_build_object('client_id',v_client,'entity_type',v_type,'status','invalid','message','goal name is required');
    end if;

    select g.id,
      jsonb_build_object(
        'name',g.name,'goal_type',g.goal_type,'currency',g.currency,
        'target_amount',g.target_amount,'current_amount',g.current_amount,
        'target_date',g.target_date,'priority',g.priority,'status',g.status
      )
    into v_existing_id,v_existing
    from public.goals g
    where g.workspace_id=p_workspace_id
      and g.deleted_at is null
      and g.profile_id is not distinct from p_profile_id
      and lower(g.name)=lower(d->>'name')
      and lower(coalesce(g.goal_type,''))=lower(coalesce(d->>'goal_type',''))
    order by g.created_at
    limit 1;

    if v_existing_id is not null then
      v_diff := financecanvas_private.jsonb_field_differences(
        v_existing,d,array['name','goal_type','currency','target_amount','current_amount','target_date','priority','status']
      );
    end if;

  elsif v_type='recurring_item' then
    if nullif(btrim(d->>'name'),'') is null or nullif(btrim(d->>'item_type'),'') is null or nullif(btrim(d->>'frequency'),'') is null then
      return jsonb_build_object('client_id',v_client,'entity_type',v_type,'status','invalid','message','name, item_type and frequency are required');
    end if;

    select ri.id,
      jsonb_build_object(
        'item_type',ri.item_type,'name',ri.name,'merchant_name',ri.merchant_name,
        'amount',ri.amount,'currency',ri.currency,'frequency',ri.frequency,
        'category',ri.category,'subcategory',ri.subcategory,
        'next_expected_date',ri.next_expected_date,'expected_day',ri.expected_day,
        'enabled',ri.enabled,'account_id',ri.account_id
      )
    into v_existing_id,v_existing
    from public.recurring_items ri
    where ri.workspace_id=p_workspace_id
      and ri.deleted_at is null
      and ri.profile_id is not distinct from p_profile_id
      and lower(ri.name)=lower(d->>'name')
      and lower(ri.item_type)=lower(d->>'item_type')
    order by ri.created_at
    limit 1;

    if v_existing_id is not null then
      v_diff := financecanvas_private.jsonb_field_differences(
        v_existing,d,
        array['item_type','name','merchant_name','amount','currency','frequency',
              'category','subcategory','next_expected_date','expected_day','enabled','account_id']
      );
    end if;
  end if;

  if v_existing_id is null then
    v_result := jsonb_build_object(
      'client_id',v_client,'entity_type',v_type,'status','ready',
      'existing',null,'differences','{}'::jsonb
    );
  elsif v_diff='{}'::jsonb then
    v_result := jsonb_build_object(
      'client_id',v_client,'entity_type',v_type,'status','existing_unchanged',
      'existing_id',v_existing_id,'existing',v_existing,'differences','{}'::jsonb
    );
  else
    v_result := jsonb_build_object(
      'client_id',v_client,'entity_type',v_type,'status','changed_existing',
      'existing_id',v_existing_id,'existing',v_existing,'differences',v_diff
    );
  end if;

  for ch in select value from jsonb_array_elements(coalesce(p_record->'children','[]'::jsonb))
  loop
    cd := coalesce(ch->'data','{}'::jsonb);
    v_child_client := v_client||'/'||coalesce(nullif(ch->>'client_id',''),'child');
    v_child_type := lower(btrim(coalesce(ch->>'event_type','')));
    v_child_existing_id := null;

    if v_existing_id is null then
      v_children := v_children || jsonb_build_array(jsonb_build_object(
        'client_id',v_child_client,'event_type',v_child_type,'status','ready'
      ));
      continue;
    end if;

    if v_type='loan' and v_child_type='loan_payment' then
      select id into v_child_existing_id
      from public.loan_payments
      where workspace_id=p_workspace_id
        and loan_id=v_existing_id
        and payment_date=nullif(cd->>'payment_date','')::date
        and amount=nullif(cd->>'amount','')::numeric
      order by created_at limit 1;

    elsif v_type='insurance_policy' and v_child_type='insurance_premium' then
      select id into v_child_existing_id
      from public.insurance_premiums
      where workspace_id=p_workspace_id
        and policy_id=v_existing_id
        and premium_date=nullif(cd->>'premium_date','')::date
        and amount=nullif(cd->>'amount','')::numeric
        and upper(currency)=upper(coalesce(nullif(cd->>'currency',''),'INR'))
      order by created_at limit 1;

    elsif v_type='investment' and v_child_type='investment_transaction' then
      select id into v_child_existing_id
      from public.investment_transactions
      where workspace_id=p_workspace_id
        and investment_id=v_existing_id
        and lower(event_type)=lower(coalesce(cd->>'event_type',''))
        and event_date=nullif(cd->>'event_date','')::date
        and coalesce(amount,0)=coalesce(nullif(cd->>'amount','')::numeric,0)
        and coalesce(quantity,0)=coalesce(nullif(cd->>'quantity','')::numeric,0)
      order by created_at limit 1;

    else
      v_children := v_children || jsonb_build_array(jsonb_build_object(
        'client_id',v_child_client,'event_type',v_child_type,'status','invalid',
        'message','Unsupported child event for entity type'
      ));
      continue;
    end if;

    v_children := v_children || jsonb_build_array(
      case when v_child_existing_id is null then
        jsonb_build_object('client_id',v_child_client,'event_type',v_child_type,'status','ready')
      else
        jsonb_build_object(
          'client_id',v_child_client,'event_type',v_child_type,'status','exact_duplicate',
          'existing_id',v_child_existing_id
        )
      end
    );
  end loop;

  return v_result || jsonb_build_object('children',v_children);
end;
$$;

revoke all on function financecanvas_private.preview_entity_record(uuid,uuid,jsonb)
from public, anon, authenticated;

create or replace function financecanvas_private.preview_financial_document(
  p_workspace_id uuid,
  p_profile_id uuid,
  p_source_hash text,
  p_document_type text,
  p_records jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = pg_catalog, public, financecanvas_private
as $$
declare
  r jsonb;
  v_results jsonb := '[]'::jsonb;
  v_existing_import jsonb;
begin
  perform financecanvas_private.assert_import_payload_safe(p_records);

  if jsonb_typeof(p_records)<>'array' then
    raise exception 'records must be an array';
  end if;

  if not exists(select 1 from public.workspaces where id=p_workspace_id) then
    raise exception 'WORKSPACE_NOT_FOUND';
  end if;

  if p_profile_id is not null and not exists(
    select 1 from public.profiles
    where id=p_profile_id and workspace_id=p_workspace_id and deleted_at is null
  ) then raise exception 'PROFILE_NOT_IN_WORKSPACE'; end if;

  if nullif(btrim(coalesce(p_source_hash,'')),'') is not null then
    select jsonb_build_object(
      'id',i.id,'source_type',i.source_type,'original_filename',i.original_filename,
      'status',i.status,'record_count',i.record_count,'detected_document_type',i.detected_document_type,
      'created_at',i.created_at
    )
    into v_existing_import
    from public.imports i
    where i.workspace_id=p_workspace_id
      and i.source_hash=p_source_hash
      and i.status in ('committed','completed')
      and i.deleted_at is null
    order by i.created_at limit 1;
  end if;

  if v_existing_import is not null then
    return jsonb_build_object(
      'document_type',p_document_type,
      'duplicate_source_document',true,
      'existing_import',v_existing_import,
      'results','[]'::jsonb
    );
  end if;

  for r in select value from jsonb_array_elements(p_records)
  loop
    v_results := v_results || jsonb_build_array(
      financecanvas_private.preview_entity_record(p_workspace_id,p_profile_id,r)
    );
  end loop;

  return jsonb_build_object(
    'document_type',p_document_type,
    'duplicate_source_document',false,
    'results',v_results
  );
end;
$$;

revoke all on function financecanvas_private.preview_financial_document(
  uuid,uuid,text,text,jsonb
) from public, anon, authenticated;

create or replace function financecanvas_private.commit_financial_document(
  p_workspace_id uuid,
  p_profile_id uuid,
  p_source_hash text,
  p_document_type text,
  p_original_filename text,
  p_records jsonb,
  p_resolutions jsonb default '[]'::jsonb,
  p_final_confirmation boolean default false
)
returns jsonb
language plpgsql
security invoker
set search_path = pg_catalog, public, financecanvas_private
as $$
declare
  v_preview jsonb;
  pr jsonb;
  r jsonb;
  d jsonb;
  ch jsonb;
  cd jsonb;
  v_res jsonb;
  v_child_res jsonb;
  v_client text;
  v_child_client text;
  v_type text;
  v_status text;
  v_decision text;
  v_reason text;
  v_existing_id uuid;
  v_entity_id uuid;
  v_child_id uuid;
  v_import_id uuid;
  v_institution_id uuid;
  v_account_id uuid;
  v_action text;
  v_conflicts jsonb := '[]'::jsonb;
  v_committed jsonb := '[]'::jsonb;
  v_skipped jsonb := '[]'::jsonb;
begin
  if p_final_confirmation is not true then
    return jsonb_build_object(
      'committed',false,'confirmation_required',true,
      'message','Final user confirmation is required before commit.'
    );
  end if;

  perform financecanvas_private.assert_import_payload_safe(p_records);
  if jsonb_typeof(p_records)<>'array'
     or jsonb_typeof(coalesce(p_resolutions,'[]'::jsonb))<>'array' then
    raise exception 'records/resolutions must be arrays';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_workspace_id::text,0));

  v_preview := financecanvas_private.preview_financial_document(
    p_workspace_id,p_profile_id,p_source_hash,p_document_type,p_records
  );

  if coalesce((v_preview->>'duplicate_source_document')::boolean,false) then
    return jsonb_build_object(
      'committed',false,'duplicate_source_document',true,
      'existing_import',v_preview->'existing_import'
    );
  end if;

  -- First pass: ensure every changed entity and duplicate child has an explicit decision.
  for pr in select value from jsonb_array_elements(v_preview->'results')
  loop
    v_client := pr->>'client_id';
    v_status := pr->>'status';

    if v_status='invalid' then
      v_conflicts := v_conflicts || jsonb_build_array(pr);
      continue;
    end if;

    if v_status='changed_existing' then
      select value into v_res
      from jsonb_array_elements(coalesce(p_resolutions,'[]'::jsonb))
      where value->>'client_id'=v_client
      limit 1;

      v_decision := coalesce(v_res->>'decision','');
      v_reason := nullif(btrim(coalesce(v_res->>'reason','')),'');

      if v_decision not in ('keep_existing','update_existing','add_separate')
         or (v_decision in ('update_existing','add_separate') and v_reason is null) then
        v_conflicts := v_conflicts || jsonb_build_array(
          pr || jsonb_build_object(
            'message','Choose keep_existing, update_existing, or add_separate. Update/add requires a reason.'
          )
        );
      end if;
    end if;

    for ch in select value from jsonb_array_elements(coalesce(pr->'children','[]'::jsonb))
    loop
      if ch->>'status'='invalid' then
        v_conflicts := v_conflicts || jsonb_build_array(ch);
      elsif ch->>'status'='exact_duplicate' then
        select value into v_child_res
        from jsonb_array_elements(coalesce(p_resolutions,'[]'::jsonb))
        where value->>'client_id'=ch->>'client_id'
        limit 1;

        v_decision := coalesce(v_child_res->>'decision','');
        v_reason := nullif(btrim(coalesce(v_child_res->>'reason','')),'');

        if v_decision not in ('skip','add_separate')
           or (v_decision='add_separate' and v_reason is null) then
          v_conflicts := v_conflicts || jsonb_build_array(
            ch || jsonb_build_object(
              'message','Choose skip or add_separate. add_separate requires a reason.'
            )
          );
        end if;
      end if;
    end loop;
  end loop;

  if jsonb_array_length(v_conflicts)>0 then
    return jsonb_build_object(
      'committed',false,'conflicts',v_conflicts,'results','[]'::jsonb
    );
  end if;

  insert into public.imports(
    workspace_id,profile_id,source_type,original_filename,source_hash,
    status,reconciliation_status,detected_document_type,confidence,metadata
  )
  values(
    p_workspace_id,p_profile_id,'structured_document',nullif(p_original_filename,''),
    nullif(btrim(coalesce(p_source_hash,'')),''),
    'confirmed','not_applicable',p_document_type,null,
    jsonb_build_object(
      'privacy_classification','private_financial',
      'source_document_stored',false,
      'connector_mode',true,
      'entity_import',true
    )
  )
  returning id into v_import_id;

  -- Second pass: commit records and supported child events.
  for r in select value from jsonb_array_elements(p_records)
  loop
    v_client := coalesce(nullif(r->>'client_id',''),'record');
    v_type := lower(btrim(r->>'entity_type'));
    d := coalesce(r->'data','{}'::jsonb);

    select value into pr
    from jsonb_array_elements(v_preview->'results')
    where value->>'client_id'=v_client
    limit 1;

    v_status := pr->>'status';
    v_existing_id := nullif(pr->>'existing_id','')::uuid;
    v_entity_id := v_existing_id;
    v_action := case when v_existing_id is null then 'created' else 'reused' end;

    select value into v_res
    from jsonb_array_elements(coalesce(p_resolutions,'[]'::jsonb))
    where value->>'client_id'=v_client
    limit 1;

    v_decision := coalesce(v_res->>'decision','');
    v_reason := nullif(btrim(coalesce(v_res->>'reason','')),'');

    if v_status='changed_existing' and v_decision='add_separate' then
      v_entity_id := null;
      v_action := 'added_duplicate';
    elsif v_status='changed_existing' and v_decision='update_existing' then
      v_action := 'updated';
    elsif v_status='changed_existing' and v_decision='keep_existing' then
      v_action := 'reused';
    end if;

    if v_type='insurance_policy' then
      v_institution_id := financecanvas_private.ensure_institution(
        p_workspace_id,d->>'institution_name','insurance'
      );

      if v_entity_id is null then
        insert into public.insurance_policies(
          workspace_id,profile_id,institution_id,policy_type,policy_name,
          policy_identifier_last4,currency,premium_amount,premium_frequency,
          coverage_amount,start_date,end_date,renewal_date,metadata
        ) values (
          p_workspace_id,p_profile_id,v_institution_id,d->>'policy_type',d->>'policy_name',
          nullif(d->>'policy_identifier_last4',''),
          upper(coalesce(nullif(d->>'currency',''),'INR')),
          nullif(d->>'premium_amount','')::numeric,nullif(d->>'premium_frequency',''),
          nullif(d->>'coverage_amount','')::numeric,nullif(d->>'start_date','')::date,
          nullif(d->>'end_date','')::date,nullif(d->>'renewal_date','')::date,
          coalesce(d->'metadata','{}'::jsonb) || jsonb_build_object(
            'privacy_classification','private_financial','source_document_stored',false,'import_id',v_import_id
          )
        ) returning id into v_entity_id;
      elsif v_action='updated' then
        update public.insurance_policies set
          institution_id=case when d ? 'institution_name' then v_institution_id else institution_id end,
          policy_type=case when d ? 'policy_type' then d->>'policy_type' else policy_type end,
          policy_name=case when d ? 'policy_name' then d->>'policy_name' else policy_name end,
          policy_identifier_last4=case when d ? 'policy_identifier_last4' then nullif(d->>'policy_identifier_last4','') else policy_identifier_last4 end,
          currency=case when d ? 'currency' then upper(d->>'currency') else currency end,
          premium_amount=case when d ? 'premium_amount' then nullif(d->>'premium_amount','')::numeric else premium_amount end,
          premium_frequency=case when d ? 'premium_frequency' then nullif(d->>'premium_frequency','') else premium_frequency end,
          coverage_amount=case when d ? 'coverage_amount' then nullif(d->>'coverage_amount','')::numeric else coverage_amount end,
          start_date=case when d ? 'start_date' then nullif(d->>'start_date','')::date else start_date end,
          end_date=case when d ? 'end_date' then nullif(d->>'end_date','')::date else end_date end,
          renewal_date=case when d ? 'renewal_date' then nullif(d->>'renewal_date','')::date else renewal_date end,
          metadata=metadata || jsonb_build_object('last_import_id',v_import_id,'privacy_classification','private_financial'),
          updated_at=now()
        where id=v_entity_id and workspace_id=p_workspace_id;
      end if;

    elsif v_type='loan' then
      v_institution_id := financecanvas_private.ensure_institution(
        p_workspace_id,d->>'institution_name','lender'
      );

      if v_entity_id is null then
        insert into public.loans(
          workspace_id,profile_id,institution_id,name,loan_type,currency,
          principal_original,outstanding_principal,interest_rate_annual,emi_amount,
          start_date,end_date,identifier_last4,metadata
        ) values (
          p_workspace_id,p_profile_id,v_institution_id,d->>'name',nullif(d->>'loan_type',''),
          upper(coalesce(nullif(d->>'currency',''),'INR')),
          nullif(d->>'principal_original','')::numeric,nullif(d->>'outstanding_principal','')::numeric,
          nullif(d->>'interest_rate_annual','')::numeric,nullif(d->>'emi_amount','')::numeric,
          nullif(d->>'start_date','')::date,nullif(d->>'end_date','')::date,
          nullif(d->>'identifier_last4',''),
          coalesce(d->'metadata','{}'::jsonb) || jsonb_build_object(
            'privacy_classification','private_financial','source_document_stored',false,'import_id',v_import_id
          )
        ) returning id into v_entity_id;
      elsif v_action='updated' then
        update public.loans set
          institution_id=case when d ? 'institution_name' then v_institution_id else institution_id end,
          name=case when d ? 'name' then d->>'name' else name end,
          loan_type=case when d ? 'loan_type' then nullif(d->>'loan_type','') else loan_type end,
          currency=case when d ? 'currency' then upper(d->>'currency') else currency end,
          principal_original=case when d ? 'principal_original' then nullif(d->>'principal_original','')::numeric else principal_original end,
          outstanding_principal=case when d ? 'outstanding_principal' then nullif(d->>'outstanding_principal','')::numeric else outstanding_principal end,
          interest_rate_annual=case when d ? 'interest_rate_annual' then nullif(d->>'interest_rate_annual','')::numeric else interest_rate_annual end,
          emi_amount=case when d ? 'emi_amount' then nullif(d->>'emi_amount','')::numeric else emi_amount end,
          start_date=case when d ? 'start_date' then nullif(d->>'start_date','')::date else start_date end,
          end_date=case when d ? 'end_date' then nullif(d->>'end_date','')::date else end_date end,
          identifier_last4=case when d ? 'identifier_last4' then nullif(d->>'identifier_last4','') else identifier_last4 end,
          metadata=metadata || jsonb_build_object('last_import_id',v_import_id,'privacy_classification','private_financial'),
          updated_at=now()
        where id=v_entity_id and workspace_id=p_workspace_id;
      end if;

    elsif v_type='investment' then
      v_account_id := nullif(d->>'account_id','')::uuid;
      if v_account_id is not null and not exists(
        select 1 from public.accounts where id=v_account_id and workspace_id=p_workspace_id and deleted_at is null
      ) then raise exception 'ACCOUNT_NOT_IN_WORKSPACE'; end if;

      if v_entity_id is null then
        insert into public.investments(
          workspace_id,profile_id,account_id,name,investment_type,symbol,currency,
          quantity,cost_basis,current_value,value_as_of,metadata
        ) values (
          p_workspace_id,p_profile_id,v_account_id,d->>'name',nullif(d->>'investment_type',''),
          nullif(d->>'symbol',''),upper(coalesce(nullif(d->>'currency',''),'INR')),
          nullif(d->>'quantity','')::numeric,nullif(d->>'cost_basis','')::numeric,
          nullif(d->>'current_value','')::numeric,nullif(d->>'value_as_of','')::date,
          coalesce(d->'metadata','{}'::jsonb) || jsonb_build_object(
            'privacy_classification','private_financial','source_document_stored',false,'import_id',v_import_id
          )
        ) returning id into v_entity_id;
      elsif v_action='updated' then
        update public.investments set
          account_id=case when d ? 'account_id' then v_account_id else account_id end,
          name=case when d ? 'name' then d->>'name' else name end,
          investment_type=case when d ? 'investment_type' then nullif(d->>'investment_type','') else investment_type end,
          symbol=case when d ? 'symbol' then nullif(d->>'symbol','') else symbol end,
          currency=case when d ? 'currency' then upper(d->>'currency') else currency end,
          quantity=case when d ? 'quantity' then nullif(d->>'quantity','')::numeric else quantity end,
          cost_basis=case when d ? 'cost_basis' then nullif(d->>'cost_basis','')::numeric else cost_basis end,
          current_value=case when d ? 'current_value' then nullif(d->>'current_value','')::numeric else current_value end,
          value_as_of=case when d ? 'value_as_of' then nullif(d->>'value_as_of','')::date else value_as_of end,
          metadata=metadata || jsonb_build_object('last_import_id',v_import_id,'privacy_classification','private_financial'),
          updated_at=now()
        where id=v_entity_id and workspace_id=p_workspace_id;
      end if;

    elsif v_type='income_source' then
      v_account_id := nullif(d->>'account_id','')::uuid;
      if v_account_id is not null and not exists(
        select 1 from public.accounts where id=v_account_id and workspace_id=p_workspace_id and deleted_at is null
      ) then raise exception 'ACCOUNT_NOT_IN_WORKSPACE'; end if;

      if v_entity_id is null then
        insert into public.income_sources(
          workspace_id,profile_id,account_id,name,income_type,currency,
          expected_amount,frequency,next_expected_date,status,metadata
        ) values (
          p_workspace_id,p_profile_id,v_account_id,d->>'name',d->>'income_type',
          upper(coalesce(nullif(d->>'currency',''),'INR')),
          nullif(d->>'expected_amount','')::numeric,nullif(d->>'frequency',''),
          nullif(d->>'next_expected_date','')::date,
          coalesce(nullif(d->>'status',''),'active'),
          coalesce(d->'metadata','{}'::jsonb) || jsonb_build_object(
            'privacy_classification','private_financial','source_document_stored',false,'import_id',v_import_id
          )
        ) returning id into v_entity_id;
      elsif v_action='updated' then
        update public.income_sources set
          account_id=case when d ? 'account_id' then v_account_id else account_id end,
          name=case when d ? 'name' then d->>'name' else name end,
          income_type=case when d ? 'income_type' then d->>'income_type' else income_type end,
          currency=case when d ? 'currency' then upper(d->>'currency') else currency end,
          expected_amount=case when d ? 'expected_amount' then nullif(d->>'expected_amount','')::numeric else expected_amount end,
          frequency=case when d ? 'frequency' then nullif(d->>'frequency','') else frequency end,
          next_expected_date=case when d ? 'next_expected_date' then nullif(d->>'next_expected_date','')::date else next_expected_date end,
          status=case when d ? 'status' then d->>'status' else status end,
          metadata=metadata || jsonb_build_object('last_import_id',v_import_id,'privacy_classification','private_financial'),
          updated_at=now()
        where id=v_entity_id and workspace_id=p_workspace_id;
      end if;

    elsif v_type='asset' then
      if v_entity_id is null then
        insert into public.assets(
          workspace_id,profile_id,name,asset_type,currency,value,value_as_of,metadata
        ) values (
          p_workspace_id,p_profile_id,d->>'name',nullif(d->>'asset_type',''),
          upper(coalesce(nullif(d->>'currency',''),'INR')),
          nullif(d->>'value','')::numeric,nullif(d->>'value_as_of','')::date,
          coalesce(d->'metadata','{}'::jsonb) || jsonb_build_object(
            'privacy_classification','private_financial','source_document_stored',false,'import_id',v_import_id
          )
        ) returning id into v_entity_id;
      elsif v_action='updated' then
        update public.assets set
          name=case when d ? 'name' then d->>'name' else name end,
          asset_type=case when d ? 'asset_type' then nullif(d->>'asset_type','') else asset_type end,
          currency=case when d ? 'currency' then upper(d->>'currency') else currency end,
          value=case when d ? 'value' then nullif(d->>'value','')::numeric else value end,
          value_as_of=case when d ? 'value_as_of' then nullif(d->>'value_as_of','')::date else value_as_of end,
          metadata=metadata || jsonb_build_object('last_import_id',v_import_id,'privacy_classification','private_financial'),
          updated_at=now()
        where id=v_entity_id and workspace_id=p_workspace_id;
      end if;

    elsif v_type='liability' then
      if v_entity_id is null then
        insert into public.liabilities(
          workspace_id,profile_id,name,liability_type,currency,outstanding_amount,amount_as_of,metadata
        ) values (
          p_workspace_id,p_profile_id,d->>'name',nullif(d->>'liability_type',''),
          upper(coalesce(nullif(d->>'currency',''),'INR')),
          nullif(d->>'outstanding_amount','')::numeric,nullif(d->>'amount_as_of','')::date,
          coalesce(d->'metadata','{}'::jsonb) || jsonb_build_object(
            'privacy_classification','private_financial','source_document_stored',false,'import_id',v_import_id
          )
        ) returning id into v_entity_id;
      elsif v_action='updated' then
        update public.liabilities set
          name=case when d ? 'name' then d->>'name' else name end,
          liability_type=case when d ? 'liability_type' then nullif(d->>'liability_type','') else liability_type end,
          currency=case when d ? 'currency' then upper(d->>'currency') else currency end,
          outstanding_amount=case when d ? 'outstanding_amount' then nullif(d->>'outstanding_amount','')::numeric else outstanding_amount end,
          amount_as_of=case when d ? 'amount_as_of' then nullif(d->>'amount_as_of','')::date else amount_as_of end,
          metadata=metadata || jsonb_build_object('last_import_id',v_import_id,'privacy_classification','private_financial'),
          updated_at=now()
        where id=v_entity_id and workspace_id=p_workspace_id;
      end if;

    elsif v_type='subscription' then
      if v_entity_id is null then
        insert into public.subscriptions(
          workspace_id,profile_id,merchant_name,amount,currency,frequency,
          next_expected_date,status,metadata
        ) values (
          p_workspace_id,p_profile_id,d->>'merchant_name',
          nullif(d->>'amount','')::numeric,upper(coalesce(nullif(d->>'currency',''),'INR')),
          nullif(d->>'frequency',''),nullif(d->>'next_expected_date','')::date,
          coalesce(nullif(d->>'status',''),'active'),
          coalesce(d->'metadata','{}'::jsonb) || jsonb_build_object(
            'privacy_classification','private_financial','source_document_stored',false,'import_id',v_import_id
          )
        ) returning id into v_entity_id;
      elsif v_action='updated' then
        update public.subscriptions set
          merchant_name=case when d ? 'merchant_name' then d->>'merchant_name' else merchant_name end,
          amount=case when d ? 'amount' then nullif(d->>'amount','')::numeric else amount end,
          currency=case when d ? 'currency' then upper(d->>'currency') else currency end,
          frequency=case when d ? 'frequency' then nullif(d->>'frequency','') else frequency end,
          next_expected_date=case when d ? 'next_expected_date' then nullif(d->>'next_expected_date','')::date else next_expected_date end,
          status=case when d ? 'status' then d->>'status' else status end,
          metadata=metadata || jsonb_build_object('last_import_id',v_import_id,'privacy_classification','private_financial'),
          updated_at=now()
        where id=v_entity_id and workspace_id=p_workspace_id;
      end if;

    elsif v_type='goal' then
      if v_entity_id is null then
        insert into public.goals(
          workspace_id,profile_id,name,goal_type,currency,target_amount,current_amount,
          target_date,priority,status,metadata
        ) values (
          p_workspace_id,p_profile_id,d->>'name',nullif(d->>'goal_type',''),
          upper(coalesce(nullif(d->>'currency',''),'INR')),
          nullif(d->>'target_amount','')::numeric,nullif(d->>'current_amount','')::numeric,
          nullif(d->>'target_date','')::date,nullif(d->>'priority',''),
          coalesce(nullif(d->>'status',''),'active'),
          coalesce(d->'metadata','{}'::jsonb) || jsonb_build_object(
            'privacy_classification','private_financial','source_document_stored',false,'import_id',v_import_id
          )
        ) returning id into v_entity_id;
      elsif v_action='updated' then
        update public.goals set
          name=case when d ? 'name' then d->>'name' else name end,
          goal_type=case when d ? 'goal_type' then nullif(d->>'goal_type','') else goal_type end,
          currency=case when d ? 'currency' then upper(d->>'currency') else currency end,
          target_amount=case when d ? 'target_amount' then nullif(d->>'target_amount','')::numeric else target_amount end,
          current_amount=case when d ? 'current_amount' then nullif(d->>'current_amount','')::numeric else current_amount end,
          target_date=case when d ? 'target_date' then nullif(d->>'target_date','')::date else target_date end,
          priority=case when d ? 'priority' then nullif(d->>'priority','') else priority end,
          status=case when d ? 'status' then d->>'status' else status end,
          metadata=metadata || jsonb_build_object('last_import_id',v_import_id,'privacy_classification','private_financial'),
          updated_at=now()
        where id=v_entity_id and workspace_id=p_workspace_id;
      end if;

    elsif v_type='recurring_item' then
      v_account_id := nullif(d->>'account_id','')::uuid;
      if v_account_id is not null and not exists(
        select 1 from public.accounts where id=v_account_id and workspace_id=p_workspace_id and deleted_at is null
      ) then raise exception 'ACCOUNT_NOT_IN_WORKSPACE'; end if;

      if v_entity_id is null then
        insert into public.recurring_items(
          workspace_id,profile_id,account_id,item_type,name,merchant_name,amount,currency,
          frequency,category,subcategory,next_expected_date,expected_day,enabled,metadata
        ) values (
          p_workspace_id,p_profile_id,v_account_id,d->>'item_type',d->>'name',
          nullif(d->>'merchant_name',''),nullif(d->>'amount','')::numeric,
          upper(coalesce(nullif(d->>'currency',''),'INR')),d->>'frequency',
          nullif(d->>'category',''),nullif(d->>'subcategory',''),
          nullif(d->>'next_expected_date','')::date,nullif(d->>'expected_day','')::integer,
          coalesce((d->>'enabled')::boolean,true),
          coalesce(d->'metadata','{}'::jsonb) || jsonb_build_object(
            'privacy_classification','private_financial','source_document_stored',false,'import_id',v_import_id
          )
        ) returning id into v_entity_id;
      elsif v_action='updated' then
        update public.recurring_items set
          account_id=case when d ? 'account_id' then v_account_id else account_id end,
          item_type=case when d ? 'item_type' then d->>'item_type' else item_type end,
          name=case when d ? 'name' then d->>'name' else name end,
          merchant_name=case when d ? 'merchant_name' then nullif(d->>'merchant_name','') else merchant_name end,
          amount=case when d ? 'amount' then nullif(d->>'amount','')::numeric else amount end,
          currency=case when d ? 'currency' then upper(d->>'currency') else currency end,
          frequency=case when d ? 'frequency' then d->>'frequency' else frequency end,
          category=case when d ? 'category' then nullif(d->>'category','') else category end,
          subcategory=case when d ? 'subcategory' then nullif(d->>'subcategory','') else subcategory end,
          next_expected_date=case when d ? 'next_expected_date' then nullif(d->>'next_expected_date','')::date else next_expected_date end,
          expected_day=case when d ? 'expected_day' then nullif(d->>'expected_day','')::integer else expected_day end,
          enabled=case when d ? 'enabled' then (d->>'enabled')::boolean else enabled end,
          metadata=metadata || jsonb_build_object('last_import_id',v_import_id,'privacy_classification','private_financial'),
          updated_at=now()
        where id=v_entity_id and workspace_id=p_workspace_id;
      end if;
    end if;

    insert into public.import_entities(
      workspace_id,import_id,entity_type,entity_id,client_id,action,reason
    )
    values(p_workspace_id,v_import_id,v_type,v_entity_id,v_client,v_action,v_reason);

    insert into public.audit_log(
      workspace_id,actor_type,action,target_table,target_id,after_snapshot,reason,metadata
    )
    values(
      p_workspace_id,'supabase_connector',
      'connector_import_'||v_action,
      case v_type
        when 'insurance_policy' then 'insurance_policies'
        when 'loan' then 'loans'
        when 'investment' then 'investments'
        when 'income_source' then 'income_sources'
        when 'asset' then 'assets'
        when 'liability' then 'liabilities'
        when 'subscription' then 'subscriptions'
        when 'goal' then 'goals'
        when 'recurring_item' then 'recurring_items'
      end,
      v_entity_id,
      jsonb_build_object('entity_type',v_type,'import_id',v_import_id),
      v_reason,
      jsonb_build_object('data_minimized',true,'connector_mode',true)
    );

    -- Child events.
    for ch in select value from jsonb_array_elements(coalesce(r->'children','[]'::jsonb))
    loop
      cd := coalesce(ch->'data','{}'::jsonb);
      v_child_client := v_client||'/'||coalesce(nullif(ch->>'client_id',''),'child');
      v_child_id := null;
      v_action := 'created';
      v_reason := null;

      select value into v_child_res
      from jsonb_array_elements(coalesce(p_resolutions,'[]'::jsonb))
      where value->>'client_id'=v_child_client
      limit 1;

      if lower(ch->>'event_type')='loan_payment' and v_type='loan' then
        select id into v_child_id
        from public.loan_payments
        where workspace_id=p_workspace_id and loan_id=v_entity_id
          and payment_date=nullif(cd->>'payment_date','')::date
          and amount=nullif(cd->>'amount','')::numeric
        order by created_at limit 1;

        if v_child_id is not null and coalesce(v_child_res->>'decision','')='skip' then
          v_action := 'skipped_duplicate';
          v_reason := nullif(v_child_res->>'reason','');
        else
          if v_child_id is not null then
            v_child_id := null;
            v_action := 'added_duplicate';
            v_reason := nullif(v_child_res->>'reason','');
          end if;
          insert into public.loan_payments(
            workspace_id,loan_id,transaction_id,payment_date,amount,
            principal_component,interest_component,other_component
          ) values (
            p_workspace_id,v_entity_id,nullif(cd->>'transaction_id','')::uuid,
            (cd->>'payment_date')::date,(cd->>'amount')::numeric,
            nullif(cd->>'principal_component','')::numeric,
            nullif(cd->>'interest_component','')::numeric,
            nullif(cd->>'other_component','')::numeric
          ) returning id into v_child_id;
        end if;

      elsif lower(ch->>'event_type')='insurance_premium' and v_type='insurance_policy' then
        select id into v_child_id
        from public.insurance_premiums
        where workspace_id=p_workspace_id and policy_id=v_entity_id
          and premium_date=nullif(cd->>'premium_date','')::date
          and amount=nullif(cd->>'amount','')::numeric
          and upper(currency)=upper(coalesce(nullif(cd->>'currency',''),'INR'))
        order by created_at limit 1;

        if v_child_id is not null and coalesce(v_child_res->>'decision','')='skip' then
          v_action := 'skipped_duplicate';
          v_reason := nullif(v_child_res->>'reason','');
        else
          if v_child_id is not null then
            v_child_id := null;
            v_action := 'added_duplicate';
            v_reason := nullif(v_child_res->>'reason','');
          end if;
          insert into public.insurance_premiums(
            workspace_id,policy_id,transaction_id,premium_date,amount,currency,premium_type
          ) values (
            p_workspace_id,v_entity_id,nullif(cd->>'transaction_id','')::uuid,
            (cd->>'premium_date')::date,(cd->>'amount')::numeric,
            upper(coalesce(nullif(cd->>'currency',''),'INR')),
            nullif(cd->>'premium_type','')
          ) returning id into v_child_id;
        end if;

      elsif lower(ch->>'event_type')='investment_transaction' and v_type='investment' then
        select id into v_child_id
        from public.investment_transactions
        where workspace_id=p_workspace_id and investment_id=v_entity_id
          and lower(event_type)=lower(cd->>'event_type')
          and event_date=nullif(cd->>'event_date','')::date
          and coalesce(amount,0)=coalesce(nullif(cd->>'amount','')::numeric,0)
          and coalesce(quantity,0)=coalesce(nullif(cd->>'quantity','')::numeric,0)
        order by created_at limit 1;

        if v_child_id is not null and coalesce(v_child_res->>'decision','')='skip' then
          v_action := 'skipped_duplicate';
          v_reason := nullif(v_child_res->>'reason','');
        else
          if v_child_id is not null then
            v_child_id := null;
            v_action := 'added_duplicate';
            v_reason := nullif(v_child_res->>'reason','');
          end if;
          insert into public.investment_transactions(
            workspace_id,investment_id,transaction_id,event_type,event_date,
            quantity,price,amount,fees
          ) values (
            p_workspace_id,v_entity_id,nullif(cd->>'transaction_id','')::uuid,
            cd->>'event_type',(cd->>'event_date')::date,
            nullif(cd->>'quantity','')::numeric,nullif(cd->>'price','')::numeric,
            nullif(cd->>'amount','')::numeric,nullif(cd->>'fees','')::numeric
          ) returning id into v_child_id;
        end if;
      end if;

      if v_child_id is not null then
        insert into public.import_entities(
          workspace_id,import_id,entity_type,entity_id,parent_entity_id,client_id,action,reason
        )
        values(
          p_workspace_id,v_import_id,lower(ch->>'event_type'),
          v_child_id,v_entity_id,v_child_client,v_action,v_reason
        );
      end if;
    end loop;

    v_committed := v_committed || jsonb_build_array(jsonb_build_object(
      'client_id',v_client,'entity_type',v_type,'entity_id',v_entity_id,
      'action',case when v_status='changed_existing' then coalesce(v_decision,v_action) else v_action end
    ));
  end loop;

  update public.imports
  set status='completed',
      record_count=(select count(*) from public.import_entities where import_id=v_import_id and action<>'skipped_duplicate'),
      committed_at=coalesce(committed_at,now()),
      completed_at=now(),
      updated_at=now()
  where id=v_import_id;

  return jsonb_build_object(
    'committed',true,
    'atomic_commit',true,
    'import_id',v_import_id,
    'results',v_committed,
    'source_document_stored',false
  );
exception
  when unique_violation then
    return jsonb_build_object(
      'committed',false,'atomic_commit',false,
      'error','DUPLICATE_SOURCE_DOCUMENT',
      'message','A concurrent import with the same source hash was detected. Re-run preview.'
    );
end;
$$;

revoke all on function financecanvas_private.commit_financial_document(
  uuid,uuid,text,text,text,jsonb,jsonb,boolean
) from public, anon, authenticated;
