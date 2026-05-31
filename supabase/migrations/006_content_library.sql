-- ============================================================
-- TABELA DE BIBLIOTECA DE CONTEÚDO
-- ============================================================
create table public.content_library (
  id         uuid        primary key default gen_random_uuid(),
  user_id    uuid        not null references auth.users(id) on delete cascade,
  brand_id   uuid        references public.brands(id) on delete set null,
  title      text        not null,
  base_text  text        not null,
  notes      text        not null default '',
  status     text        not null default 'draft' check (status in ('draft', 'in_use', 'used', 'archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index content_library_user_id_idx  on public.content_library(user_id);
create index content_library_brand_id_idx on public.content_library(brand_id);
create index content_library_status_idx   on public.content_library(status);

-- ============================================================
-- RLS — content_library (somente admin)
-- ============================================================
alter table public.content_library enable row level security;

create policy "content_library_admin_all"
  on public.content_library for all
  using (public.get_current_user_role() = 'admin')
  with check (public.get_current_user_role() = 'admin');

create trigger content_library_updated_at
  before update on public.content_library
  for each row execute function public.set_updated_at();

-- ============================================================
-- TABELA DE HISTÓRICO EDITORIAL AVANÇADO
-- ============================================================
create table public.editorial_history (
  id           uuid        primary key default gen_random_uuid(),
  user_id      uuid        not null references auth.users(id) on delete cascade,
  brand_id     uuid        references public.brands(id) on delete set null,
  persona_id   uuid        references public.personas(id) on delete set null,
  feature_used text        not null,
  platform     text        not null default '',
  objective    text        not null default '',
  content_type text        not null default '',
  input_text   text        not null,
  output_text  text        not null,
  status       text        not null default 'generated'
                check (status in ('generated', 'approved', 'needs_edit', 'rejected', 'published')),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index editorial_history_user_id_idx   on public.editorial_history(user_id);
create index editorial_history_brand_id_idx  on public.editorial_history(brand_id);
create index editorial_history_status_idx    on public.editorial_history(status);
create index editorial_history_created_idx   on public.editorial_history(created_at desc);

-- ============================================================
-- RLS — editorial_history (somente admin)
-- ============================================================
alter table public.editorial_history enable row level security;

create policy "editorial_history_admin_all"
  on public.editorial_history for all
  using (public.get_current_user_role() = 'admin')
  with check (public.get_current_user_role() = 'admin');

create trigger editorial_history_updated_at
  before update on public.editorial_history
  for each row execute function public.set_updated_at();
