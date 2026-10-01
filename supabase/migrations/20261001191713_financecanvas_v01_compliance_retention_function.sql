create or replace function public.financecanvas_purge_expired_compliance_records()
returns table(audit_deleted bigint,sensitive_events_deleted bigint,security_events_deleted bigint)
language plpgsql security definer set search_path = pg_catalog, public
as $$
declare a bigint; s bigint; e bigint;
begin
 delete from public.audit_log where retain_until < now(); get diagnostics a = row_count;
 delete from public.sensitive_data_events where retain_until < now(); get diagnostics s = row_count;
 delete from public.security_events where retain_until < now(); get diagnostics e = row_count;
 return query select a,s,e;
end;
$$;
revoke all on function public.financecanvas_purge_expired_compliance_records() from public, anon, authenticated;
