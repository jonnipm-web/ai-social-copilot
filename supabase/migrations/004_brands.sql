-- ============================================================
-- TABELA DE MARCAS (Brand Studio)
-- ============================================================
create table public.brands (
  id               uuid        primary key default gen_random_uuid(),
  user_id          uuid        not null references auth.users(id) on delete cascade,
  name             text        not null,
  description      text        not null default '',
  niche            text        not null default '',
  target_audience  text        not null default '',
  tone_of_voice    text        not null default '',
  primary_language text        not null default 'pt-BR',
  platforms        text[]      not null default '{}',
  default_ctas     text[]      not null default '{}',
  allowed_topics   text[]      not null default '{}',
  forbidden_topics text[]      not null default '{}',
  writing_style    text        not null default '',
  brand_prompt     text        not null default '',
  status           text        not null default 'active' check (status in ('active', 'inactive', 'archived')),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create index brands_user_id_idx    on public.brands(user_id);
create index brands_status_idx     on public.brands(status);

-- ============================================================
-- RLS — brands (somente admin tem acesso)
-- ============================================================
alter table public.brands enable row level security;

create policy "brands_admin_all"
  on public.brands for all
  using (public.get_current_user_role() = 'admin')
  with check (public.get_current_user_role() = 'admin');

-- ============================================================
-- TRIGGER: atualiza updated_at automaticamente
-- ============================================================
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger brands_updated_at
  before update on public.brands
  for each row execute function public.set_updated_at();
