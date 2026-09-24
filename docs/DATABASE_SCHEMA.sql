-- بصيرة الحديث | PostgreSQL / Supabase
-- مبدأ: حفظ النص الأصلي، فصل التحليل، وعدم دمج أحكام العلماء في حكم آلي واحد.
create extension if not exists pgcrypto;
create table if not exists sources (
 id uuid primary key default gen_random_uuid(), title text not null, author text, source_type text,
 editor text, edition text, publisher text, publication_year integer, isbn text, source_url text,
 file_path text, notes text, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists hadiths (
 id uuid primary key default gen_random_uuid(), source_id uuid not null references sources(id) on delete restrict,
 source_hadith_number text, book_name text, chapter_name text, narrator_text text,
 original_text text not null, isnad_text text, matn_text text, volume text, page text, keywords text[],
 extra_reference text, research_notes text, workflow_status text not null default 'مراجعة'
 check (workflow_status in ('مراجعة','موثق','منشور')), created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists narrators (
 id uuid primary key default gen_random_uuid(), name text not null, normalized_name text,
 kunya text, nisba text, generation text, notes text, created_at timestamptz not null default now()
);
create table if not exists hadith_narrators (
 id uuid primary key default gen_random_uuid(), hadith_id uuid not null references hadiths(id) on delete cascade,
 narrator_id uuid not null references narrators(id) on delete restrict, position integer not null, relation_note text,
 unique(hadith_id,narrator_id,position)
);
create table if not exists scholar_judgments (
 id uuid primary key default gen_random_uuid(), hadith_id uuid not null references hadiths(id) on delete cascade,
 scholar_name text not null, judgment_text text not null, source_title text, volume text, page text,
 citation text, judgment_date text, notes text, created_at timestamptz not null default now()
);
create table if not exists hadith_variants (
 id uuid primary key default gen_random_uuid(), hadith_id uuid not null references hadiths(id) on delete cascade,
 variant_text text not null, source_id uuid references sources(id) on delete restrict, volume text, page text,
 similarity_method text, similarity_score numeric, notes text, created_at timestamptz not null default now()
);
create table if not exists reviews (
 id uuid primary key default gen_random_uuid(), hadith_id uuid not null references hadiths(id) on delete cascade,
 reviewer_name text, decision text not null, notes text, reviewed_at timestamptz not null default now()
);
create table if not exists audit_logs (
 id uuid primary key default gen_random_uuid(), entity_type text not null, entity_id uuid not null,
 action text not null, actor_id uuid, before_data jsonb, after_data jsonb, created_at timestamptz not null default now()
);
create index if not exists idx_hadiths_source on hadiths(source_id);
create index if not exists idx_hadiths_status on hadiths(workflow_status);
create index if not exists idx_narrators_normalized on narrators(normalized_name);
create index if not exists idx_judgments_hadith on scholar_judgments(hadith_id);
create index if not exists idx_variants_hadith on hadith_variants(hadith_id);
create index if not exists idx_audit_entity on audit_logs(entity_type,entity_id);
create index if not exists idx_hadiths_original_text_fts on hadiths using gin (to_tsvector('simple',coalesce(original_text,'')));
-- عند النقل إلى Supabase: فعّل RLS وسياسات منفصلة للأدوار، ولا تضع مفاتيح سرية في GitHub Pages.
