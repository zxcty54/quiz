-- ============================================================
-- MockTester Premium System (Monthly, Free UPI Manual Flow)
-- Supabase SQL Editor me pura paste karke RUN karo. (Ek hi baar)
-- Tables: user_premium (kis din tak premium), premium_requests (payment requests)
-- Bucket: premium_proofs (screenshots)
-- ============================================================

-- 1) Premium status per user
create table if not exists public.user_premium (
  user_id text primary key,
  premium_until timestamptz not null,
  updated_at timestamptz not null default now()
);

-- 2) Payment requests (screenshot + UPI ref)
create table if not exists public.premium_requests (
  id uuid primary key default gen_random_uuid(),
  user_id text not null,
  user_name text,
  user_contact text,
  amount int not null default 49,
  upi_ref text,
  screenshot_url text,
  status text not null default 'pending',  -- pending | approved | rejected
  created_at timestamptz not null default now(),
  reviewed_at timestamptz
);

-- Ek UPI Ref No sirf ek baar (pending/approved me) chalega — duplicate pakad
create unique index if not exists premium_requests_upi_ref_unique
  on public.premium_requests (upi_ref)
  where upi_ref is not null and status in ('pending', 'approved');

-- 3) RLS: app anon key se kaam karta hai (baaki app ki tarah permissive)
alter table public.user_premium enable row level security;
alter table public.premium_requests enable row level security;

drop policy if exists "user_premium_all" on public.user_premium;
create policy "user_premium_all" on public.user_premium
  for all using (true) with check (true);

drop policy if exists "premium_requests_all" on public.premium_requests;
create policy "premium_requests_all" on public.premium_requests
  for all using (true) with check (true);

-- 4) Screenshot wala bucket
insert into storage.buckets (id, name, public)
values ('premium_proofs', 'premium_proofs', true)
on conflict (id) do nothing;

drop policy if exists "premium_proofs_insert" on storage.objects;
create policy "premium_proofs_insert" on storage.objects
  for insert with check (bucket_id = 'premium_proofs');

drop policy if exists "premium_proofs_read" on storage.objects;
create policy "premium_proofs_read" on storage.objects
  for select using (bucket_id = 'premium_proofs');
