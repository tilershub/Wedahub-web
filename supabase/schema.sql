-- ================================================================
--  වැඩHUB — Complete Database Schema
--  Sri Lankan Construction & Home Services Marketplace
--  PostgreSQL / Supabase
--
--  Run once on a fresh project, or wrap every statement in
--  "if not exists" guards before running on an existing project.
-- ================================================================

-- ── Extensions ──────────────────────────────────────────────────
create extension if not exists "uuid-ossp";
create extension if not exists "pg_trgm";   -- fast text search


-- ================================================================
--  ENUM TYPES
-- ================================================================

-- Individual tradesperson vs registered company
create type provider_type as enum (
  'individual',
  'company'
);

-- Tasker lifecycle
create type tasker_status as enum (
  'pending',      -- just registered, awaiting review
  'active',       -- approved and live on the platform
  'suspended',    -- temporarily blocked
  'rejected'      -- rejected by admin
);

-- Work availability
create type availability_status as enum (
  'available',    -- accepting new work
  'busy',         -- working, limited capacity
  'unavailable'   -- not taking jobs right now
);

-- How a service is priced
create type pricing_model as enum (
  'per_sqft',
  'per_day',
  'per_hour',
  'fixed',
  'quote_based'   -- price only after site visit / scoping
);

-- Two-step registration progress
create type registration_step as enum (
  'personal',       -- step 1 complete
  'professional',   -- step 2 complete
  'complete'        -- profile published
);

-- Quote / job request lifecycle
create type quote_status as enum (
  'pending',    -- submitted, waiting for tasker
  'accepted',   -- tasker accepted
  'rejected',   -- tasker declined
  'withdrawn',  -- client cancelled
  'expired'     -- no response within window
);


-- ================================================================
--  1. SERVICE CATEGORIES  (master trade list)
-- ================================================================

create table if not exists public.service_categories (
  id          serial primary key,
  name        text    not null,
  slug        text    not null unique,
  icon        text,                         -- emoji or icon key
  description text,
  sort_order  integer not null default 0,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now()
);

comment on table public.service_categories is
  'Master list of trade/service types available on the platform.';


-- ================================================================
--  2. TASKERS  (provider profiles — individual or company)
-- ================================================================

create table if not exists public.taskers (
  id              uuid primary key default gen_random_uuid(),
  auth_user_id    uuid unique references auth.users(id) on delete cascade,

  -- ── Type ───────────────────────────────────────────────────
  provider_type   provider_type not null,

  -- ── Step 1 · Personal / Business ───────────────────────────
  full_name       text    not null,
  display_name    text,                     -- shown publicly; defaults to full_name
  email           text    not null unique,
  phone           text    not null,
  whatsapp        text,                     -- often same as phone; kept separate
  avatar_url      text,
  district        text    not null,         -- primary operating district
  address         text,                     -- not shown publicly

  -- Verification numbers (one applies depending on provider_type)
  nic_number      text,                     -- individual — National Identity Card
  br_number       text,                     -- company   — Business Registration

  -- Company-only fields
  company_name    text,
  company_logo_url text,

  -- ── Step 2 · Professional ──────────────────────────────────
  bio             text,
  tagline         text,                     -- one-liner shown on listings
  years_experience integer,
  cover_image_url text,
  languages       text[]  not null default '{}',   -- e.g. ['Sinhala', 'Tamil', 'English']

  -- ── Registration progress ──────────────────────────────────
  registration_step registration_step not null default 'personal',

  -- ── Status & verification ──────────────────────────────────
  status          tasker_status     not null default 'pending',
  is_verified     boolean           not null default false,
  verified_at     timestamptz,

  -- ── Availability ───────────────────────────────────────────
  availability_status availability_status not null default 'available',

  -- ── Denormalised stats (maintained by triggers) ────────────
  avg_rating      numeric(3,2) not null default 0.00,
  total_reviews   integer      not null default 0,
  jobs_completed  integer      not null default 0,

  -- ── Timestamps ─────────────────────────────────────────────
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),

  -- ── Integrity constraints ───────────────────────────────────
  constraint individual_requires_nic  check (provider_type != 'individual' or nic_number is not null),
  constraint company_requires_br      check (provider_type != 'company'    or br_number  is not null),
  constraint company_requires_name    check (provider_type != 'company'    or company_name is not null)
);

comment on table public.taskers is
  'Core provider profile. A tasker can join without any services and add them later.';
comment on column public.taskers.avg_rating      is 'Denormalised — updated by trigger after each review.';
comment on column public.taskers.total_reviews   is 'Denormalised — updated by trigger after each review.';
comment on column public.taskers.jobs_completed  is 'Denormalised — updated by trigger when a quote_request is marked complete.';


-- ================================================================
--  3. TASKER SERVICES  (what a tasker offers; one or many)
-- ================================================================

create table if not exists public.tasker_services (
  id              serial primary key,
  tasker_id       uuid    not null references public.taskers(id) on delete cascade,
  category_id     integer not null references public.service_categories(id),

  title           text    not null,         -- e.g. "Wall & Floor Tiling"
  description     text,
  specializations text[]  not null default '{}',  -- e.g. ['Marble', 'Mosaic', 'Anti-slip']

  -- ── Pricing ────────────────────────────────────────────────
  pricing_model   pricing_model not null default 'quote_based',
  price_min       numeric(12,2),
  price_max       numeric(12,2),
  currency        char(3) not null default 'LKR',

  -- ── Service coverage ───────────────────────────────────────
  coverage_districts text[] not null default '{}',  -- districts served
  service_radius_km  integer not null default 25,

  -- ── Availability ───────────────────────────────────────────
  lead_time_days  integer,                  -- minimum notice (days) before job start
  is_active       boolean not null default true,

  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),

  unique (tasker_id, category_id, title)
);

comment on table public.tasker_services is
  'Each row is one service a tasker offers. A tasker can have zero or many services.';


-- ================================================================
--  4. PORTFOLIO ITEMS  (before/after work photos)
-- ================================================================

create table if not exists public.portfolio_items (
  id                serial primary key,
  tasker_id         uuid    not null references public.taskers(id) on delete cascade,
  tasker_service_id integer references public.tasker_services(id) on delete set null,

  title             text    not null,
  description       text,
  image_url         text    not null,
  sort_order        integer not null default 0,

  -- Optional context
  project_district  text,
  completed_year    integer,

  created_at        timestamptz not null default now()
);

comment on table public.portfolio_items is
  'Work photos uploaded by a tasker. Optionally linked to a specific service.';


-- ================================================================
--  5. CERTIFICATIONS  (licences & credentials)
-- ================================================================

create table if not exists public.certifications (
  id            serial primary key,
  tasker_id     uuid not null references public.taskers(id) on delete cascade,

  title         text    not null,     -- e.g. "Electrical Trade License"
  issuing_body  text,                 -- e.g. "Sri Lanka Electrical Authority"
  issued_year   integer,
  expiry_year   integer,
  document_url  text,                 -- uploaded scan (storage URL)
  is_verified   boolean not null default false,   -- admin-verified

  created_at    timestamptz not null default now()
);

comment on table public.certifications is
  'Trade licences and professional credentials uploaded by a tasker.';


-- ================================================================
--  6. CLIENTS  (homeowners / requestors)
-- ================================================================

create table if not exists public.clients (
  id              uuid primary key default gen_random_uuid(),
  auth_user_id    uuid unique references auth.users(id) on delete set null,

  full_name       text not null,
  email           text,
  phone           text,
  whatsapp        text,
  district        text,

  -- True when the client submitted a quote without creating an account
  is_guest        boolean not null default false,

  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

comment on table public.clients is
  'People requesting services. Guests (no account) are allowed for quote submissions.';


-- ================================================================
--  7. QUOTE REQUESTS  (job inquiries; guest-friendly)
-- ================================================================

create table if not exists public.quote_requests (
  id          uuid primary key default gen_random_uuid(),

  -- ── Requestor ──────────────────────────────────────────────
  -- Either a registered client or a guest (fields filled inline)
  client_id   uuid references public.clients(id) on delete set null,

  -- Guest fields — only required when client_id is null
  guest_name      text,
  guest_email     text,
  guest_phone     text,
  guest_whatsapp  text,

  -- ── Target ─────────────────────────────────────────────────
  -- Null = broadcast to all matching taskers
  tasker_id   uuid    references public.taskers(id) on delete set null,
  category_id integer references public.service_categories(id),

  -- ── Job details ────────────────────────────────────────────
  title       text not null,
  description text not null,
  district    text not null,
  address     text,                           -- optional; not shown publicly

  -- ── Budget ─────────────────────────────────────────────────
  budget_min  numeric(12,2),
  budget_max  numeric(12,2),
  currency    char(3) not null default 'LKR',

  -- ── Timeline ───────────────────────────────────────────────
  preferred_start_date date,
  is_flexible_date     boolean not null default true,

  -- ── Attachments & notes ────────────────────────────────────
  photo_urls    text[] not null default '{}',
  special_notes text,

  -- ── Status ─────────────────────────────────────────────────
  status        quote_status not null default 'pending',

  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),

  -- Either a registered client or guest details must be present
  constraint client_or_guest check (
    client_id is not null
    or (guest_name is not null and (guest_phone is not null or guest_email is not null))
  )
);

comment on table public.quote_requests is
  'Job inquiries from clients to taskers. Supports guest submissions (no account required).';


-- ================================================================
--  8. REVIEWS  (client ratings per tasker)
-- ================================================================

create table if not exists public.reviews (
  id                serial primary key,
  tasker_id         uuid    not null references public.taskers(id) on delete cascade,
  client_id         uuid    references public.clients(id) on delete set null,
  quote_request_id  uuid    references public.quote_requests(id) on delete set null,

  rating            integer not null check (rating between 1 and 5),
  comment           text,
  photo_urls        text[]  not null default '{}',

  is_published      boolean not null default true,

  created_at        timestamptz not null default now(),

  -- One review per client per tasker
  unique (tasker_id, client_id)
);

comment on table public.reviews is
  'Client ratings and comments for a tasker after a job.';


-- ================================================================
--  LEGACY TABLES  (kept for backward compatibility with auth flow)
-- ================================================================

-- profiles — Supabase Auth hook target; kept slim
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  role        text not null default 'client' check (role in ('client', 'tasker', 'admin')),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

comment on table public.profiles is
  'Thin auth bridge created automatically on signup. Role drives routing.';


-- ================================================================
--  TRIGGERS — updated_at maintenance
-- ================================================================

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- Apply to every table with an updated_at column
do $$
declare
  t text;
begin
  foreach t in array array[
    'taskers', 'tasker_services', 'clients',
    'quote_requests', 'profiles'
  ]
  loop
    execute format(
      'drop trigger if exists trg_%1$s_updated_at on public.%1$s;
       create trigger trg_%1$s_updated_at
         before update on public.%1$s
         for each row execute function public.set_updated_at();',
      t
    );
  end loop;
end;
$$;


-- ================================================================
--  TRIGGERS — denormalised rating stats on taskers
-- ================================================================

create or replace function public.refresh_tasker_rating()
returns trigger language plpgsql security definer as $$
declare
  v_tasker_id uuid;
begin
  -- Works for INSERT, UPDATE, DELETE
  v_tasker_id := coalesce(new.tasker_id, old.tasker_id);

  update public.taskers
  set
    avg_rating    = coalesce((
      select round(avg(rating)::numeric, 2)
      from   public.reviews
      where  tasker_id = v_tasker_id
      and    is_published = true
    ), 0.00),
    total_reviews = (
      select count(*)
      from   public.reviews
      where  tasker_id = v_tasker_id
      and    is_published = true
    )
  where id = v_tasker_id;

  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_reviews_rating on public.reviews;
create trigger trg_reviews_rating
  after insert or update or delete on public.reviews
  for each row execute function public.refresh_tasker_rating();


-- ================================================================
--  TRIGGERS — auto-create profile + tasker/client row on signup
-- ================================================================

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
declare
  v_role text;
begin
  v_role := coalesce(new.raw_user_meta_data->>'role', 'client');

  insert into public.profiles (id, role)
  values (new.id, v_role)
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists trg_on_auth_user_created on auth.users;
create trigger trg_on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();


-- ================================================================
--  INDEXES
-- ================================================================

-- service_categories
create index if not exists idx_svc_cat_slug         on public.service_categories(slug);
create index if not exists idx_svc_cat_sort          on public.service_categories(sort_order);

-- taskers
create index if not exists idx_taskers_auth_user     on public.taskers(auth_user_id);
create index if not exists idx_taskers_status        on public.taskers(status);
create index if not exists idx_taskers_district      on public.taskers(district);
create index if not exists idx_taskers_provider_type on public.taskers(provider_type);
create index if not exists idx_taskers_availability  on public.taskers(availability_status);
create index if not exists idx_taskers_verified      on public.taskers(is_verified);
create index if not exists idx_taskers_rating        on public.taskers(avg_rating desc);
-- Full-text search on name / tagline
create index if not exists idx_taskers_name_trgm     on public.taskers using gin(display_name gin_trgm_ops);

-- tasker_services
create index if not exists idx_ts_tasker             on public.tasker_services(tasker_id);
create index if not exists idx_ts_category           on public.tasker_services(category_id);
create index if not exists idx_ts_active             on public.tasker_services(is_active);
create index if not exists idx_ts_pricing            on public.tasker_services(pricing_model);
create index if not exists idx_ts_districts          on public.tasker_services using gin(coverage_districts);

-- portfolio_items
create index if not exists idx_portfolio_tasker      on public.portfolio_items(tasker_id);
create index if not exists idx_portfolio_service     on public.portfolio_items(tasker_service_id);
create index if not exists idx_portfolio_sort        on public.portfolio_items(tasker_id, sort_order);

-- certifications
create index if not exists idx_certs_tasker          on public.certifications(tasker_id);

-- clients
create index if not exists idx_clients_auth_user     on public.clients(auth_user_id);
create index if not exists idx_clients_email         on public.clients(email);
create index if not exists idx_clients_guest         on public.clients(is_guest);

-- quote_requests
create index if not exists idx_qr_client             on public.quote_requests(client_id);
create index if not exists idx_qr_tasker             on public.quote_requests(tasker_id);
create index if not exists idx_qr_category           on public.quote_requests(category_id);
create index if not exists idx_qr_status             on public.quote_requests(status);
create index if not exists idx_qr_district           on public.quote_requests(district);
create index if not exists idx_qr_created            on public.quote_requests(created_at desc);

-- reviews
create index if not exists idx_reviews_tasker        on public.reviews(tasker_id);
create index if not exists idx_reviews_client        on public.reviews(client_id);
create index if not exists idx_reviews_published     on public.reviews(tasker_id, is_published);


-- ================================================================
--  ROW LEVEL SECURITY
-- ================================================================

alter table public.service_categories  enable row level security;
alter table public.taskers             enable row level security;
alter table public.tasker_services     enable row level security;
alter table public.portfolio_items     enable row level security;
alter table public.certifications      enable row level security;
alter table public.clients             enable row level security;
alter table public.quote_requests      enable row level security;
alter table public.reviews             enable row level security;
alter table public.profiles            enable row level security;

-- ── service_categories (public read, admin write) ──────────────
create policy "svc_cat_public_read"
  on public.service_categories for select using (true);

-- ── taskers ────────────────────────────────────────────────────
-- Public can see active taskers
create policy "taskers_public_read"
  on public.taskers for select
  using (status = 'active');

-- Tasker can read their own row regardless of status
create policy "taskers_self_read"
  on public.taskers for select
  using (auth.uid() = auth_user_id);

create policy "taskers_self_insert"
  on public.taskers for insert
  with check (auth.uid() = auth_user_id);

create policy "taskers_self_update"
  on public.taskers for update
  using (auth.uid() = auth_user_id);

-- ── tasker_services ────────────────────────────────────────────
create policy "ts_public_read"
  on public.tasker_services for select using (is_active = true);

create policy "ts_self_read"
  on public.tasker_services for select
  using (exists (
    select 1 from public.taskers
    where id = tasker_id and auth_user_id = auth.uid()
  ));

create policy "ts_self_write"
  on public.tasker_services for insert
  with check (exists (
    select 1 from public.taskers
    where id = tasker_id and auth_user_id = auth.uid()
  ));

create policy "ts_self_update"
  on public.tasker_services for update
  using (exists (
    select 1 from public.taskers
    where id = tasker_id and auth_user_id = auth.uid()
  ));

create policy "ts_self_delete"
  on public.tasker_services for delete
  using (exists (
    select 1 from public.taskers
    where id = tasker_id and auth_user_id = auth.uid()
  ));

-- ── portfolio_items ────────────────────────────────────────────
create policy "portfolio_public_read"
  on public.portfolio_items for select using (true);

create policy "portfolio_self_write"
  on public.portfolio_items for insert
  with check (exists (
    select 1 from public.taskers
    where id = tasker_id and auth_user_id = auth.uid()
  ));

create policy "portfolio_self_update"
  on public.portfolio_items for update
  using (exists (
    select 1 from public.taskers
    where id = tasker_id and auth_user_id = auth.uid()
  ));

create policy "portfolio_self_delete"
  on public.portfolio_items for delete
  using (exists (
    select 1 from public.taskers
    where id = tasker_id and auth_user_id = auth.uid()
  ));

-- ── certifications ─────────────────────────────────────────────
create policy "certs_public_read"
  on public.certifications for select using (true);

create policy "certs_self_write"
  on public.certifications for insert
  with check (exists (
    select 1 from public.taskers
    where id = tasker_id and auth_user_id = auth.uid()
  ));

create policy "certs_self_delete"
  on public.certifications for delete
  using (exists (
    select 1 from public.taskers
    where id = tasker_id and auth_user_id = auth.uid()
  ));

-- ── clients ────────────────────────────────────────────────────
-- Guests can insert (unauthenticated insert via service role)
create policy "clients_self_read"
  on public.clients for select
  using (auth.uid() = auth_user_id);

create policy "clients_self_update"
  on public.clients for update
  using (auth.uid() = auth_user_id);

-- ── quote_requests ─────────────────────────────────────────────
-- Public insert (guests submit without auth — use anon key + service role)
create policy "qr_public_insert"
  on public.quote_requests for insert
  with check (true);

-- Client reads their own requests
create policy "qr_client_read"
  on public.quote_requests for select
  using (
    client_id in (
      select id from public.clients where auth_user_id = auth.uid()
    )
  );

-- Tasker reads requests directed at them
create policy "qr_tasker_read"
  on public.quote_requests for select
  using (
    tasker_id in (
      select id from public.taskers where auth_user_id = auth.uid()
    )
  );

-- Tasker can update status of requests directed at them
create policy "qr_tasker_update"
  on public.quote_requests for update
  using (
    tasker_id in (
      select id from public.taskers where auth_user_id = auth.uid()
    )
  );

-- ── reviews ────────────────────────────────────────────────────
create policy "reviews_public_read"
  on public.reviews for select
  using (is_published = true);

create policy "reviews_client_insert"
  on public.reviews for insert
  with check (
    client_id in (
      select id from public.clients where auth_user_id = auth.uid()
    )
  );

-- ── profiles ───────────────────────────────────────────────────
create policy "profiles_self_read"
  on public.profiles for select
  using (auth.uid() = id);

create policy "profiles_self_insert"
  on public.profiles for insert
  with check (auth.uid() = id);

create policy "profiles_self_update"
  on public.profiles for update
  using (auth.uid() = id);


-- ================================================================
--  STORAGE BUCKETS
-- ================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('avatars',     'avatars',     true, 5242880,   array['image/jpeg', 'image/png', 'image/webp']),
  ('portfolios',  'portfolios',  true, 20971520,  array['image/jpeg', 'image/png', 'image/webp']),
  ('certs',       'certs',       false, 10485760, array['image/jpeg', 'image/png', 'application/pdf']),
  ('job-photos',  'job-photos',  true, 20971520,  array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set
  file_size_limit    = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Public buckets: anyone can read
create policy "avatars_public_read"   on storage.objects for select using (bucket_id = 'avatars');
create policy "portfolios_public_read" on storage.objects for select using (bucket_id = 'portfolios');
create policy "job_photos_public_read" on storage.objects for select using (bucket_id = 'job-photos');

-- Authenticated taskers can upload to their own folder (path prefix = tasker auth uid)
create policy "avatars_auth_upload"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and auth.uid()::text = split_part(name, '/', 1));

create policy "portfolios_auth_upload"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'portfolios' and auth.uid()::text = split_part(name, '/', 1));

create policy "certs_auth_upload"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'certs' and auth.uid()::text = split_part(name, '/', 1));

create policy "certs_auth_read"
  on storage.objects for select to authenticated
  using (bucket_id = 'certs' and auth.uid()::text = split_part(name, '/', 1));

create policy "job_photos_auth_upload"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'job-photos' and auth.uid()::text = split_part(name, '/', 1));

-- Delete own files
create policy "storage_auth_delete"
  on storage.objects for delete to authenticated
  using (auth.uid()::text = split_part(name, '/', 1));


-- ================================================================
--  SEED DATA — service_categories
-- ================================================================

insert into public.service_categories (name, slug, icon, description, sort_order) values
  ('General Construction', 'general-construction', '🏗️', 'New builds, renovations, extensions and general contracting',                          1),
  ('Architecture & Design','architecture-design',  '📐', 'Architectural planning, blueprints and structural design',                               2),
  ('Interior Design',      'interior-design',      '🎨', 'Space planning, furniture selection and interior styling',                                3),
  ('Plumbing',             'plumbing',              '🔧', 'Pipe installation, repairs, water systems and drainage',                                  4),
  ('Electrical Work',      'electrical-work',       '⚡', 'Wiring, panel upgrades, lighting and electrical repairs',                                 5),
  ('Masonry',              'masonry',               '🧱', 'Brickwork, block work, plastering and stone wall construction',                           6),
  ('Tiling',               'tiling',                '⬜', 'Floor and wall tiling, grouting, and tile installation',                                  7),
  ('Carpentry & Woodwork', 'carpentry-woodwork',    '🪵', 'Custom furniture, cabinetry, doors and woodworking',                                      8),
  ('Painting & Finishing', 'painting-finishing',    '🖌️', 'Interior and exterior painting, textures and wall finishes',                              9),
  ('Roofing',              'roofing',               '🏠', 'Roof installation, repair, waterproofing and insulation',                                10),
  ('Landscaping',          'landscaping',           '🌿', 'Garden design, lawn care, outdoor structures and planting',                              11),
  ('Glass Work',           'glass-work',            '🪟', 'Glass partitions, windows, mirrors and tempered glass fitting',                          12),
  ('Ceiling',              'ceiling',               '🏢', 'Gypsum ceilings, false ceilings, panel installation and repairs',                        13),
  ('Pantry Cupboards',     'pantry-cupboards',      '🗄️', 'Custom pantry cupboards, kitchen storage and cabinet installation',                      14),
  ('Welding & Metalwork',  'welding-metalwork',     '⚙️', 'Gates, grills, railings and custom metal fabrication',                                   15),
  ('Waterproofing',        'waterproofing',         '💧', 'Basement, roof and wall waterproofing solutions',                                        16)
on conflict (slug) do update set
  name        = excluded.name,
  icon        = excluded.icon,
  description = excluded.description,
  sort_order  = excluded.sort_order;
