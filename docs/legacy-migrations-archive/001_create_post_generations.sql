-- Criação da tabela principal do MVP
create table public.post_generations (
  id                   uuid primary key default gen_random_uuid(),
  user_id              uuid not null references auth.users(id) on delete cascade,
  original_text        text not null,
  improved_text        text not null,
  professional_version text not null,
  casual_version       text not null,
  persuasive_version   text not null,
  comment_reply        text not null,
  clarity_score        numeric(4,1) not null check (clarity_score    between 0 and 10),
  impact_score         numeric(4,1) not null check (impact_score     between 0 and 10),
  engagement_score     numeric(4,1) not null check (engagement_score between 0 and 10),
  created_at           timestamptz not null default now()
);

-- Índice para listagem do histórico por usuário, mais recente primeiro
create index post_generations_user_created
  on public.post_generations (user_id, created_at desc);
