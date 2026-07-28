# DESKTOP RESPONSIVE AUDIT
## AI Social Copilot → InsightValues Business OS
### Data: 2026-07-28

---

## PROBLEMAS IDENTIFICADOS E STATUS

| # | Problema | Tela | Status |
|---|----------|------|--------|
| 1 | Cards do Business OS vazios ou com apenas um número | Executive Dashboard | ✅ Corrigido |
| 2 | Nome "Aurora" visível como agente | Multiple screens | ✅ Corrigido → "Iris" |
| 3 | "AI Social Copilot OS" visível no header | Home Screen | ✅ Corrigido → "InsightValues" |
| 4 | "AI Social Copilot" como nome do app | App Constants | ✅ Corrigido → "InsightValues" |
| 5 | Campos concatenados sem espaçamento no Project Center | Project Command Center | ✅ Corrigido |
| 6 | Valores R$ 0 onde não calculados | Project Cards e Detail Sheet | ✅ Corrigido → "Ainda não estimado" |
| 7 | "0d" no prazo quando não definido | Project Cards | ✅ Corrigido → "—" |
| 8 | IVE flutuante sobrepõe conteúdo no desktop | IVE Overlay | ✅ Corrigido — margem segura no desktop |
| 9 | Briefing Executivo ocupa área pequena no desktop | Weekly Briefing Screen | ✅ Corrigido — layout 2 colunas |
| 10 | Grandes áreas vazias sem estado explicativo | Executive Dashboard | ✅ Corrigido — empty states com ação |
| 11 | Cards não deixam claro se são clicáveis | Executive Dashboard | ✅ Corrigido — cursor pointer + hover |
| 12 | Saúde 26/100 sem causa e ação corretiva | Weekly Briefing | ✅ Corrigido — HealthSideCard com aviso |

---

## BREAKPOINTS IMPLEMENTADOS

```
MOBILE    < 600px   → 1 coluna, layout compacto
TABLET   600-1024px → 2 colunas, KPI grid expandido  
DESKTOP 1024-1440px → 2 colunas (main 70% + sidebar 30%)
WIDE    > 1440px    → 2 colunas, maxWidth: 1400px centralizado
```

---

## IDENTITY CHANGES

| Antes | Depois | Arquivo |
|-------|--------|---------|
| AI Social Copilot | InsightValues | app_constants.dart |
| AI Social Copilot OS | InsightValues | home_screen.dart |
| Aurora (advisor name) | Iris | advisor_profile.dart, advisor_onboarding_screen.dart |
| Personal AI Advisor | — (não alterado — genérico) | advisor_onboarding_screen.dart |

### Identidade visual aprovada
- **Produto**: InsightValues
- **Sistema**: Business OS
- **Agente IA**: IVE (único agente visível ao usuário)
- **Nomes de advisor internos**: Atlas, Iris, Mentor, Nexus (sem Aurora)

---

## TELAS MODIFICADAS

### 1. executive_dashboard_screen.dart
- **Antes**: KPI grid com 4 tiles simples, muitos vazios
- **Depois**: 4 Executive Module Cards responsivos com dados reais por módulo
  - Projetos: total, ativos, em ideia, sem análise
  - Market Intelligence: análises, score médio, alta qualidade
  - Oportunidades: total, alta prioridade, aprovadas, pendentes
  - Action Engine: pendentes, em execução, bloqueadas, concluídas
- **Layout desktop**: main column (7/10) + sidebar (3/10) com KPIs e acesso rápido
- **Empty states**: mensagem explicativa + CTA quando módulo vazio

### 2. weekly_briefing_screen.dart
- **Antes**: ListView single-column em qualquer tamanho
- **Depois**: LayoutBuilder com 2 colunas no desktop
  - Coluna principal: O que mudou, cresceu, piorou, priorizar, pausar, oportunidades
  - Coluna lateral (300px): HealthSideCard + riscos
- **HealthSideCard**: score visual + aviso quando < 50

### 3. ive_overlay.dart
- **Antes**: posição fixa sem considerar tamanho de tela
- **Depois**: 
  - Desktop (≥ 1024px): posição padrão bottom-right com margem extra (88px da borda)
  - Clamp máximo Y ajustado para não ultrapassar zona segura (height - 140 - safeBottom)

### 4. project_command_center_screen.dart
- `_fmtRevenue(0)` → "Não estimado" / "Ainda não estimado"
- `timeToRevenueDays = 0` → "—" (em vez de "0d")
- Prazo > 365 dias → "Xa" (anos), > 30 dias → "Xm" (meses)

### 5. app_constants.dart
- `appName = 'InsightValues'`

### 6. home_screen.dart
- Header: "AI Social Copilot OS" → "InsightValues"

---

## PRÓXIMOS PASSOS RECOMENDADOS

1. **Hover states** em todos os cards do Decision Center (já clicáveis via FASE 7)
2. **Tooltip** em cada métrica explicando fonte e metodologia
3. **Comparação semanal** no Briefing (esta semana vs semana anterior)
4. **FASE 4** — IVE Discovery Interview para perfis incompletos
