alter table public.transactions
 add column if not exists source_sequence integer null check(source_sequence is null or source_sequence >= 0);

create index if not exists transactions_balance_history_idx
 on public.transactions(workspace_id,account_id,posted_date,source_sequence)
 where deleted_at is null;

revoke all on table public.transactions from anon, authenticated;
