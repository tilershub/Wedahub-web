-- වැඩHUB Database Schema
-- Run this in your Supabase SQL Editor to set up the database

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- Profiles table (extends Supabase auth.users)
create table if not exists public.profiles (
  id uuid references auth.users(id) on delete cascade primary key,
  full_name text not null,
  role text not null check (role in ('freelancer', 'client')),
  avatar_url text,
  bio text,
  skills text[] default '{}',
  location text,
  hourly_rate numeric(10, 2),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Gigs / Job postings table
create table if not exists public.gigs (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  title text not null,
  description text not null,
  category text not null,
  skills text[] default '{}',
  budget numeric(12, 2) not null,
  budget_type text not null check (budget_type in ('fixed', 'hourly', 'monthly')),
  deadline date,
  status text default 'open' check (status in ('open', 'in_progress', 'completed', 'cancelled')),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Proposals table
create table if not exists public.proposals (
  id uuid default uuid_generate_v4() primary key,
  gig_id uuid references public.gigs(id) on delete cascade not null,
  freelancer_id uuid references public.profiles(id) on delete cascade not null,
  cover_letter text not null,
  proposed_budget numeric(12, 2) not null,
  estimated_duration text,
  status text default 'pending' check (status in ('pending', 'accepted', 'rejected', 'withdrawn')),
  created_at timestamptz default now(),
  unique(gig_id, freelancer_id)
);

-- Messages table
create table if not exists public.messages (
  id uuid default uuid_generate_v4() primary key,
  sender_id uuid references public.profiles(id) on delete cascade not null,
  receiver_id uuid references public.profiles(id) on delete cascade not null,
  gig_id uuid references public.gigs(id) on delete set null,
  content text not null,
  read boolean default false,
  created_at timestamptz default now()
);

-- Reviews table
create table if not exists public.reviews (
  id uuid default uuid_generate_v4() primary key,
  gig_id uuid references public.gigs(id) on delete cascade not null,
  reviewer_id uuid references public.profiles(id) on delete cascade not null,
  reviewee_id uuid references public.profiles(id) on delete cascade not null,
  rating integer not null check (rating >= 1 and rating <= 5),
  comment text,
  created_at timestamptz default now(),
  unique(gig_id, reviewer_id)
);

-- Row Level Security (RLS) policies

alter table public.profiles enable row level security;
alter table public.gigs enable row level security;
alter table public.proposals enable row level security;
alter table public.messages enable row level security;
alter table public.reviews enable row level security;

-- Profiles: anyone can read, users can update their own
create policy "Profiles are publicly readable" on public.profiles for select using (true);
create policy "Users can update own profile" on public.profiles for update using (auth.uid() = id);
create policy "Users can insert own profile" on public.profiles for insert with check (auth.uid() = id);

-- Gigs: anyone can read, authenticated users can create, owners can update
create policy "Gigs are publicly readable" on public.gigs for select using (true);
create policy "Authenticated users can create gigs" on public.gigs for insert with check (auth.uid() = user_id);
create policy "Owners can update gigs" on public.gigs for update using (auth.uid() = user_id);

-- Proposals: gig owner and proposer can read, freelancers can create
create policy "Involved parties can read proposals" on public.proposals for select
  using (auth.uid() = freelancer_id or auth.uid() in (select user_id from public.gigs where id = gig_id));
create policy "Freelancers can create proposals" on public.proposals for insert with check (auth.uid() = freelancer_id);
create policy "Proposers can update own proposals" on public.proposals for update using (auth.uid() = freelancer_id);

-- Messages: sender and receiver can read
create policy "Users can read own messages" on public.messages for select
  using (auth.uid() = sender_id or auth.uid() = receiver_id);
create policy "Authenticated users can send messages" on public.messages for insert with check (auth.uid() = sender_id);

-- Reviews: publicly readable, authenticated users can create
create policy "Reviews are publicly readable" on public.reviews for select using (true);
create policy "Authenticated users can create reviews" on public.reviews for insert with check (auth.uid() = reviewer_id);

-- Function to auto-create profile on user signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, full_name, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', 'User'),
    coalesce(new.raw_user_meta_data->>'role', 'freelancer')
  );
  return new;
end;
$$ language plpgsql security definer;

-- Trigger to auto-create profile
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Indexes for performance
create index if not exists idx_gigs_user_id on public.gigs(user_id);
create index if not exists idx_gigs_category on public.gigs(category);
create index if not exists idx_gigs_status on public.gigs(status);
create index if not exists idx_proposals_gig_id on public.proposals(gig_id);
create index if not exists idx_proposals_freelancer_id on public.proposals(freelancer_id);
create index if not exists idx_messages_sender on public.messages(sender_id);
create index if not exists idx_messages_receiver on public.messages(receiver_id);
create index if not exists idx_reviews_reviewee on public.reviews(reviewee_id);
