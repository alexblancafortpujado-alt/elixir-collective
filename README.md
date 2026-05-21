# Elixir Collective Checklist

Checklist + SOPs para Elixir Collective.

## Stack

- HTML estático + JS vanilla (sin build step)
- [Clerk](https://clerk.com) para auth (JS SDK desde CDN)
- [Supabase](https://supabase.com) Postgres para estado por usuario (RLS + JWT bridge con Clerk)
- Hosted en [Vercel](https://vercel.com)

## Desarrollo local

```bash
cd "/Users/againstoddssl/Documents/Elixir Collective Checklist"
python3 -m http.server 4321
```

Abre <http://localhost:4321/index.html>.

## Despliegue

Edita `index.html`, commit, push a `main` → Vercel auto-despliega en ~30 s.

## Schema de Supabase

Las tablas y RLS policies están en [supabase-schema.sql](supabase-schema.sql). Pegar en SQL Editor de Supabase para bootstrap.
