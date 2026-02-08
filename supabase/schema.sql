-- වැඩHUB Database Schema — Construction Services Marketplace
-- Run this in your Supabase SQL Editor to set up the database

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- ============================================================
-- PROFILES (extends Supabase auth.users)
-- ============================================================
create table if not exists public.profiles (
  id uuid references auth.users(id) on delete cascade primary key,
  full_name text not null,
  role text not null check (role in ('homeowner', 'professional')),
  avatar_url text,
  bio text,
  phone text,
  location text,
  district text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ============================================================
-- PROFESSIONAL PROFILES (additional data for pros)
-- ============================================================
create table if not exists public.professional_profiles (
  id uuid references public.profiles(id) on delete cascade primary key,
  company_name text,
  service_category text not null,
  specializations text[] default '{}',
  license_number text,
  years_experience integer,
  is_verified boolean default false,
  service_areas text[] default '{}',
  hourly_rate numeric(10, 2),
  completed_projects integer default 0,
  average_rating numeric(3, 2) default 0,
  total_reviews integer default 0
);

-- ============================================================
-- PROJECTS (homeowner project requests — seeking quotes)
-- ============================================================
create table if not exists public.projects (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  title text not null,
  description text not null,
  category text not null,
  project_type text not null check (project_type in ('New Build', 'Renovation', 'Repair', 'Extension', 'Consultation')),
  location text not null,
  budget_min numeric(12, 2),
  budget_max numeric(12, 2),
  timeline text,
  start_date date,
  status text default 'open' check (status in ('open', 'quoting', 'in_progress', 'completed', 'cancelled')),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ============================================================
-- PORTFOLIO PROJECTS (construction projects added by professionals)
-- ============================================================
create table if not exists public.portfolio_projects (
  id uuid default uuid_generate_v4() primary key,
  professional_id uuid references public.profiles(id) on delete cascade not null,
  title text not null,
  description text not null,
  category text not null,
  project_type text not null,
  district text not null,
  area text,
  cost numeric(12, 2),
  duration text,
  year_completed integer,
  tags text[] default '{}',
  is_featured boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ============================================================
-- QUOTES (professional responses to homeowner project requests)
-- ============================================================
create table if not exists public.quotes (
  id uuid default uuid_generate_v4() primary key,
  project_id uuid references public.projects(id) on delete cascade not null,
  professional_id uuid references public.profiles(id) on delete cascade not null,
  amount numeric(12, 2) not null,
  description text not null,
  estimated_duration text,
  materials_included boolean default false,
  status text default 'pending' check (status in ('pending', 'accepted', 'rejected', 'withdrawn')),
  created_at timestamptz default now(),
  unique(project_id, professional_id)
);

-- ============================================================
-- MESSAGES
-- ============================================================
create table if not exists public.messages (
  id uuid default uuid_generate_v4() primary key,
  sender_id uuid references public.profiles(id) on delete cascade not null,
  receiver_id uuid references public.profiles(id) on delete cascade not null,
  project_id uuid references public.projects(id) on delete set null,
  content text not null,
  read boolean default false,
  created_at timestamptz default now()
);

-- ============================================================
-- REVIEWS (homeowners review professionals after project completion)
-- ============================================================
create table if not exists public.reviews (
  id uuid default uuid_generate_v4() primary key,
  project_id uuid references public.projects(id) on delete cascade not null,
  reviewer_id uuid references public.profiles(id) on delete cascade not null,
  professional_id uuid references public.profiles(id) on delete cascade not null,
  rating integer not null check (rating >= 1 and rating <= 5),
  comment text,
  photos text[] default '{}',
  created_at timestamptz default now(),
  unique(project_id, reviewer_id)
);

-- ============================================================
-- PROJECT PHOTOS (for both portfolio projects and project requests)
-- ============================================================
create table if not exists public.project_photos (
  id uuid default uuid_generate_v4() primary key,
  project_id uuid references public.projects(id) on delete cascade,
  portfolio_project_id uuid references public.portfolio_projects(id) on delete cascade,
  professional_id uuid references public.profiles(id) on delete cascade not null,
  photo_url text not null,
  caption text,
  is_before boolean default false,
  created_at timestamptz default now(),
  check (project_id is not null or portfolio_project_id is not null)
);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

alter table public.profiles enable row level security;
alter table public.professional_profiles enable row level security;
alter table public.projects enable row level security;
alter table public.portfolio_projects enable row level security;
alter table public.quotes enable row level security;
alter table public.messages enable row level security;
alter table public.reviews enable row level security;
alter table public.project_photos enable row level security;

-- Profiles
create policy "Profiles are publicly readable" on public.profiles for select using (true);
create policy "Users can update own profile" on public.profiles for update using (auth.uid() = id);
create policy "Users can insert own profile" on public.profiles for insert with check (auth.uid() = id);

-- Professional Profiles
create policy "Pro profiles are publicly readable" on public.professional_profiles for select using (true);
create policy "Pros can update own profile" on public.professional_profiles for update using (auth.uid() = id);
create policy "Pros can insert own profile" on public.professional_profiles for insert with check (auth.uid() = id);

-- Projects (homeowner requests)
create policy "Projects are publicly readable" on public.projects for select using (true);
create policy "Homeowners can create projects" on public.projects for insert with check (auth.uid() = user_id);
create policy "Owners can update projects" on public.projects for update using (auth.uid() = user_id);

-- Portfolio Projects (professional showcases)
create policy "Portfolio projects are publicly readable" on public.portfolio_projects for select using (true);
create policy "Pros can create portfolio projects" on public.portfolio_projects for insert with check (auth.uid() = professional_id);
create policy "Pros can update own portfolio" on public.portfolio_projects for update using (auth.uid() = professional_id);
create policy "Pros can delete own portfolio" on public.portfolio_projects for delete using (auth.uid() = professional_id);

-- Quotes
create policy "Project owner and quoter can read quotes" on public.quotes for select
  using (auth.uid() = professional_id or auth.uid() in (select user_id from public.projects where id = project_id));
create policy "Professionals can create quotes" on public.quotes for insert with check (auth.uid() = professional_id);
create policy "Professionals can update own quotes" on public.quotes for update using (auth.uid() = professional_id);

-- Messages
create policy "Users can read own messages" on public.messages for select
  using (auth.uid() = sender_id or auth.uid() = receiver_id);
create policy "Authenticated users can send messages" on public.messages for insert with check (auth.uid() = sender_id);

-- Reviews
create policy "Reviews are publicly readable" on public.reviews for select using (true);
create policy "Homeowners can create reviews" on public.reviews for insert with check (auth.uid() = reviewer_id);

-- Project Photos
create policy "Project photos are publicly readable" on public.project_photos for select using (true);
create policy "Professionals can add project photos" on public.project_photos for insert with check (auth.uid() = professional_id);

-- ============================================================
-- TRIGGER: Auto-create profile on signup
-- ============================================================
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, full_name, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', 'User'),
    coalesce(new.raw_user_meta_data->>'role', 'homeowner')
  );
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================
-- TRIGGER: Update professional stats after review
-- ============================================================
create or replace function public.update_professional_stats()
returns trigger as $$
begin
  update public.professional_profiles
  set
    average_rating = (select avg(rating)::numeric(3,2) from public.reviews where professional_id = new.professional_id),
    total_reviews = (select count(*) from public.reviews where professional_id = new.professional_id)
  where id = new.professional_id;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_review_created on public.reviews;
create trigger on_review_created
  after insert on public.reviews
  for each row execute function public.update_professional_stats();

-- ============================================================
-- INDEXES
-- ============================================================
create index if not exists idx_profiles_role on public.profiles(role);
create index if not exists idx_profiles_district on public.profiles(district);
create index if not exists idx_pro_profiles_category on public.professional_profiles(service_category);
create index if not exists idx_pro_profiles_verified on public.professional_profiles(is_verified);
create index if not exists idx_projects_user_id on public.projects(user_id);
create index if not exists idx_projects_category on public.projects(category);
create index if not exists idx_projects_status on public.projects(status);
create index if not exists idx_projects_location on public.projects(location);
create index if not exists idx_portfolio_professional on public.portfolio_projects(professional_id);
create index if not exists idx_portfolio_category on public.portfolio_projects(category);
create index if not exists idx_portfolio_district on public.portfolio_projects(district);
create index if not exists idx_quotes_project_id on public.quotes(project_id);
create index if not exists idx_quotes_professional_id on public.quotes(professional_id);
create index if not exists idx_messages_sender on public.messages(sender_id);
create index if not exists idx_messages_receiver on public.messages(receiver_id);
create index if not exists idx_reviews_professional on public.reviews(professional_id);
create index if not exists idx_photos_portfolio on public.project_photos(portfolio_project_id);
create index if not exists idx_photos_project on public.project_photos(project_id);
