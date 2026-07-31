# IVE Avatar Admin Override
**Fase 11F | Branch:** `claude/ive-avatar-v2-production-integration`

## Localização na UI

```
Configurações
  └── Inteligência e IVE
        └── Avatar da IVE (apenas admin/debug)
```

## Opções disponíveis

| Opção | `IveAvatarLocalOverride` | Efeito |
|-------|--------------------------|--------|
| Automático | `automatic` | Segue feature flag remota |
| Avatar legado | `legacy` | Força legado independente da flag |
| Avatar V2 | `v2` | Força V2 independente da flag |
| Ocultar avatar | `hidden` | Oculta o avatar neste dispositivo |

## Regras

- **Persistência**: `SharedPreferences` key `ive_avatar_local_override`
- **Escopo**: somente dispositivo local, não afeta outros usuários
- **Disponibilidade**: apenas `kDebugMode == true` ou usuário com role `admin`
- **Indicador**: UI mostra claramente quando override está ativo (≠ `automatic`)
- **Restaurar**: botão "Automático" ou limpar SharedPreferences

## Informações exibidas no painel admin

- Versão atualmente ativa: Legacy / V2 / Oculto
- Feature flag remota: `ive_avatar_v2_enabled` (valor e origem)
- Override local: valor atual
- Estado atual do avatar: `IveAvatarStateV2.name`
- Motivo de ocultamento (quando hidden): rota, auth, override, etc.
- Botão "Abrir showcase do Avatar V2" (apenas debug)

## Garantias de segurança

- Não aparece para usuário comum em release build
- Não modifica a feature flag remota no Supabase
- Não persiste entre reinstalações do app
- Rollback imediato: selecionar "Automático" restaura comportamento padrão
