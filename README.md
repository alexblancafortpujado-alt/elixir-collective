# Heroes App

Personal dashboard for habit tracking, goals, calendar, sleep visualization and inspiration.
Single self-contained `index.html` with Clerk auth and Supabase per-user storage.

## Stack

- Static HTML + vanilla JS (no build step)
- [Clerk](https://clerk.com) for auth (JS SDK loaded from CDN)
- [Supabase](https://supabase.com) Postgres for per-user state (single `user_state` key-value table with RLS)
- Hosted on [Vercel](https://vercel.com)

## Local development

```bash
cd /Users/againstoddssl/Documents/ClaudeBro
python3 -m http.server 4321
```

Open <http://localhost:4321/index.html>.

## How storage works

All app state (habits, goals, calendar, sleep CSV, portal notes/images) is stored in `localStorage` keys.
The wrapper `storeGet`/`storeSet`/`storeDelete`/`storeListKeys` reads from an in-memory cache
backed by `public.user_state` (one row per (user_id, key)).

`STORAGE_MODE` at the top of the inline `<script>` toggles between `'local'` (legacy localStorage)
and `'supabase'` (cloud sync via Clerk JWT).

## Updating

Edit `index.html`, commit, push to `main` — Vercel auto-deploys in ~30 sec.
