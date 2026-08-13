# SHOW-00 — Repository Boundary Decision
## InsightValues™ Showcase — Análise de Arquitetura de Repositório

**Data:** 2026-08-13  
**Status:** DECISÃO ARQUITETURAL — Aguarda aprovação antes de implementação

---

## 1. QUESTÃO CENTRAL

O InsightValues Showcase deve ser:

A. uma aplicação independente que **replica** capacidades  
B. uma aplicação independente que **consome** capacidades compartilhadas  
C. uma **configuração** do produto principal  
D. outra arquitetura  

**Resposta fundamentada no código real encontrado — ao final desta análise.**

---

## 2. ESTADO REAL DO REPOSITÓRIO ATUAL

**Repositório:** `jonnipm-web/ai-social-copilot`  
**Natureza:** Aplicação Flutter monolítica + Supabase backend

**O que o repositório atual NÃO é:**
- Não é um monorepo (sem packages/, sem workspace de Dart/Flutter)
- Não é uma biblioteca consumível (sem SDK público)
- Não expõe API REST própria (tudo vai direto ao Supabase)
- Não tem separation of concerns entre "core engine" e "produto principal"

**O que existe de reutilizável:**
- Edge Functions Supabase (17 funções — acessíveis por qualquer cliente autenticado)
- Database schema + RLS (acessível por qualquer cliente Supabase com credenciais)
- Models Dart (apenas dentro do Flutter app)
- Services Dart (apenas dentro do Flutter app)
- IVE visual system (apenas dentro do Flutter app)

---

## 3. ANÁLISE DAS OPÇÕES

### OPÇÃO A — Showcase dentro do repositório principal (feature flag / flavor)

```
ai-social-copilot/
  lib/
    features/
      showcase/          ← nova feature isolada
        screens/
        providers/
    ...
  lib/main_showcase.dart ← entry point alternativo
```

| Critério | Análise |
|---|---|
| **Coupling** | ALTO — Showcase compartilha todo o estado do app principal |
| **Duplication** | BAIXA — reutiliza tudo |
| **Security** | RISCO — mesma base de código exposta; prompts proprietários no mesmo repo |
| **Release independence** | BAIXA — versão do Showcase amarrada ao produto principal |
| **Reuse** | ALTA — todos os services, providers, models disponíveis |
| **CI/CD** | SIMPLES — um pipeline |
| **Demo reliability** | RISCO — falha no produto afeta o Showcase |
| **Maintenance** | MÉDIO — features de Showcase poluem o app principal |
| **Open-source exposure** | RISCO CRÍTICO — lógica proprietária no mesmo repo |
| **Hackathon submission** | SIMPLES — um repo para submeter |
| **Enterprise evolution** | RUIM — Showcase misturado ao produto comercial |

**Recomendação:** NÃO RECOMENDADO como arquitetura final. Aceitável como protótipo temporário.

---

### OPÇÃO B — Showcase como repositório independente

```
jonnipm-web/
  ai-social-copilot/         ← produto principal (atual)
  insightvalues-showcase/    ← repositório independente
    lib/
      ...consome Supabase Edge Functions e DB...
```

| Critério | Análise |
|---|---|
| **Coupling** | BAIXO — consome APIs, não código |
| **Duplication** | ALTA — models, services, UI components reescritos |
| **Security** | MELHOR — IP proprietário permanece no repo principal |
| **Release independence** | ALTA — versiona independentemente |
| **Reuse** | BAIXA — sem shared packages |
| **CI/CD** | DOIS pipelines independentes |
| **Demo reliability** | MELHOR — pode ter dataset e fallbacks próprios |
| **Maintenance** | RISCO — dois repos com lógica similar evoluindo separadamente |
| **Open-source exposure** | MELHOR — pode ser público sem expor core |
| **Hackathon submission** | DIRETO — repo dedicado ao Showcase |
| **Enterprise evolution** | BOM — Showcase tem ciclo de vida próprio |

**Recomendação:** RECOMENDADO para fase de Showcase público. Requer investimento em SDK compartilhado.

---

### OPÇÃO C — Monorepo

```
insightvalues/               ← monorepo (novo repositório raiz)
  packages/
    ive_core/                ← Engine compartilhado
    ive_ui/                  ← Componentes visuais compartilhados
    ive_models/              ← Models compartilhados
  apps/
    insightvalues/           ← produto principal
    showcase/                ← Showcase
  supabase/                  ← backend compartilhado
```

| Critério | Análise |
|---|---|
| **Coupling** | CONTROLADO — shared packages explícitos |
| **Duplication** | MÍNIMA — packages compartilhados |
| **Security** | BOM — packages podem ser versionados separadamente |
| **Release independence** | BOA — apps independentes |
| **Reuse** | MÁXIMA |
| **CI/CD** | COMPLEXO — Melos ou Nx necessário |
| **Demo reliability** | BOA — showcase tem config independente |
| **Maintenance** | MELHOR a longo prazo |
| **Open-source exposure** | CONTROLADO — packages escolhidos podem ser públicos |
| **Hackathon submission** | COMPLEXO — sub-repo ou workspace para submissão |
| **Enterprise evolution** | EXCELENTE |

**Recomendação:** IDEAL para longo prazo. Prematura agora — requer migração completa.

---

### OPÇÃO D — Shared packages + separate applications (híbrida)

```
ai-social-copilot/           ← produto principal (repositório atual)
  packages/
    ive_sdk/                 ← SDK extraído do core
      lib/
        models/
        services/
        ive/
insightvalues-showcase/      ← repositório independente
  pubspec.yaml
    dependencies:
      ive_sdk:
        git:
          url: https://github.com/jonnipm-web/ai-social-copilot
          path: packages/ive_sdk
```

| Critério | Análise |
|---|---|
| **Coupling** | MÉDIO — SDK como contrato explícito |
| **Duplication** | BAIXA — SDK compartilhado |
| **Security** | BOM — SDK pode ser público sem expor app inteiro |
| **Release independence** | BOA — showcase referencia versão do SDK |
| **Reuse** | ALTA — apenas o necessário |
| **CI/CD** | DOIS pipelines + versionamento do SDK |
| **Demo reliability** | BOA |
| **Maintenance** | MÉDIO — SDK precisa de versionamento |
| **Open-source exposure** | CONTROLADO |
| **Hackathon submission** | SIMPLIFICADO — showcase repo é suficiente |
| **Enterprise evolution** | BOA |

**Recomendação:** RECOMENDADO como evolução natural da Opção B.

---

## 4. DECISÃO RECOMENDADA

### Fase atual (SHOW-00 a SHOW-05): OPÇÃO A + CONTENÇÃO

**Por quê:** O produto principal ainda está evoluindo rapidamente. Criar um repositório separado agora resultaria em duplicação massiva e divergência imediata. A prioridade é validar as capacidades arquiteturais antes de separar.

**Como implementar com contenção:**
- Criar `lib/features/showcase/` no repositório atual
- Showcase usa feature flag `showcase_mode_enabled`
- Entry point alternativo: `lib/main_showcase.dart`
- Dados de demonstração identificados com prefixo `[DEMO]` ou campo `is_demo: true`
- NÃO expor prompts proprietários
- CI/CD separado para build do Showcase (flavor)

**Restrição crítica:** Showcase dentro do repo principal é estratégia temporária. Não deve durar além de SHOW-05.

---

### Fase madura (SHOW-06+): OPÇÃO B → OPÇÃO D

**Sequência de migração:**

1. Extrair `packages/ive_sdk/` do repositório atual com:
   - Models (apenas os essenciais para Showcase)
   - Core IVE (IveState, IveEvent, IveMemory, IveAvatar)
   - Supabase client wrapper
   - Edge Function contracts (interfaces TypeScript)

2. Criar repositório `insightvalues-showcase` independente consumindo o SDK via git reference

3. Showcase tem seu próprio:
   - Dataset de demonstração (identificado como demo)
   - Cache de análises para fallback offline
   - Feature flags próprias
   - CI/CD e release cycle independente

---

## 5. PUBLIC SHOWCASE BOUNDARY vs PRIVATE INTELLIGENCE CORE

### O que pode ser público no Showcase:
- IVE Visual System (IveAvatar, IveVisualState, visual runtime)
- UI/UX do fluxo decisório
- Models genéricos (Project, Decision, Evidence)
- Dados de demonstração identificados como sample
- Edge Function contracts (schema de entrada/saída)

### O que deve permanecer privado (PRIVATE INTELLIGENCE CORE):
- Algoritmos de scoring (EcosystemIntelligenceService, ProjectIntelligenceService)
- Prompts de todas as Edge Functions
- Estratégias do Quant (quando disponível)
- Dados de clientes reais
- Implementação de auto bootstrap
- Lógica de decision validation

---

## 6. RESPOSTA FINAL À QUESTÃO CENTRAL

> O InsightValues Showcase deve ser: **(B) uma aplicação independente que consome capacidades compartilhadas**

Fundamentação no código real:
- O backend (Supabase Edge Functions) é naturalmente acessível por qualquer cliente autenticado
- Não há lógica de negócio no lado Flutter que não possa ser reproduzida com os mesmos Edge Functions
- A separação protege IP proprietário (prompts, algoritmos de scoring)
- A Opção B permite que o Showcase tenha lifecycle independente (demo dataset, release cycle, apresentações)

**Caminho prático:** Opção A temporária → Opção B + SDK compartilhado (Opção D)

---

## 7. RECOMENDAÇÃO PARA SHOW-01

Iniciar com **Opção A** (feature no repositório atual) com as seguintes restrições:

1. Todo código do Showcase em `lib/features/showcase/` (sem vazamento para outras features)
2. Feature flag `showcase_mode_enabled` controlando acesso
3. Entry point `lib/main_showcase.dart` para build de Showcase
4. Dados de demo em `lib/features/showcase/demo/` com identificação explícita
5. Documentar na Capability Gap Matrix quais capacidades são reutilizadas vs criadas
6. NÃO fazer deploy do Showcase como build de produção do app principal
