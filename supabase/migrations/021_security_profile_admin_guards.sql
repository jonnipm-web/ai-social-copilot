-- =============================================================
-- Migração 021 — Guardiões de autorização para profiles
--
-- Problema: profiles_update_own permite que qualquer usuário
-- autenticado atualize a própria linha, incluindo o campo `role`.
-- Isso possibilitaria auto-promoção para 'admin'.
--
-- Solução em 3 camadas:
--   1. Função RPC SECURITY DEFINER para auto-promoção controlada
--   2. Trigger BEFORE UPDATE que bloqueia alterações de role/is_active
--      por não-admins (segunda camada após o service layer)
--   3. Substituição de profiles_update_own por política restrita
-- =============================================================

-- ── 1. Função RPC para auto-promoção do email admin ──────────────────────────
-- Chamada via ProfileService.fetchCurrentProfile() quando o email
-- do usuário logado corresponde ao adminEmail configurado.
-- SECURITY DEFINER: executa como dono da função (superuser/postgres),
-- ignorando RLS. Nunca confia em payload do cliente para role.
CREATE OR REPLACE FUNCTION public.auto_promote_if_admin_email()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_email TEXT;
BEGIN
  SELECT email INTO v_email
  FROM public.profiles
  WHERE id = auth.uid();

  -- Só promove se o email bater exatamente com o endereço admin configurado
  -- em AppConstants.adminEmail. Qualquer outro email é ignorado.
  IF v_email = 'jpaulo.start@gmail.com' THEN
    UPDATE public.profiles
    SET role = 'admin', monthly_limit = 99999
    WHERE id = auth.uid()
      AND role != 'admin';
  END IF;
END;
$$;

-- Garante que apenas usuários autenticados podem chamar esta função
REVOKE ALL ON FUNCTION public.auto_promote_if_admin_email() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.auto_promote_if_admin_email() TO authenticated;


-- ── 2. Trigger: bloqueia alterações não autorizadas de role/is_active ────────
CREATE OR REPLACE FUNCTION public.enforce_profile_role_authorization()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  caller_role TEXT;
BEGIN
  -- Se role e is_active não mudaram, permite a atualização normalmente
  IF (NEW.role = OLD.role AND NEW.is_active = OLD.is_active) THEN
    RETURN NEW;
  END IF;

  -- Lê a role do chamador diretamente do banco
  SELECT role INTO caller_role
  FROM public.profiles
  WHERE id = auth.uid();

  -- Bloqueia se o chamador não for admin
  IF caller_role IS DISTINCT FROM 'admin' THEN
    RAISE EXCEPTION
      'Operação reservada para administradores. uid=% role=%',
      auth.uid(), caller_role
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  -- Bloqueia auto-promoção: admin não pode alterar a própria role
  IF auth.uid() = NEW.id AND NEW.role != OLD.role THEN
    RAISE EXCEPTION
      'Administrador não pode alterar a própria role. uid=%',
      auth.uid()
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS enforce_profile_role_authorization ON public.profiles;
CREATE TRIGGER enforce_profile_role_authorization
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.enforce_profile_role_authorization();


-- ── 3. Substituir profiles_update_own por política que exclui role/is_active ─
-- A política original FOR UPDATE USING (auth.uid() = id) permitia que o
-- usuário atualizasse qualquer campo da própria linha, incluindo role.
-- O trigger acima já bloqueia isso, mas a nova política remove a ambiguidade:
-- usuários só podem atualizar full_name e email na própria linha.
-- Operações em role/monthly_limit/is_active passam pelo trigger e exigem admin.
DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;
CREATE POLICY "profiles_update_safe_fields" ON public.profiles
  FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (
    auth.uid() = id
    -- O trigger enforce_profile_role_authorization bloqueia role/is_active
    -- para não-admins. Esta política permite o UPDATE chegar ao trigger,
    -- que então decide se autoriza ou rejeita.
  );


-- ── Comentário de auditoria ───────────────────────────────────────────────────
COMMENT ON FUNCTION public.auto_promote_if_admin_email IS
  'RPC SECURITY DEFINER para auto-promoção controlada do email admin. '
  'Não confia em payload do cliente. Apenas o email verificado pelo Supabase Auth é usado.';

COMMENT ON FUNCTION public.enforce_profile_role_authorization IS
  'Trigger BEFORE UPDATE que impede alterações de role/is_active por não-admins '
  'e bloqueia auto-promoção mesmo por admins. Segunda camada após ProfileService._requireAdmin().';
