-- Habilita Row Level Security
alter table public.post_generations enable row level security;

-- Leitura: usuário só lê seus próprios registros
create policy "select_own"
  on public.post_generations
  for select
  using (auth.uid() = user_id);

-- Inserção: usuário só insere com seu próprio user_id
create policy "insert_own"
  on public.post_generations
  for insert
  with check (auth.uid() = user_id);

-- Deleção: usuário só apaga seus próprios registros (segurança defensiva)
create policy "delete_own"
  on public.post_generations
  for delete
  using (auth.uid() = user_id);
