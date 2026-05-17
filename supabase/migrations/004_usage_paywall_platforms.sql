-- Fase 1: segurança e rate limiting
-- Fase 2: campo is_pro para paywall
-- Fase 3: campos de hashtags e versões por plataforma

-- 1. is_pro em user_profiles
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS is_pro boolean NOT NULL DEFAULT false;

-- 2. Novos campos de IA em post_generations
ALTER TABLE post_generations
  ADD COLUMN IF NOT EXISTS suggested_hashtags text[]     DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS linkedin_version   text,
  ADD COLUMN IF NOT EXISTS instagram_version  text,
  ADD COLUMN IF NOT EXISTS twitter_version    text;

-- 3. Tabela de controle de uso mensal
CREATE TABLE IF NOT EXISTS generation_usage (
  user_id    uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  year_month text    NOT NULL,
  count      integer NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, year_month)
);

ALTER TABLE generation_usage ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users read own usage"
  ON generation_usage FOR SELECT
  USING (auth.uid() = user_id);

-- 4. Função atômica de verificação + incremento (roda com service role)
CREATE OR REPLACE FUNCTION check_and_increment_usage(
  p_user_id uuid,
  p_limit   integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_month   text    := to_char(now(), 'YYYY-MM');
  v_current integer;
BEGIN
  SELECT count INTO v_current
  FROM generation_usage
  WHERE user_id = p_user_id AND year_month = v_month;

  v_current := COALESCE(v_current, 0);

  IF v_current >= p_limit THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'count',   v_current,
      'limit',   p_limit
    );
  END IF;

  INSERT INTO generation_usage (user_id, year_month, count)
  VALUES (p_user_id, v_month, 1)
  ON CONFLICT (user_id, year_month) DO UPDATE
    SET count = generation_usage.count + 1;

  RETURN jsonb_build_object(
    'allowed', true,
    'count',   v_current + 1,
    'limit',   p_limit
  );
END;
$$;
