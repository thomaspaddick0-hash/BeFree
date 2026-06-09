-- Run this in the Supabase SQL editor at supabase.com > your project > SQL editor

create table if not exists users (
  id uuid primary key default gen_random_uuid(),
  email text unique not null,
  created_at timestamptz default now()
);

create table if not exists blocks (
  id uuid primary key,
  user_id uuid references users(id) on delete cascade,
  app_name text not null,
  blocked_domains text[] not null default '{}',
  friend_email text not null,
  code_hash text not null,      -- SHA-256 of the 4-digit code (never store plaintext)
  blocked_at timestamptz not null default now(),
  unlocked_at timestamptz       -- null = still active
);

-- Only the owning user can read/write their own blocks (Row Level Security)
alter table blocks enable row level security;
create policy "Users manage own blocks"
  on blocks for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Index for fetching active blocks quickly
create index if not exists blocks_user_active
  on blocks (user_id)
  where unlocked_at is null;
