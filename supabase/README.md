# Supabase setup (Auth + Database + Edge Functions)

This project uses Supabase for:

- **Auth** (`signUp`, `signInWithPassword` in the Astro pages)
- **Database** (`profiles` and marketplace tables from `schema.sql`)
- **Edge Functions** (`get-profile` to return the current authenticated profile)

## 1) Environment variables

Copy `.env.example` to `.env` and set your project values:

- `PUBLIC_SUPABASE_URL`
- `PUBLIC_SUPABASE_ANON_KEY`

## 2) Database schema

Run the SQL in `supabase/schema.sql` in the Supabase SQL editor.

This creates tables, RLS policies, and auth triggers (including profile bootstrap on signup).

## 3) Deploy edge function

From the project root:

```bash
supabase functions deploy get-profile --project-ref <your-project-ref>
```

When running locally with Supabase CLI:

```bash
supabase start
supabase functions serve get-profile
```

## 4) How it is used in the app

`src/pages/dashboard.astro` calls:

```ts
supabase.functions.invoke('get-profile')
```

The function validates JWT auth and returns:

```json
{
  "user": { "id": "...", "email": "..." },
  "profile": {
    "id": "...",
    "full_name": "...",
    "role": "homeowner"
  }
}
```

The dashboard then renders role-specific UI from database-backed profile data.
