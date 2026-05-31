-- ============================================================
-- TABELA DE PAPÉIS DE USUÁRIO
-- ============================================================
create table public.user_roles (
  id         uuid        primary key default gen_random_uuid(),
  user_id    uuid        not null references auth.users(id) on delete cascade,
  role       text        not null default 'user' check (role in ('admin', 'tester', 'user')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id)
);

create index user_roles_user_id_idx on public.user_roles(user_id);

-- ============================================================
-- TABELA DE FEATURE FLAGS POR USUÁRIO
-- ============================================================
create table public.feature_flags (
  id         uuid        primary key default gen_random_uuid(),
  user_id    uuid        not null references auth.users(id) on delete cascade,
  flag_name  text        not null,
  enabled    boolean     not null default false,
  created_at timestamptz not null default now(),
  unique (user_id, flag_name)
);

create index feature_flags_user_id_idx on public.feature_flags(user_id);

-- ============================================================
-- FUNÇÃO SECURITY DEFINER: retorna role do usuário atual
-- (SECURITY DEFINER bypassa RLS para evitar dependência circular)
-- ============================================================
create or replace function public.get_current_user_role()
returns text
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(
    (select role from public.user_roles where user_id = auth.uid()),
    'user'
  );
$$;

-- ============================================================
-- RLS — user_roles
-- ============================================================
alter table public.user_roles enable row level security;

-- Qualquer usuário autenticado lê seu próprio papel
create policy "roles_select_own"
  on public.user_roles for select
  using (auth.uid() = user_id);

-- Admin pode ler todos os papéis
create policy "roles_admin_select_all"
  on public.user_roles for select
  using (public.get_current_user_role() = 'admin');

-- Admin pode inserir papéis
create policy "roles_admin_insert"
  on public.user_roles for insert
  with check (public.get_current_user_role() = 'admin');

-- Admin pode atualizar papéis
create policy "roles_admin_update"
  on public.user_roles for update
  using (public.get_current_user_role() = 'admin');

-- ============================================================
-- RLS — feature_flags
-- ============================================================
alter table public.feature_flags enable row level security;

create policy "flags_select_own"
  on public.feature_flags for select
  using (auth.uid() = user_id);

create policy "flags_admin_all"
  on public.feature_flags for all
  using (public.get_current_user_role() = 'admin');

-- ============================================================
-- PROCEDURE: Promover usuário a admin por email
-- Usar via Supabase SQL Editor:
--   select public.promote_to_admin('email@exemplo.com');
-- ============================================================
create or replace function public.promote_to_admin(p_email text)
returns text
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid;
begin
  select id into v_user_id
  from auth.users
  where email = p_email;

  if v_user_id is null then
    return 'Usuário não encontrado: ' || p_email;
  end if;

  insert into public.user_roles (user_id, role)
  values (v_user_id, 'admin')
  on conflict (user_id) do update set role = 'admin', updated_at = now();

  return 'Usuário promovido a admin: ' || p_email;
end;
$$;
