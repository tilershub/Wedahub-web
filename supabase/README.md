# Supabase setup (Auth + Database + Edge Functions)

This project uses Supabase for:

- **Auth** (`signUp`, `signInWithPassword` in the Astro pages)
- **Database** (`profiles` and marketplace tables from `schema.sql`)
- **Edge Functions** (`get-profile` for auth profile lookup, `cloudinary-signature` for secure Cloudinary uploads)

## 1) Environment variables

Copy `.env.example` to `.env` and set your project values:

- `PUBLIC_SUPABASE_URL`
- `PUBLIC_SUPABASE_ANON_KEY`
- `PUBLIC_CLOUDINARY_CLOUD_NAME`
- `PUBLIC_CLOUDINARY_API_KEY`

## 2) Database schema

Run the SQL in `supabase/schema.sql` in the Supabase SQL editor.

This creates tables, RLS policies, and auth triggers (including profile bootstrap on signup).

Set Supabase function secrets for Cloudinary:

```bash
supabase secrets set CLOUDINARY_API_KEY=<cloudinary-api-key> CLOUDINARY_API_SECRET=<cloudinary-api-secret>
```

## 3) Deploy edge function

From the project root:

```bash
supabase functions deploy get-profile --project-ref <your-project-ref>
supabase functions deploy cloudinary-signature --project-ref <your-project-ref>
```

When running locally with Supabase CLI:

```bash
supabase start
supabase functions serve get-profile
supabase functions serve cloudinary-signature
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


## 5) Cloudinary image upload flow

`src/pages/pro/add-project.astro` now uploads selected image files to Cloudinary:

1. Calls `supabase.functions.invoke('cloudinary-signature')` to get a short-lived signed payload.
2. Uploads each image directly to Cloudinary's upload API.
3. Saves returned `secure_url` values into `public.project_photos.photo_url`.

This keeps the Cloudinary API secret on the server (Supabase Edge Function) while still allowing direct client uploads.
