-- =============================================================
-- AI Social Copilot — Migração Completa da Plataforma
-- Execute este SQL no Supabase SQL Editor (em partes se necessário)
-- =============================================================

-- =====================
-- 1. TABELA: profiles
-- =====================
CREATE TABLE IF NOT EXISTS public.profiles (
  id           UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email        TEXT,
  full_name    TEXT,
  role         TEXT NOT NULL DEFAULT 'free'
                 CHECK (role IN ('admin','free','pro','premium','beta_tester')),
  monthly_limit INTEGER NOT NULL DEFAULT 5,
  is_active    BOOLEAN NOT NULL DEFAULT true,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Políticas de segurança para profiles
DROP POLICY IF EXISTS "profiles_select_own"   ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_own"   ON public.profiles;
DROP POLICY IF EXISTS "profiles_admin_select" ON public.profiles;
DROP POLICY IF EXISTS "profiles_admin_update" ON public.profiles;

CREATE POLICY "profiles_select_own" ON public.profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "profiles_update_own" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "profiles_admin_select" ON public.profiles
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
  );

CREATE POLICY "profiles_admin_update" ON public.profiles
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
  );

-- Trigger: cria perfil automaticamente ao registrar novo usuário
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, role, monthly_limit)
  VALUES (NEW.id, NEW.email, 'free', 5)
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Atualiza updated_at automaticamente
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS set_profiles_updated_at ON public.profiles;
CREATE TRIGGER set_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Insere perfil para usuários já existentes que ainda não têm perfil
INSERT INTO public.profiles (id, email, role, monthly_limit)
SELECT id, email, 'free', 5
FROM auth.users
ON CONFLICT (id) DO NOTHING;


-- =====================
-- 2. TABELA: personas
-- =====================
CREATE TABLE IF NOT EXISTS public.personas (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id                UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  is_global               BOOLEAN NOT NULL DEFAULT false,
  name                    TEXT NOT NULL,
  description             TEXT,
  voice_tone              TEXT,
  target_audience         TEXT,
  niche                   TEXT,
  objectives              TEXT,
  main_language           TEXT DEFAULT 'pt-BR',
  brand_colors            TEXT,
  words_to_use            TEXT[] DEFAULT '{}',
  words_to_avoid          TEXT[] DEFAULT '{}',
  preferred_content_types TEXT[] DEFAULT '{}',
  cta_style               TEXT,
  communication_examples  TEXT,
  specific_rules          TEXT,
  is_active               BOOLEAN NOT NULL DEFAULT true,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.personas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "personas_select_global"  ON public.personas;
DROP POLICY IF EXISTS "personas_select_own"      ON public.personas;
DROP POLICY IF EXISTS "personas_insert_own"      ON public.personas;
DROP POLICY IF EXISTS "personas_update_own"      ON public.personas;
DROP POLICY IF EXISTS "personas_delete_own"      ON public.personas;
DROP POLICY IF EXISTS "personas_admin_all"       ON public.personas;

CREATE POLICY "personas_select_global" ON public.personas
  FOR SELECT USING (is_global = true AND auth.uid() IS NOT NULL);

CREATE POLICY "personas_select_own" ON public.personas
  FOR SELECT USING (owner_id = auth.uid());

CREATE POLICY "personas_insert_own" ON public.personas
  FOR INSERT WITH CHECK (owner_id = auth.uid());

CREATE POLICY "personas_update_own" ON public.personas
  FOR UPDATE USING (owner_id = auth.uid());

CREATE POLICY "personas_delete_own" ON public.personas
  FOR DELETE USING (owner_id = auth.uid());

CREATE POLICY "personas_admin_all" ON public.personas
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
  );

DROP TRIGGER IF EXISTS set_personas_updated_at ON public.personas;
CREATE TRIGGER set_personas_updated_at
  BEFORE UPDATE ON public.personas
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- =========================
-- 3. TABELA: content_items
-- =========================
CREATE TABLE IF NOT EXISTS public.content_items (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id              UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  persona_id           UUID REFERENCES public.personas(id) ON DELETE SET NULL,
  title                TEXT NOT NULL,
  type                 TEXT NOT NULL DEFAULT 'texto',
  description          TEXT,
  base_text            TEXT,
  niche                TEXT,
  target_audience      TEXT,
  commercial_objective TEXT,
  language             TEXT DEFAULT 'pt-BR',
  status               TEXT NOT NULL DEFAULT 'active',
  created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.content_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "content_items_own"       ON public.content_items;
DROP POLICY IF EXISTS "content_items_admin_sel" ON public.content_items;

CREATE POLICY "content_items_own" ON public.content_items
  FOR ALL USING (user_id = auth.uid());

CREATE POLICY "content_items_admin_sel" ON public.content_items
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
  );

DROP TRIGGER IF EXISTS set_content_items_updated_at ON public.content_items;
CREATE TRIGGER set_content_items_updated_at
  BEFORE UPDATE ON public.content_items
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- ==========================
-- 4. TABELA: calendar_items
-- ==========================
CREATE TABLE IF NOT EXISTS public.calendar_items (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  persona_id        UUID REFERENCES public.personas(id) ON DELETE SET NULL,
  content_item_id   UUID REFERENCES public.content_items(id) ON DELETE SET NULL,
  suggested_date    DATE,
  platform          TEXT,
  theme             TEXT,
  format            TEXT,
  objective         TEXT,
  cta               TEXT,
  status            TEXT NOT NULL DEFAULT 'ideia'
                      CHECK (status IN ('ideia','planejado','gerado','aprovado','publicado','arquivado')),
  generated_content TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.calendar_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "calendar_items_own"       ON public.calendar_items;
DROP POLICY IF EXISTS "calendar_items_admin_sel" ON public.calendar_items;

CREATE POLICY "calendar_items_own" ON public.calendar_items
  FOR ALL USING (user_id = auth.uid());

CREATE POLICY "calendar_items_admin_sel" ON public.calendar_items
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
  );

DROP TRIGGER IF EXISTS set_calendar_items_updated_at ON public.calendar_items;
CREATE TRIGGER set_calendar_items_updated_at
  BEFORE UPDATE ON public.calendar_items
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- ===================================================
-- 5. DEFINIR ADMIN — substitua pelo seu user UUID
--    (pegue em: Authentication > Users no Supabase)
-- ===================================================
-- UPDATE public.profiles
--   SET role = 'admin', monthly_limit = 99999
-- WHERE email = 'jpaulo.start@gmail.com';
--
-- Descomente as 3 linhas acima e execute separadamente.
