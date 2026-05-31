-- ============================================================
-- TABELA DE PERSONAS
-- ============================================================
create table public.personas (
  id                  uuid        primary key default gen_random_uuid(),
  user_id             uuid        not null references auth.users(id) on delete cascade,
  brand_id            uuid        not null references public.brands(id) on delete cascade,
  name                text        not null,
  description         text        not null default '',
  audience_profile    text        not null default '',
  pain_points         text[]      not null default '{}',
  desires             text[]      not null default '{}',
  objections          text[]      not null default '{}',
  communication_style text        not null default '',
  preferred_hooks     text[]      not null default '{}',
  avoided_language    text[]      not null default '{}',
  persona_prompt      text        not null default '',
  status              text        not null default 'active' check (status in ('active', 'inactive', 'archived')),
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

create index personas_user_id_idx  on public.personas(user_id);
create index personas_brand_id_idx on public.personas(brand_id);
create index personas_status_idx   on public.personas(status);

-- ============================================================
-- RLS — personas (somente admin)
-- ============================================================
alter table public.personas enable row level security;

create policy "personas_admin_all"
  on public.personas for all
  using (public.get_current_user_role() = 'admin')
  with check (public.get_current_user_role() = 'admin');

create trigger personas_updated_at
  before update on public.personas
  for each row execute function public.set_updated_at();
