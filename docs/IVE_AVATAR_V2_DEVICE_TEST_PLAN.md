# IVE Avatar V2 — Device Test Plan
**Fase 11G | Samsung Galaxy S25 Ultra (Android 16)**

> **Nota:** O APK de referência vem da branch `claude/ive-avatar-v2-build-recovery`
> (Fase 11G). O artifact da Fase 11F continha `DEBUG_APK_SHA=N/A` — APK não real.
> Usar exclusivamente o artifact gerado pelo CI da Fase 11G.

## Pré-requisitos

1. Instalar APK debug gerado pelo CI da Fase 11G (artifact `ive-avatar-v2-debug-apk`, branch `claude/ive-avatar-v2-build-recovery`)
2. Ativar opção de desenvolvedor no dispositivo
3. Garantir conta de teste com acesso ao Supabase de staging
4. Ativar override admin: Configurações → Inteligência e IVE → Avatar da IVE → **Avatar V2**

## Casos de teste no dispositivo

### Grupo 1 — Visibilidade básica

| # | Cenário | Ação | Esperado |
|---|---------|------|----------|
| T01 | Login screen | Abrir app sem sessão | Nenhum avatar visível |
| T02 | Após login | Entrar com conta de teste | Avatar aparece na dashboard |
| T03 | Logout | Sair da conta | Avatar desaparece |
| T04 | Rota proibida | Navegar para `/` (splash) | Avatar oculto |
| T05 | Rota autorizada | Navegar para `/projects` | Avatar visível |

### Grupo 2 — Override admin

| # | Cenário | Ação | Esperado |
|---|---------|------|----------|
| T06 | Selecionar Legacy | Override → Avatar legado | Avatar legado renderizado |
| T07 | Selecionar V2 | Override → Avatar V2 | Avatar V2 renderizado |
| T08 | Ocultar | Override → Ocultar | Nenhum avatar |
| T09 | Automático | Override → Automático | Segue flag remota (legacy por padrão) |
| T10 | Restart app | Reiniciar com override ativo | Override persiste |

### Grupo 3 — Interações

| # | Cenário | Ação | Esperado |
|---|---------|------|----------|
| T11 | Toque (idle) | Tocar no avatar em repouso | Abre chat da IVE |
| T12 | Arraste | Arrastar avatar para outro canto | Avatar segue o dedo, sem crash |
| T13 | Toque duplo rápido | Tocar 2x rapidamente | Abre chat apenas 1x |
| T14 | Abrir/fechar chat | 10 vezes seguidas | Sem crash, sem estado corrompido |
| T15 | Long press | Segurar avatar | Sem crash (sem ação definida = ok) |

### Grupo 4 — Estados operacionais

| # | Cenário | Ação | Esperado |
|---|---------|------|----------|
| T16 | Analisando | Criar novo projeto | Avatar → `analyzing` |
| T17 | Sucesso | Análise concluída | Avatar → `success` por ~3s → `idle` |
| T18 | Erro | Simular falha de rede | Avatar → `error` |
| T19 | Atenção | Nova oportunidade detectada | Avatar → `attention` |
| T20 | Voltando para idle | Aguardar após success | Avatar retorna para `idle` automaticamente |

### Grupo 5 — Layout e responsividade

| # | Cenário | Ação | Esperado |
|---|---------|------|----------|
| T21 | Portrait | Orientação padrão | Avatar no canto inferior direito |
| T22 | Landscape | Rotacionar o dispositivo | Avatar reposicionado, sem overflow |
| T23 | Teclado aberto | Abrir campo de texto | Avatar oculto ou reposicionado |
| T24 | Texto grande | Acessibilidade → fonte máxima | Avatar não sobrepõe texto |
| T25 | Modo reduzido | Reduzir animações no sistema | Avatar sem animações intensas |
| T26 | SafeArea | Arrastar para borda da tela | Avatar não sai da SafeArea |
| T27 | Barra de gestos | Navegação por gestos ativa | Avatar acima da zona de gestos |

### Grupo 6 — Nenhum avatar duplicado

| # | Cenário | Ação | Esperado |
|---|---------|------|----------|
| T28 | Decision Center | Navegar para `/ecosystem` | Apenas 1 avatar visível |
| T29 | Briefing | Navegar para `/ecosystem/briefing` | Apenas 1 avatar visível |
| T30 | Projects | Navegar para `/projects` | Apenas 1 avatar (sem duplicar com botões IVE da tela) |

### Grupo 7 — Badge de debug

| # | Cenário | Ação | Esperado |
|---|---------|------|----------|
| T31 | Produção | Qualquer tela com avatar | Sem texto "RIVE ASSET PENDING" |
| T32 | Showcase | Navegar para showcase (debug) | Badge pode aparecer (aceitável) |

## Aprovação

- [ ] Todos os casos T01–T32 executados
- [ ] Sem crash em nenhum cenário
- [ ] Sem avatar duplicado em nenhuma tela
- [ ] Sem texto técnico visível em produção
- [ ] PO aprovou visualmente o Avatar V2
- [ ] Comportamento de rollback confirmado (T09 funciona)

**Aprovação do PO:** `_______________ (data: ____/____/______)`
