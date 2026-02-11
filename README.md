# Wedahub Web

## Cloudflare Pages + Supabase Setup

1. In Cloudflare Pages, open your project and go to **Settings > Environment variables**.
2. Add these variables to **both Production and Preview** environments:
   - `PUBLIC_SUPABASE_URL`
   - `PUBLIC_SUPABASE_ANON_KEY`
3. Astro exposes client-safe env vars through `import.meta.env`, and browser-available variables must use the `PUBLIC_` prefix.
4. Use the Supabase anon/publishable key for client-side usage. Do not use a service role key in this app.

You can copy `.env.example` to `.env` for local development and fill in your own values.
