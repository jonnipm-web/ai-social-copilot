# UX Fixes — Sprint P0

**Data:** 2026-07-29

---

## 1. BottomSheets — Conteúdo Completo Visível (P0-01)

**Problema:** Explicações da IVE eram cortadas na metade da tela, sem scroll.

**Solução:**
- `useSafeArea: true` em todos os `showModalBottomSheet` calls → conteúdo não é cortado por navegação ou notch
- `initialChildSize: 0.75`, `maxChildSize: 0.95` → sheet ocupa mais espaço por padrão
- `_ProjectPickerSheet` envolvida em `DraggableScrollableSheet` com `SingleChildScrollView`

**Resultado:** Usuário vê a resposta completa e pode fazer scroll para mais conteúdo.

---

## 2. Avatar IVE Ausente em Contextos Indevidos (P0-02 / P0-09)

**Problema:** O avatar flutuante da IVE aparecia na tela de login e splash, confundindo usuários não autenticados.

**Solução:** `IveOverlay` verifica a rota atual via `iveRouteNotifier`. Se a rota for `/login`, `/` ou vazia, retorna `SizedBox.shrink()` (invisível).

**Resultado:** Login mostra apenas branding. IVE aparece somente depois da autenticação.

---

## 3. IVE com Resposta Honesta (P0-03)

**Problema:** Mesmo sem nenhum projeto ou dado configurado, a IVE tentava responder às perguntas com respostas genéricas sem valor.

**Solução:** Quando `CopilotContextData.isEmpty`, a IVE responde localmente:
> "Ainda não possuo dados suficientes... O que falta: • Adicionar projetos • Executar análises • Registrar ações"

**Resultado:** O usuário recebe orientação clara sobre o que configurar, não uma resposta vaga.

---

## 4. Recomendações com Contexto de Projeto (P0-04)

**Problema:** Cards de recomendação no Decision Center não mostravam de qual projeto a recomendação se originava.

**Solução:** `_RecCard` agora exibe `Projeto: [entityName]` abaixo do título quando disponível. O detail sheet inclui "Projeto" nos itens de evidência.

**Resultado:** Usuário entende imediatamente qual projeto cada recomendação afeta.

---

## 5. Desbloqueio com Explicação de Impacto (P0-05)

**Problema:** Cards bloqueados mostravam apenas "BLOQUEADO" e os motivos, sem motivação para desbloquear.

**Solução:** Adicionada seção "Ao desbloquear:" com o impacto esperado da recomendação.

**Resultado:** Usuário sabe o que ganha ao resolver cada bloqueio.

---

## 6. Strings em Português (P0-12)

**Problema:** Termos em inglês misturados na UI causavam estranheza: "Decision Center", "OPPORTUNITY SCORE", "Learning Score", etc.

**Solução:**
- "Decision Center" → "Central de Decisões" (drawer, home, dashboard, tela)
- "OPPORTUNITY SCORE" → "PONTUAÇÃO DE OPORTUNIDADE"
- "Learning Score" (chip) → "Aprendizado"
- "Knowledge Coverage" (gate label) → "Cobertura de Conhecimento"
- "Learning Score" (gate label) → "Índice de Aprendizado"
- "Intelligence Profile" (gate label) → "Perfil de Inteligência"

**Resultado:** UI consistentemente em português para o usuário.

---

## 7. Mensagens de Erro Amigáveis (P0-11)

**Problema:** Erros técnicos como "FunctionException: 429 Too Many Requests (Groq rate limit)" apareciam diretamente na UI.

**Solução:**
- `_friendlyError()` no copilot provider converte exceções técnicas em frases simples
- `_sanitizeDebugError()` no debug hub trunca erros na primeira linha

**Exemplo de transformação:**
- Antes: `FunctionException: status=429, body={"error":"rate_limit_exceeded"...}`
- Depois: `Serviço temporariamente indisponível. Tente novamente em alguns instantes.`
