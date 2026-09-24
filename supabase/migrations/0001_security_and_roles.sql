-- بصيرة الحديث | Supabase production migration 0001
-- Run in Supabase SQL Editor after creating a project.
-- This migration adds identity, roles, updated_at, RLS and audit helpers.
create extension if not exists pgcrypto;

create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  role text not null default 'قارئ'
    check (role in ('مدير','باحث','مراجع علمي','محرر','قارئ')),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_sources_updated_at on sources;
create trigger trg_sources_updated_at before update on sources
for each row execute function public.set_updated_at();

drop trigger if exists trg_hadiths_updated_at on hadiths;
create trigger trg_hadiths_updated_at before update on hadiths
for each row execute function public.set_updated_at();

drop trigger if exists trg_profiles_updated_at on profiles;
create trigger trg_profiles_updated_at before update on profiles
for each row execute function public.set_updated_at();

create or replace function public.current_role()
returns text language sql stable security definer set search_path = public as $$
  select role from public.profiles where id = auth.uid() and is_active = true limit 1;
$$;

create or replace function public.can_edit()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(public.current_role() in ('مدير','باحث','محرر'), false);
$$;

create or replace function public.can_review()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(public.current_role() in ('مدير','مراجع علمي'), false);
$$;

alter table profiles enable row level security;
alter table sources enable row level security;
alter table hadiths enable row level security;
alter table narrators enable row level security;
alter table hadith_narrators enable row level security;
alter table scholar_judgments enable row level security;
alter table hadith_variants enable row level security;
alter table reviews enable row level security;
alter table audit_logs enable row level security;

drop policy if exists profiles_self_read on profiles;
create policy profiles_self_read on profiles for select
using (id = auth.uid() or public.current_role() = 'مدير');

drop policy if exists profiles_admin_write on profiles;
create policy profiles_admin_write on profiles for all
using (public.current_role() = 'مدير')
with check (public.current_role() = 'مدير');

drop policy if exists sources_read on sources;
create policy sources_read on sources for select to authenticated using (true);
drop policy if exists sources_write on sources;
create policy sources_write on sources for insert to authenticated
with check (public.can_edit());
drop policy if exists sources_update on sources;
create policy sources_update on sources for update to authenticated
using (public.can_edit()) with check (public.can_edit());
drop policy if exists sources_delete on sources;
create policy sources_delete on sources for delete to authenticated
using (public.current_role() = 'مدير');

drop policy if exists hadiths_read on hadiths;
create policy hadiths_read on hadiths for select to authenticated using (true);
drop policy if exists hadiths_insert on hadiths;
create policy hadiths_insert on hadiths for insert to authenticated
with check (public.can_edit());
drop policy if exists hadiths_update on hadiths;
create policy hadiths_update on hadiths for update to authenticated
using (public.can_edit() or public.can_review())
with check (public.can_edit() or public.can_review());
drop policy if exists hadiths_delete on hadiths;
create policy hadiths_delete on hadiths for delete to authenticated
using (public.current_role() = 'مدير');

drop policy if exists narrators_read on narrators;
create policy narrators_read on narrators for select to authenticated using (true);
drop policy if exists narrators_write on narrators;
create policy narrators_write on narrators for all to authenticated
using (public.can_edit()) with check (public.can_edit());

drop policy if exists hadith_narrators_read on hadith_narrators;
create policy hadith_narrators_read on hadith_narrators for select to authenticated using (true);
drop policy if exists hadith_narrators_write on hadith_narrators;
create policy hadith_narrators_write on hadith_narrators for all to authenticated
using (public.can_edit()) with check (public.can_edit());

drop policy if exists judgments_read on scholar_judgments;
create policy judgments_read on scholar_judgments for select to authenticated using (true);
drop policy if exists judgments_write on scholar_judgments;
create policy judgments_write on scholar_judgments for all to authenticated
using (public.can_edit()) with check (public.can_edit());

drop policy if exists variants_read on hadith_variants;
create policy variants_read on hadith_variants for select to authenticated using (true);
drop policy if exists variants_write on hadith_variants;
create policy variants_write on hadith_variants for all to authenticated
using (public.can_edit()) with check (public.can_edit());

drop policy if exists reviews_read on reviews;
create policy reviews_read on reviews for select to authenticated using (true);
drop policy if exists reviews_write on reviews;
create policy reviews_write on reviews for all to authenticated
using (public.can_review()) with check (public.can_review());

drop policy if exists audit_read on audit_logs;
create policy audit_read on audit_logs for select to authenticated
using (public.current_role() = 'مدير' or actor_id = auth.uid());
-- No direct client insert/update/delete policy: audit writes should be server-side.
