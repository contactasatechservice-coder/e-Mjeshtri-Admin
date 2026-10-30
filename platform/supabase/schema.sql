-- e-Mjeshtri 2.0 draft schema. Apply only to a dedicated project after review.
create extension if not exists pgcrypto;
create table if not exists public.profiles (id uuid primary key references auth.users(id) on delete cascade, display_name text not null check (char_length(display_name) between 2 and 100), city text, created_at timestamptz not null default now());
create table if not exists public.professionals (user_id uuid primary key references public.profiles(id) on delete cascade, bio text, verified boolean not null default false, created_at timestamptz not null default now());
create table if not exists public.categories (id uuid primary key default gen_random_uuid(), name text not null unique);
create table if not exists public.job_posts (id uuid primary key default gen_random_uuid(), client_id uuid not null references public.profiles(id), category_id uuid references public.categories(id), title text not null check (char_length(title) between 5 and 160), description text not null, city text not null, budget_min numeric(12,2) check (budget_min >= 0), budget_max numeric(12,2) check (budget_max >= budget_min), status text not null default 'open' check(status in ('open','assigned','completed','cancelled')), created_at timestamptz not null default now());
create table if not exists public.service_listings (id uuid primary key default gen_random_uuid(), professional_id uuid not null references public.professionals(user_id), category_id uuid references public.categories(id), title text not null, description text not null, city text not null, price_from numeric(12,2) check(price_from >= 0), active boolean not null default true, created_at timestamptz not null default now());
create table if not exists public.job_offers (id uuid primary key default gen_random_uuid(), job_id uuid not null references public.job_posts(id), professional_id uuid not null references public.professionals(user_id), amount numeric(12,2) not null check(amount >= 0), message text not null, status text not null default 'pending' check(status in ('pending','accepted','rejected','withdrawn')), created_at timestamptz not null default now(), unique(job_id,professional_id));
create unique index if not exists one_accepted_offer_per_job on public.job_offers(job_id) where status='accepted';
alter table public.profiles enable row level security;
alter table public.professionals enable row level security;
alter table public.categories enable row level security;
alter table public.job_posts enable row level security;
alter table public.service_listings enable row level security;
alter table public.job_offers enable row level security;
create policy "profiles public read" on public.profiles for select using(true);
create policy "profiles own insert" on public.profiles for insert to authenticated with check ((select auth.uid())=id);
create policy "profiles own update" on public.profiles for update to authenticated using((select auth.uid())=id) with check((select auth.uid())=id);
create policy "professionals public read" on public.professionals for select using(true);
create policy "professionals own insert" on public.professionals for insert to authenticated with check ((select auth.uid())=user_id and verified=false);
-- Verification is admin-only; clients cannot update the verified column.
create policy "categories public read" on public.categories for select using(true);
create policy "jobs public read" on public.job_posts for select using(true);
create policy "jobs own insert" on public.job_posts for insert to authenticated with check((select auth.uid())=client_id and status='open');
create policy "services public read" on public.service_listings for select using(active=true or professional_id=(select auth.uid()));
create policy "services own insert" on public.service_listings for insert to authenticated with check((select auth.uid())=professional_id);
create policy "offers participants read" on public.job_offers for select to authenticated using(professional_id=(select auth.uid()) or exists(select 1 from public.job_posts j where j.id=job_id and j.client_id=(select auth.uid())));
create policy "offers own insert" on public.job_offers for insert to authenticated with check(professional_id=(select auth.uid()) and status='pending' and exists(select 1 from public.job_posts j where j.id=job_id and j.status='open' and j.client_id<>(select auth.uid())));
-- Offer acceptance, job assignment, edits and moderation will use carefully validated server operations in a later phase.
