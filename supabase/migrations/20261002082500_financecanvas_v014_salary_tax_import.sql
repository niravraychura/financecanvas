-- Connector-native salary/pay-slip and tax-summary imports.
-- Also hardens import hashes and child-record workspace references.

alter table public.imports
  drop constraint if exists imports_source_hash_format_check;

alter table public.imports
  add constraint imports_source_hash_format_check
  check(source_hash is null or source_hash ~ '^[0-9a-f]{64}$');

create table if not exists public.income_payments (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  profile_id uuid null references public.profiles(id) on delete set null,
  income_source_id uuid not null references public.income_sources(id) on delete cascade,
  transaction_id uuid null references public.transactions(id) on delete set null,
  import_id uuid null references public.imports(id) on delete set null,
  period_start date null,
  period_end date null,
  payment_date date null,
  currency text not null default 'INR' check(char_length(currency)=3),
  gross_amount numeric(20,4) null check(gross_amount is null or gross_amount>=0),
  net_amount numeric(20,4) null check(net_amount is null or net_amount>=0),
  taxes_withheld numeric(20,4) null check(taxes_withheld is null or taxes_withheld>=0),
  other_deductions numeric(20,4) null check(other_deductions is null or other_deductions>=0),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.income_payments enable row level security;
revoke all on table public.income_payments from anon, authenticated;

create index if not exists income_payments_workspace_idx
  on public.income_payments(workspace_id,profile_id,period_end desc,payment_date desc);

create table if not exists public.tax_records (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  profile_id uuid null references public.profiles(id) on delete set null,
  jurisdiction text not null default 'IN',
  tax_year text not null,
  form_type text not null,
  currency text not null default 'INR' check(char_length(currency)=3),
  gross_income numeric(20,4) null,
  taxable_income numeric(20,4) null,
  tax_paid numeric(20,4) null,
  tax_due numeric(20,4) null,
  refund_amount numeric(20,4) null,
  filing_status text null,
  filing_date date null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null
);

alter table public.tax_records enable row level security;
revoke all on table public.tax_records from anon, authenticated;

drop trigger if exists tax_records_set_updated_at on public.tax_records;
create trigger tax_records_set_updated_at
before update on public.tax_records
for each row execute function public.set_updated_at();

create index if not exists tax_records_workspace_idx
  on public.tax_records(workspace_id,profile_id,tax_year,form_type)
  where deleted_at is null;

alter table public.import_entities
  drop constraint if exists import_entities_entity_type_check;

alter table public.import_entities
  add constraint import_entities_entity_type_check
  check(entity_type in (
    'insurance_policy','loan','investment','income_source','income_payment',
    'asset','liability','subscription','goal','recurring_item','tax_record',
    'insurance_premium','loan_payment','investment_transaction'
  ));

create or replace function financecanvas_private.enforce_child_workspace()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog, public, financecanvas_private
as $$
declare
  v_parent_workspace uuid;
  v_transaction_workspace uuid;
  v_import_workspace uuid;
  v_profile_workspace uuid;
begin
  if tg_table_name='loan_payments' then
    select workspace_id into v_parent_workspace from public.loans where id=new.loan_id;
  elsif tg_table_name='insurance_premiums' then
    select workspace_id into v_parent_workspace from public.insurance_policies where id=new.policy_id;
  elsif tg_table_name='investment_transactions' then
    select workspace_id into v_parent_workspace from public.investments where id=new.investment_id;
  elsif tg_table_name='income_payments' then
    select workspace_id into v_parent_workspace from public.income_sources where id=new.income_source_id;
    if new.profile_id is not null then
      select workspace_id into v_profile_workspace from public.profiles where id=new.profile_id;
      if v_profile_workspace is distinct from new.workspace_id then
        raise exception 'CROSS_WORKSPACE_REFERENCE: profile_id';
      end if;
    end if;
    if new.import_id is not null then
      select workspace_id into v_import_workspace from public.imports where id=new.import_id;
      if v_import_workspace is distinct from new.workspace_id then
        raise exception 'CROSS_WORKSPACE_REFERENCE: import_id';
      end if;
    end if;
  end if;

  if v_parent_workspace is distinct from new.workspace_id then
    raise exception 'CROSS_WORKSPACE_REFERENCE: parent entity';
  end if;

  if new.transaction_id is not null then
    select workspace_id into v_transaction_workspace from public.transactions where id=new.transaction_id;
    if v_transaction_workspace is distinct from new.workspace_id then
      raise exception 'CROSS_WORKSPACE_REFERENCE: transaction_id';
    end if;
  end if;

  return new;
end;
$$;

revoke all on function financecanvas_private.enforce_child_workspace()
from public, anon, authenticated;

drop trigger if exists loan_payments_workspace_guard on public.loan_payments;
create trigger loan_payments_workspace_guard
before insert or update on public.loan_payments
for each row execute function financecanvas_private.enforce_child_workspace();

drop trigger if exists insurance_premiums_workspace_guard on public.insurance_premiums;
create trigger insurance_premiums_workspace_guard
before insert or update on public.insurance_premiums
for each row execute function financecanvas_private.enforce_child_workspace();

drop trigger if exists investment_transactions_workspace_guard on public.investment_transactions;
create trigger investment_transactions_workspace_guard
before insert or update on public.investment_transactions
for each row execute function financecanvas_private.enforce_child_workspace();

drop trigger if exists income_payments_workspace_guard on public.income_payments;
create trigger income_payments_workspace_guard
before insert or update on public.income_payments
for each row execute function financecanvas_private.enforce_child_workspace();

create or replace function financecanvas_private.preview_salary_document(
  p_workspace_id uuid,
  p_profile_id uuid,
  p_source_hash text,
  p_income_source jsonb,
  p_payment jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = pg_catalog, public, financecanvas_private
as $$
declare
  v_parent_record jsonb;
  v_preview jsonb;
  v_parent jsonb;
  v_source_id uuid;
  v_payment_id uuid;
  v_payment_status text := 'ready';
begin
  perform financecanvas_private.assert_import_payload_safe(p_income_source);
  perform financecanvas_private.assert_import_payload_safe(p_payment);

  v_parent_record := jsonb_build_object(
    'client_id','income-source',
    'entity_type','income_source',
    'data',p_income_source
  );

  v_preview := financecanvas_private.preview_financial_document(
    p_workspace_id,p_profile_id,p_source_hash,'salary_slip',
    jsonb_build_array(v_parent_record)
  );

  if coalesce((v_preview->>'duplicate_source_document')::boolean,false) then
    return v_preview || jsonb_build_object('payment',null);
  end if;

  v_parent := v_preview->'results'->0;
  v_source_id := nullif(v_parent->>'existing_id','')::uuid;

  if v_source_id is not null then
    select id into v_payment_id
    from public.income_payments
    where workspace_id=p_workspace_id
      and income_source_id=v_source_id
      and period_start is not distinct from nullif(p_payment->>'period_start','')::date
      and period_end is not distinct from nullif(p_payment->>'period_end','')::date
      and payment_date is not distinct from nullif(p_payment->>'payment_date','')::date
      and net_amount is not distinct from nullif(p_payment->>'net_amount','')::numeric
    order by created_at
    limit 1;

    if v_payment_id is not null then
      v_payment_status := 'exact_duplicate';
    end if;
  end if;

  return v_preview || jsonb_build_object(
    'payment',jsonb_build_object(
      'client_id','income-source/payment',
      'event_type','income_payment',
      'status',v_payment_status,
      'existing_id',v_payment_id
    )
  );
end;
$$;

revoke all on function financecanvas_private.preview_salary_document(
  uuid,uuid,text,jsonb,jsonb
) from public, anon, authenticated;

create or replace function financecanvas_private.commit_salary_document(
  p_workspace_id uuid,
  p_profile_id uuid,
  p_source_hash text,
  p_original_filename text,
  p_income_source jsonb,
  p_payment jsonb,
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
  v_payment_preview jsonb;
  v_payment_resolution jsonb;
  v_parent_result jsonb;
  v_import_id uuid;
  v_income_source_id uuid;
  v_payment_id uuid;
  v_payment_action text := 'created';
  v_reason text;
begin
  if p_final_confirmation is not true then
    return jsonb_build_object('committed',false,'confirmation_required',true);
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_workspace_id::text,0));

  v_preview := financecanvas_private.preview_salary_document(
    p_workspace_id,p_profile_id,p_source_hash,p_income_source,p_payment
  );

  if coalesce((v_preview->>'duplicate_source_document')::boolean,false) then
    return jsonb_build_object(
      'committed',false,'duplicate_source_document',true,
      'existing_import',v_preview->'existing_import'
    );
  end if;

  v_payment_preview := v_preview->'payment';

  if v_payment_preview->>'status'='exact_duplicate' then
    select value into v_payment_resolution
    from jsonb_array_elements(coalesce(p_resolutions,'[]'::jsonb))
    where value->>'client_id'='income-source/payment'
    limit 1;

    if coalesce(v_payment_resolution->>'decision','') not in ('skip','add_separate')
       or (
         v_payment_resolution->>'decision'='add_separate'
         and nullif(btrim(coalesce(v_payment_resolution->>'reason','')),'') is null
       ) then
      return jsonb_build_object(
        'committed',false,
        'conflicts',jsonb_build_array(
          v_payment_preview || jsonb_build_object(
            'message','Choose skip or add_separate. add_separate requires a reason.'
          )
        )
      );
    end if;
  end if;

  v_parent_result := financecanvas_private.commit_financial_document(
    p_workspace_id,p_profile_id,p_source_hash,'salary_slip',p_original_filename,
    jsonb_build_array(jsonb_build_object(
      'client_id','income-source','entity_type','income_source','data',p_income_source
    )),
    p_resolutions,true
  );

  if coalesce((v_parent_result->>'committed')::boolean,false) is not true then
    return v_parent_result;
  end if;

  v_import_id := (v_parent_result->>'import_id')::uuid;
  v_income_source_id := (v_parent_result->'results'->0->>'entity_id')::uuid;

  if v_payment_preview->>'status'='exact_duplicate'
     and v_payment_resolution->>'decision'='skip' then
    v_payment_id := nullif(v_payment_preview->>'existing_id','')::uuid;
    v_payment_action := 'skipped_duplicate';
    v_reason := nullif(v_payment_resolution->>'reason','');
  else
    if v_payment_preview->>'status'='exact_duplicate' then
      v_payment_action := 'added_duplicate';
      v_reason := nullif(v_payment_resolution->>'reason','');
    end if;

    if nullif(p_payment->>'transaction_id','') is not null
       and not exists(
         select 1 from public.transactions
         where id=(p_payment->>'transaction_id')::uuid
           and workspace_id=p_workspace_id
           and deleted_at is null
       ) then
      raise exception 'CROSS_WORKSPACE_REFERENCE: transaction_id';
    end if;

    insert into public.income_payments(
      workspace_id,profile_id,income_source_id,transaction_id,import_id,
      period_start,period_end,payment_date,currency,gross_amount,net_amount,
      taxes_withheld,other_deductions,metadata
    )
    values(
      p_workspace_id,p_profile_id,v_income_source_id,
      nullif(p_payment->>'transaction_id','')::uuid,v_import_id,
      nullif(p_payment->>'period_start','')::date,
      nullif(p_payment->>'period_end','')::date,
      nullif(p_payment->>'payment_date','')::date,
      upper(coalesce(nullif(p_payment->>'currency',''),'INR')),
      nullif(p_payment->>'gross_amount','')::numeric,
      nullif(p_payment->>'net_amount','')::numeric,
      nullif(p_payment->>'taxes_withheld','')::numeric,
      nullif(p_payment->>'other_deductions','')::numeric,
      coalesce(p_payment->'metadata','{}'::jsonb)
        || jsonb_build_object(
          'privacy_classification','private_financial',
          'source_document_stored',false
        )
    )
    returning id into v_payment_id;
  end if;

  insert into public.import_entities(
    workspace_id,import_id,entity_type,entity_id,parent_entity_id,client_id,action,reason
  )
  values(
    p_workspace_id,v_import_id,'income_payment',v_payment_id,v_income_source_id,
    'income-source/payment',v_payment_action,v_reason
  );

  update public.imports
  set record_count=(
      select count(*) from public.import_entities
      where import_id=v_import_id and action<>'skipped_duplicate'
    ),
    updated_at=now()
  where id=v_import_id;

  return v_parent_result || jsonb_build_object(
    'salary_payment',jsonb_build_object(
      'id',v_payment_id,'action',v_payment_action
    )
  );
end;
$$;

revoke all on function financecanvas_private.commit_salary_document(
  uuid,uuid,text,text,jsonb,jsonb,jsonb,boolean
) from public, anon, authenticated;

create or replace function financecanvas_private.preview_tax_document(
  p_workspace_id uuid,
  p_profile_id uuid,
  p_source_hash text,
  p_tax_record jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = pg_catalog, public, financecanvas_private
as $$
declare
  v_existing_id uuid;
  v_existing jsonb;
  v_diff jsonb := '{}'::jsonb;
  v_existing_import jsonb;
begin
  perform financecanvas_private.assert_import_payload_safe(p_tax_record);

  if not exists(
    select 1 from public.profiles
    where id=p_profile_id and workspace_id=p_workspace_id and deleted_at is null
  ) then raise exception 'PROFILE_NOT_IN_WORKSPACE'; end if;

  if nullif(btrim(coalesce(p_source_hash,'')),'') is not null then
    select jsonb_build_object(
      'id',id,'original_filename',original_filename,'status',status,
      'record_count',record_count,'detected_document_type',detected_document_type
    )
    into v_existing_import
    from public.imports
    where workspace_id=p_workspace_id
      and source_hash=p_source_hash
      and status in ('committed','completed')
      and deleted_at is null
    order by created_at limit 1;
  end if;

  if v_existing_import is not null then
    return jsonb_build_object(
      'duplicate_source_document',true,
      'existing_import',v_existing_import
    );
  end if;

  if nullif(btrim(p_tax_record->>'tax_year'),'') is null
     or nullif(btrim(p_tax_record->>'form_type'),'') is null then
    return jsonb_build_object(
      'duplicate_source_document',false,'status','invalid',
      'message','tax_year and form_type are required'
    );
  end if;

  select t.id,
    jsonb_build_object(
      'jurisdiction',t.jurisdiction,'tax_year',t.tax_year,'form_type',t.form_type,
      'currency',t.currency,'gross_income',t.gross_income,
      'taxable_income',t.taxable_income,'tax_paid',t.tax_paid,
      'tax_due',t.tax_due,'refund_amount',t.refund_amount,
      'filing_status',t.filing_status,'filing_date',t.filing_date
    )
  into v_existing_id,v_existing
  from public.tax_records t
  where t.workspace_id=p_workspace_id
    and t.profile_id is not distinct from p_profile_id
    and t.deleted_at is null
    and lower(t.jurisdiction)=lower(coalesce(nullif(p_tax_record->>'jurisdiction',''),'IN'))
    and lower(t.tax_year)=lower(p_tax_record->>'tax_year')
    and lower(t.form_type)=lower(p_tax_record->>'form_type')
  order by t.created_at
  limit 1;

  if v_existing_id is not null then
    v_diff := financecanvas_private.jsonb_field_differences(
      v_existing,p_tax_record,
      array['jurisdiction','tax_year','form_type','currency','gross_income',
            'taxable_income','tax_paid','tax_due','refund_amount',
            'filing_status','filing_date']
    );
  end if;

  return jsonb_build_object(
    'duplicate_source_document',false,
    'status',case
      when v_existing_id is null then 'ready'
      when v_diff='{}'::jsonb then 'existing_unchanged'
      else 'changed_existing'
    end,
    'existing_id',v_existing_id,
    'existing',v_existing,
    'differences',v_diff
  );
end;
$$;

revoke all on function financecanvas_private.preview_tax_document(
  uuid,uuid,text,jsonb
) from public, anon, authenticated;

create or replace function financecanvas_private.commit_tax_document(
  p_workspace_id uuid,
  p_profile_id uuid,
  p_source_hash text,
  p_original_filename text,
  p_tax_record jsonb,
  p_decision text default null,
  p_reason text default null,
  p_final_confirmation boolean default false
)
returns jsonb
language plpgsql
security invoker
set search_path = pg_catalog, public, financecanvas_private
as $$
declare
  v_preview jsonb;
  v_status text;
  v_existing_id uuid;
  v_entity_id uuid;
  v_import_id uuid;
  v_action text;
  v_decision text := lower(btrim(coalesce(p_decision,'')));
  v_reason text := nullif(btrim(coalesce(p_reason,'')),'');
begin
  if p_final_confirmation is not true then
    return jsonb_build_object('committed',false,'confirmation_required',true);
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_workspace_id::text,0));

  v_preview := financecanvas_private.preview_tax_document(
    p_workspace_id,p_profile_id,p_source_hash,p_tax_record
  );

  if coalesce((v_preview->>'duplicate_source_document')::boolean,false) then
    return jsonb_build_object(
      'committed',false,'duplicate_source_document',true,
      'existing_import',v_preview->'existing_import'
    );
  end if;

  v_status := v_preview->>'status';
  v_existing_id := nullif(v_preview->>'existing_id','')::uuid;

  if v_status='invalid' then
    return jsonb_build_object('committed',false,'conflicts',jsonb_build_array(v_preview));
  end if;

  if v_status='changed_existing' then
    if v_decision not in ('keep_existing','update_existing','add_separate')
       or (v_decision in ('update_existing','add_separate') and v_reason is null) then
      return jsonb_build_object(
        'committed',false,
        'conflicts',jsonb_build_array(
          v_preview || jsonb_build_object(
            'message','Choose keep_existing, update_existing, or add_separate. Update/add requires a reason.'
          )
        )
      );
    end if;
  end if;

  insert into public.imports(
    workspace_id,profile_id,source_type,original_filename,source_hash,
    status,reconciliation_status,detected_document_type,metadata
  )
  values(
    p_workspace_id,p_profile_id,'structured_document',nullif(p_original_filename,''),
    nullif(btrim(coalesce(p_source_hash,'')),''),
    'confirmed','not_applicable','tax_document',
    jsonb_build_object(
      'privacy_classification','private_financial',
      'source_document_stored',false,
      'connector_mode',true,
      'tax_identifiers_stored',false
    )
  )
  returning id into v_import_id;

  if v_existing_id is null or (v_status='changed_existing' and v_decision='add_separate') then
    insert into public.tax_records(
      workspace_id,profile_id,jurisdiction,tax_year,form_type,currency,
      gross_income,taxable_income,tax_paid,tax_due,refund_amount,
      filing_status,filing_date,metadata
    )
    values(
      p_workspace_id,p_profile_id,
      coalesce(nullif(p_tax_record->>'jurisdiction',''),'IN'),
      p_tax_record->>'tax_year',p_tax_record->>'form_type',
      upper(coalesce(nullif(p_tax_record->>'currency',''),'INR')),
      nullif(p_tax_record->>'gross_income','')::numeric,
      nullif(p_tax_record->>'taxable_income','')::numeric,
      nullif(p_tax_record->>'tax_paid','')::numeric,
      nullif(p_tax_record->>'tax_due','')::numeric,
      nullif(p_tax_record->>'refund_amount','')::numeric,
      nullif(p_tax_record->>'filing_status',''),
      nullif(p_tax_record->>'filing_date','')::date,
      coalesce(p_tax_record->'metadata','{}'::jsonb)
        || jsonb_build_object(
          'privacy_classification','private_financial',
          'source_document_stored',false,'import_id',v_import_id,
          'tax_identifiers_stored',false
        )
    )
    returning id into v_entity_id;
    v_action := case when v_existing_id is null then 'created' else 'added_duplicate' end;

  elsif v_status='changed_existing' and v_decision='update_existing' then
    v_entity_id := v_existing_id;
    update public.tax_records set
      jurisdiction=case when p_tax_record ? 'jurisdiction' then p_tax_record->>'jurisdiction' else jurisdiction end,
      tax_year=case when p_tax_record ? 'tax_year' then p_tax_record->>'tax_year' else tax_year end,
      form_type=case when p_tax_record ? 'form_type' then p_tax_record->>'form_type' else form_type end,
      currency=case when p_tax_record ? 'currency' then upper(p_tax_record->>'currency') else currency end,
      gross_income=case when p_tax_record ? 'gross_income' then nullif(p_tax_record->>'gross_income','')::numeric else gross_income end,
      taxable_income=case when p_tax_record ? 'taxable_income' then nullif(p_tax_record->>'taxable_income','')::numeric else taxable_income end,
      tax_paid=case when p_tax_record ? 'tax_paid' then nullif(p_tax_record->>'tax_paid','')::numeric else tax_paid end,
      tax_due=case when p_tax_record ? 'tax_due' then nullif(p_tax_record->>'tax_due','')::numeric else tax_due end,
      refund_amount=case when p_tax_record ? 'refund_amount' then nullif(p_tax_record->>'refund_amount','')::numeric else refund_amount end,
      filing_status=case when p_tax_record ? 'filing_status' then nullif(p_tax_record->>'filing_status','') else filing_status end,
      filing_date=case when p_tax_record ? 'filing_date' then nullif(p_tax_record->>'filing_date','')::date else filing_date end,
      metadata=metadata || jsonb_build_object('last_import_id',v_import_id,'tax_identifiers_stored',false),
      updated_at=now()
    where id=v_entity_id and workspace_id=p_workspace_id;
    v_action := 'updated';

  else
    v_entity_id := v_existing_id;
    v_action := 'reused';
  end if;

  insert into public.import_entities(
    workspace_id,import_id,entity_type,entity_id,client_id,action,reason
  )
  values(
    p_workspace_id,v_import_id,'tax_record',v_entity_id,'tax-record',
    v_action,v_reason
  );

  insert into public.audit_log(
    workspace_id,actor_type,action,target_table,target_id,after_snapshot,reason,metadata
  )
  values(
    p_workspace_id,'supabase_connector','connector_import_'||v_action,
    'tax_records',v_entity_id,
    jsonb_build_object('import_id',v_import_id,'tax_year',p_tax_record->>'tax_year','form_type',p_tax_record->>'form_type'),
    v_reason,
    jsonb_build_object('data_minimized',true,'tax_identifiers_stored',false,'connector_mode',true)
  );

  update public.imports set
    status='completed',record_count=1,committed_at=now(),completed_at=now(),updated_at=now()
  where id=v_import_id;

  return jsonb_build_object(
    'committed',true,'atomic_commit',true,'import_id',v_import_id,
    'entity_id',v_entity_id,'action',v_action,'source_document_stored',false
  );
exception
  when unique_violation then
    return jsonb_build_object(
      'committed',false,'atomic_commit',false,
      'error','DUPLICATE_SOURCE_DOCUMENT'
    );
end;
$$;

revoke all on function financecanvas_private.commit_tax_document(
  uuid,uuid,text,text,jsonb,text,text,boolean
) from public, anon, authenticated;
