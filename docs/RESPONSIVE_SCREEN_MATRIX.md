# RESPONSIVE SCREEN MATRIX
## InsightValues Business OS — Layout por Breakpoint
### Data: 2026-07-28

---

## BREAKPOINTS

| Sigla | Intervalo | Dispositivos típicos |
|-------|-----------|---------------------|
| M     | < 600px   | Smartphones (360-599px) |
| T     | 600-1023px| Tablets, small laptops |
| D     | 1024-1439px| Desktops, laptops |
| W     | ≥ 1440px  | Wide desktops, ultrawide |

---

## MATRIZ POR TELA

### Business OS — Executive Dashboard

| Componente | M | T | D | W |
|------------|---|---|---|---|
| Module Cards | 1 coluna vertical | 2×2 grid | 4 em linha | 4 em linha (max 1400px) |
| Sidebar KPIs | Abaixo do conteúdo | Abaixo do conteúdo | Coluna direita 320px | Coluna direita 320px |
| Quick Nav | Abaixo dos KPIs | Abaixo dos KPIs | Sidebar | Sidebar |
| Module Grid (atalhos) | 3 colunas | 3 colunas | 3 colunas | 3 colunas |
| Executive Recommendations | Full width | Full width | Full width (main col) | Full width (main col) |
| Pending Actions | Full width | Full width | Full width (main col) | Full width (main col) |
| H-Padding | 16px | 16px | 32px | 32px |
| Max Width | ∞ | ∞ | ∞ | 1400px |

### Briefing Executivo Semanal

| Componente | M | T | D | W |
|------------|---|---|---|---|
| Header | Full width | Full width | Full width | Full width (max 1400px) |
| Data Origin Card | Full width | Full width | Full width | Full width |
| Resumo Executivo | Full width | Full width | Full width | Full width |
| Seções principais | 1 coluna | 1 coluna | Col. esq. (7/10) | Col. esq. (7/10) |
| Health + Riscos | Inline | Inline | Col. dir. 300px | Col. dir. 300px |
| H-Padding | 16px | 16px | 32px | 32px |

### Project Command Center

| Componente | M | T | D | W |
|------------|---|---|---|---|
| Project List | 1 coluna | 1 coluna | 1 coluna | 1 coluna |
| Project Cards | Full width | Full width | Full width | Full width (max 700px) |
| Stat Chips | Row (3 chips) | Row (3 chips) | Row (3 chips) | Row (3 chips) |
| Detail Sheet | Bottom sheet (65%) | Bottom sheet (65%) | Bottom sheet (65%) | Bottom sheet (65%) |
| Intelligence Profile | Seção na sheet | Seção na sheet | Seção na sheet | Seção na sheet |

### IVE Overlay

| Componente | M | T | D | W |
|------------|---|---|---|---|
| Posição padrão | Bottom-right -80, -200 | Bottom-right -80, -200 | Bottom-right -88, -220 | Bottom-right -88, -220 |
| Safe area bottom | Sim (MediaQuery) | Sim | Sim +extra margin | Sim +extra margin |
| Clamp Y max | height - 100 | height - 100 | height - 140 - safeBottom | height - 140 - safeBottom |
| Bubble max width | 220px | 220px | 220px | 220px |
| Draggable | Sim | Sim | Sim | Sim |

### Decision Center (Executive Decision Center)

| Componente | M | T | D | W |
|------------|---|---|---|---|
| Score Cards | Full width | Full width | Full width | Full width |
| TOP5 Cards | 1 col por seção | 1 col por seção | 1 col por seção | 1 col por seção |
| SimpleCard | Clicável + chevron | Clicável + chevron | Hover + cursor pointer | Hover + cursor pointer |
| Detail Sheet | Bottom sheet | Bottom sheet | Bottom sheet | Bottom sheet |

---

## VALORES AUSENTES — REGRAS DE EXIBIÇÃO

| Campo | Valor zero/null | Exibir como |
|-------|----------------|-------------|
| revenuePotential | 0 ou null | "Ainda não estimado" (detail) / "Não estimado" (card) |
| timeToRevenueDays | 0 ou null | "—" |
| roiGlobal | 0 | "Ainda não estimado" |
| opportunityScore | 0 | "—" |
| ecosystemScore | ausente | Não exibir badge |
| avgScore (MI) | 0 | "—" |

---

## TELAS A IMPLEMENTAR — ROADMAP RESPONSIVO

| Tela | Status | Prioridade |
|------|--------|-----------|
| Executive Dashboard | ✅ Responsivo | — |
| Weekly Briefing | ✅ Responsivo | — |
| Project Command Center | ✅ Valores corrigidos | — |
| IVE Overlay | ✅ Desktop safe area | — |
| Decision Center | ✅ Cards clicáveis | — |
| Market Intelligence Hub | ⬜ Mobile-only layout | Alta |
| Opportunity Lab | ⬜ Mobile-only layout | Média |
| Action Engine | ⬜ Mobile-only layout | Média |
| ROI Tracker | ⬜ Mobile-only layout | Baixa |
| Knowledge Vault | ⬜ Mobile-only layout | Baixa |
