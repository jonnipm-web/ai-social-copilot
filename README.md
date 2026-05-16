# AI Social Copilot

Copiloto de posts para redes sociais. O usuário digita um texto e recebe versões melhoradas, profissional, descontraída, persuasiva, sugestão de resposta a comentários e notas de clareza, impacto e engajamento.

---

## Stack

| Camada | Tecnologia |
|---|---|
| Frontend | Flutter |
| Estado | Riverpod |
| Navegação | GoRouter |
| Backend / Auth / DB | Supabase |
| IA | Anthropic Claude (via Edge Function) |

---

## Configuração do projeto

### 1. Pré-requisitos

- Flutter SDK ≥ 3.3
- Conta no [Supabase](https://supabase.com)
- Conta na [Anthropic](https://console.anthropic.com)
- [Supabase CLI](https://supabase.com/docs/guides/cli)

### 2. Clone e instale

```bash
cd ai_social_copilot
flutter pub get
```

### 3. Configure as variáveis de ambiente

Edite o arquivo `.env` na raiz do projeto:

```
SUPABASE_URL=https://SEU_PROJETO.supabase.co
SUPABASE_ANON_KEY=SUA_CHAVE_ANON
```

### 4. Crie a tabela e as políticas RLS no Supabase

No painel do Supabase → SQL Editor, execute os dois arquivos em ordem:

```
supabase/migrations/001_create_post_generations.sql
supabase/migrations/002_rls_post_generations.sql
```

### 5. Faça o deploy da Edge Function

```bash
supabase login
supabase link --project-ref SEU_PROJECT_REF

# Adiciona a chave da Anthropic como secret
supabase secrets set ANTHROPIC_API_KEY=sk-ant-...

# Deploy
supabase functions deploy improve-post
```

### 6. Execute o app

```bash
flutter run
```

---

## Estrutura de pastas

```
lib/
├── main.dart                        # Entry point
├── app.dart                         # MaterialApp + GoRouter
├── core/
│   ├── constants/app_constants.dart # Rotas e constantes
│   ├── theme/app_theme.dart         # Tema dark
│   └── utils/snackbar_utils.dart    # Helpers de feedback
├── data/
│   ├── models/post_generation.dart  # Modelo de dados
│   └── services/
│       ├── auth_service.dart        # Login, cadastro, logout
│       └── post_service.dart        # Edge Function + Supabase CRUD
├── providers/
│   ├── auth_provider.dart           # AuthNotifier + authStateProvider
│   └── post_provider.dart           # PostNotifier + historyProvider
├── features/
│   ├── splash/splash_screen.dart
│   ├── auth/screens/login_screen.dart
│   ├── home/screens/home_screen.dart
│   ├── result/screens/result_screen.dart
│   └── history/screens/
│       ├── history_screen.dart
│       └── history_detail_screen.dart
└── shared/widgets/
    ├── app_text_field.dart
    ├── loading_button.dart
    ├── result_block.dart            # Card de resultado com botão copiar
    └── score_chip.dart              # Badge colorido de nota

supabase/
├── migrations/
│   ├── 001_create_post_generations.sql
│   └── 002_rls_post_generations.sql
└── functions/
    └── improve-post/
        └── index.ts                 # Edge Function (Deno)
```

---

## Contrato da Edge Function

**POST** `{SUPABASE_URL}/functions/v1/improve-post`

Headers:
```
Authorization: Bearer {SUPABASE_ANON_KEY}
Content-Type: application/json
```

Corpo:
```json
{ "text": "seu texto aqui" }
```

Resposta:
```json
{
  "improved_text": "...",
  "professional_version": "...",
  "casual_version": "...",
  "persuasive_version": "...",
  "comment_reply": "...",
  "scores": {
    "clarity": 8.5,
    "impact": 7.0,
    "engagement": 9.0
  }
}
```

---

## Modelo de dados

Tabela: `post_generations`

| Campo | Tipo | Descrição |
|---|---|---|
| id | uuid PK | Gerado automaticamente |
| user_id | uuid FK | Referencia `auth.users(id)` |
| original_text | text | Texto digitado pelo usuário |
| improved_text | text | Versão melhorada pela IA |
| professional_version | text | Versão profissional |
| casual_version | text | Versão descontraída |
| persuasive_version | text | Versão persuasiva |
| comment_reply | text | Sugestão de resposta a comentários |
| clarity_score | numeric(4,1) | Nota 0–10 |
| impact_score | numeric(4,1) | Nota 0–10 |
| engagement_score | numeric(4,1) | Nota 0–10 |
| created_at | timestamptz | Data de criação |

RLS ativa: cada usuário acessa apenas seus próprios registros.

---

## Fluxo completo

```
Splash → verifica sessão
  ├── sem sessão → Login/Cadastro → Home
  └── com sessão → Home

Home → digita texto → "Melhorar post"
  └── Edge Function improve-post (Anthropic Claude)
      └── Result Screen
          ├── 5 blocos com botão copiar
          ├── 3 scores coloridos
          └── botão Salvar → post_generations (Supabase)

Home → ícone Histórico → History Screen
  └── toque no item → History Detail Screen
```
