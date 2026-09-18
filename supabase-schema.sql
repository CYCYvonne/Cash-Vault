create table if not exists public.user_wallets (
  id uuid primary key,
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 32),
  currency text not null default 'USD',
  savings_goals jsonb not null default '[]'::jsonb,
  savings_history jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.user_transactions (
  id uuid primary key,
  owner_id uuid not null references auth.users(id) on delete cascade,
  wallet_id uuid not null references public.user_wallets(id) on delete cascade,
  description text not null,
  amount numeric(12, 2) not null check (amount > 0),
  type text not null check (type in ('income', 'expense')),
  category text not null,
  transaction_date date not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists user_wallets_owner_id_idx on public.user_wallets(owner_id);
create index if not exists user_transactions_owner_id_idx on public.user_transactions(owner_id);
create index if not exists user_transactions_wallet_id_idx on public.user_transactions(wallet_id);
create index if not exists user_transactions_date_idx on public.user_transactions(transaction_date desc);

alter table public.user_wallets enable row level security;
alter table public.user_transactions enable row level security;

create policy "Users can read own wallets"
  on public.user_wallets for select
  using (auth.uid() = owner_id);

create policy "Users can create own wallets"
  on public.user_wallets for insert
  with check (auth.uid() = owner_id);

create policy "Users can update own wallets"
  on public.user_wallets for update
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

create policy "Users can delete own wallets"
  on public.user_wallets for delete
  using (auth.uid() = owner_id);

create policy "Users can read own transactions"
  on public.user_transactions for select
  using (auth.uid() = owner_id);

create policy "Users can create own transactions"
  on public.user_transactions for insert
  with check (
    auth.uid() = owner_id
    and exists (
      select 1 from public.user_wallets
      where user_wallets.id = user_transactions.wallet_id
      and user_wallets.owner_id = auth.uid()
    )
  );

create policy "Users can update own transactions"
  on public.user_transactions for update
  using (auth.uid() = owner_id)
  with check (
    auth.uid() = owner_id
    and exists (
      select 1 from public.user_wallets
      where user_wallets.id = user_transactions.wallet_id
      and user_wallets.owner_id = auth.uid()
    )
  );

create policy "Users can delete own transactions"
  on public.user_transactions for delete
  using (auth.uid() = owner_id);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_user_wallets_updated_at on public.user_wallets;
create trigger set_user_wallets_updated_at
  before update on public.user_wallets
  for each row execute function public.set_updated_at();

drop trigger if exists set_user_transactions_updated_at on public.user_transactions;
create trigger set_user_transactions_updated_at
  before update on public.user_transactions
  for each row execute function public.set_updated_at();
