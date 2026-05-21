-- ─────────────────────────────────────────────────────────────────────────
-- Elixir Collective Checklist — Supabase schema
-- Run this in Supabase → SQL Editor → New query, then "Run".
--
-- REQUIRES: Clerk ↔ Supabase third-party auth provider already configured
-- (Supabase Dashboard → Authentication → Sign In / Providers → add Clerk,
-- domain: optimum-quetzal-17.clerk.accounts.dev). Without it the JWT bridge
-- won't verify and every query will fail RLS.
-- ─────────────────────────────────────────────────────────────────────────

-- ─── 1. user_state ────────────────────────────────────────────────────────
-- Per-user key/value store. The app keeps all its localStorage state here:
-- habits, goals, calendar, sleep CSV, portal notes, etc.
create table if not exists public.user_state (
  user_id    text        not null,        -- Clerk user id (e.g. "user_2ab…")
  key        text        not null,
  value      jsonb,
  updated_at timestamptz not null default now(),
  primary key (user_id, key)
);
create index if not exists user_state_user_id_idx on public.user_state (user_id);

alter table public.user_state enable row level security;

-- Each Clerk-authenticated user can only see / mutate their own rows.
-- auth.jwt() ->> 'sub' is the Clerk user id when the third-party auth
-- provider is configured.
drop policy if exists "user_state self read"   on public.user_state;
drop policy if exists "user_state self write"  on public.user_state;
drop policy if exists "user_state self update" on public.user_state;
drop policy if exists "user_state self delete" on public.user_state;
create policy "user_state self read"   on public.user_state for select using  (user_id = (auth.jwt() ->> 'sub'));
create policy "user_state self write"  on public.user_state for insert with check (user_id = (auth.jwt() ->> 'sub'));
create policy "user_state self update" on public.user_state for update using  (user_id = (auth.jwt() ->> 'sub')) with check (user_id = (auth.jwt() ->> 'sub'));
create policy "user_state self delete" on public.user_state for delete using  (user_id = (auth.jwt() ->> 'sub'));


-- ─── 2. user_fragments ────────────────────────────────────────────────────
-- Community-currency balance per email (10 fragmentos = 1 free month).
create table if not exists public.user_fragments (
  email       text        primary key,
  balance     integer     not null default 0,
  user_id     text,                          -- Clerk user id, filled when known
  updated_at  timestamptz not null default now()
);
create index if not exists user_fragments_user_id_idx on public.user_fragments (user_id);

alter table public.user_fragments enable row level security;
-- Readable by any signed-in user (leaderboard view). Writes are gated in
-- the UI to admin emails — see SECURITY NOTE at the bottom of this file.
drop policy if exists "user_fragments authed full"   on public.user_fragments;
create policy "user_fragments authed full" on public.user_fragments for all
  using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');


-- ─── 3. fragment_log ──────────────────────────────────────────────────────
-- Audit trail of every fragmento adjustment.
create table if not exists public.fragment_log (
  id              bigserial   primary key,
  email           text        not null,
  delta           integer     not null,
  balance_after   integer     not null,
  reason          text,
  actor           text,
  created_at      timestamptz not null default now()
);
create index if not exists fragment_log_email_idx       on public.fragment_log (email);
create index if not exists fragment_log_created_at_idx  on public.fragment_log (created_at desc);

alter table public.fragment_log enable row level security;
drop policy if exists "fragment_log authed full" on public.fragment_log;
create policy "fragment_log authed full" on public.fragment_log for all
  using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');


-- ─── 4. app_admins ────────────────────────────────────────────────────────
-- Dynamic admin list. ADMIN_EMAILS in index.html is the unremovable owner.
create table if not exists public.app_admins (
  email     text        primary key,
  added_by  text,
  added_at  timestamptz not null default now()
);

alter table public.app_admins enable row level security;
drop policy if exists "app_admins authed full" on public.app_admins;
create policy "app_admins authed full" on public.app_admins for all
  using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');


-- ─── 5. paying_members ────────────────────────────────────────────────────
-- Source-of-truth for active subscriptions. Refilled from a Skool CSV export.
create table if not exists public.paying_members (
  email               text        primary key,
  recurring_interval  text,
  tier                text,
  first_name          text,
  last_name           text,
  joined_at           timestamptz,
  last_synced_at      timestamptz
);

alter table public.paying_members enable row level security;
drop policy if exists "paying_members authed full" on public.paying_members;
create policy "paying_members authed full" on public.paying_members for all
  using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');


-- ─── 6. sync_meta ─────────────────────────────────────────────────────────
-- Singleton row (id = 1) with metadata about the last CSV sync.
create table if not exists public.sync_meta (
  id                  integer primary key,
  last_csv_synced_at  timestamptz,
  last_csv_count      integer,
  last_csv_filename   text
);

alter table public.sync_meta enable row level security;
drop policy if exists "sync_meta authed full" on public.sync_meta;
create policy "sync_meta authed full" on public.sync_meta for all
  using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');


-- ─── 7. access_overrides ──────────────────────────────────────────────────
-- Manual allow/block list that beats the paying_members CSV.
create table if not exists public.access_overrides (
  email       text        primary key,
  override    text        not null check (override in ('allow','block')),
  reason      text,
  updated_at  timestamptz not null default now()
);

alter table public.access_overrides enable row level security;
drop policy if exists "access_overrides authed full" on public.access_overrides;
create policy "access_overrides authed full" on public.access_overrides for all
  using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');


-- ─── 8. known_users ───────────────────────────────────────────────────────
-- Roster of every email that has signed in, with first_seen_at used for
-- the "grace period for users that signed up after the last CSV sync".
create table if not exists public.known_users (
  email           text        primary key,
  clerk_user_id   text,
  display_name    text,
  first_seen_at   timestamptz not null default now(),
  last_seen_at    timestamptz not null default now()
);

alter table public.known_users enable row level security;
drop policy if exists "known_users authed full" on public.known_users;
create policy "known_users authed full" on public.known_users for all
  using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');


-- ─────────────────────────────────────────────────────────────────────────
-- SECURITY NOTE
-- ─────────────────────────────────────────────────────────────────────────
-- All tables except user_state allow ANY authenticated user (any Clerk-
-- signed-in user) to read/write. Admin gating is enforced only in the
-- UI (isAdminUser() in index.html). This mirrors the Heroes App design
-- and keeps the static-HTML / no-backend architecture viable.
--
-- Trade-off: a determined signed-in user could open devtools and tamper
-- with these tables (add themselves to app_admins, wipe paying_members,
-- etc.). If that ever becomes a problem, the proper fix is to move write
-- operations behind a serverless function that uses the Clerk SECRET key
-- and a Supabase service-role key. Out of scope for this initial cutover.
-- ─────────────────────────────────────────────────────────────────────────
