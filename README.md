# Wedahub Web

## Cloudflare Pages + Supabase Setup

1. In Cloudflare Pages, open your project and go to **Settings > Environment variables**.
2. Add these variables to **both Production and Preview** environments:
   - `PUBLIC_SUPABASE_URL`
   - `PUBLIC_SUPABASE_ANON_KEY`
3. Astro exposes client-safe env vars through `import.meta.env`, and browser-available variables must use the `PUBLIC_` prefix.
4. Use the Supabase anon/publishable key for client-side usage. Do not use a service role key in this app.

You can copy `.env.example` to `.env` for local development and fill in your own values.


## Supabase backend

Supabase powers authentication, Postgres database tables, and image storage for this app.

1. Create a Supabase project and copy keys into `.env` (or Cloudflare Pages env vars).
2. Run `supabase/schema.sql` in the SQL editor to create tables, RLS, auth triggers, and the `project-media` storage bucket policies.
3. Deploy the `get-profile` edge function if you need role-aware profile hydration on dashboard pages.

See `supabase/README.md` for the full flow.
