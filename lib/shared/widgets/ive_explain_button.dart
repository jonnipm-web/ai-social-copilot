import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'context_copilot_widget.dart' show showCopilotChat;
import '../../data/models/copilot_context_data.dart';
import '../../data/models/ive_interaction_request.dart';
import '../../providers/ive_context_provider.dart';

/// Botão "Explicar com IVE" — qualquer componente pode adicionar.
///
/// Ao tocar, abre o chat da IVE já com a pergunta pre-enviada.
///
/// IVE-COMMERCIAL-FOUNDATION-11 — [projectId]/[sourceModule]/
/// [sourceEntityType]/[sourceEntityId] são OPCIONAIS e todos `null` por
/// padrão: um chamador que não sabe a qual projeto o texto se refere
/// (ex.: a narrativa de saúde do ecossistema, que é system-wide por
/// natureza) continua funcionando exatamente como antes — apenas
/// chamadores que SABEM o projeto em foco (ex.: um card por-projeto)
/// agora podem passá-lo, fechando o vazamento de contexto descrito em
/// docs/commercial/PROJECT_CONTEXT_CONTRACT.md sem exigir mudança em
/// nenhum outro call site.
class IveExplainButton extends ConsumerWidget {
  final String question;
  final String screenName;
  final String? label;
  final bool compact;
  final String? projectId;
  final String? sourceModule;
  final String? sourceEntityType;
  final String? sourceEntityId;

  const IveExplainButton({
    super.key,
    required this.question,
    required this.screenName,
    this.label,
    this.compact = false,
    this.projectId,
    this.sourceModule,
    this.sourceEntityType,
    this.sourceEntityId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (compact) {
      return GestureDetector(
        onTap: () => _open(context, ref),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💬', style: TextStyle(fontSize: 12)),
            const SizedBox(width: 3),
            Text(
              label ?? 'Entender',
              style: const TextStyle(
                color:      Color(0xFF9B8FFF),
                fontSize:   11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF9B8FFF),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFF6C63FF), width: 0.8),
        ),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: const Text('💬', style: TextStyle(fontSize: 13)),
      label: Text(label ?? 'Explicar com IVE', style: const TextStyle(fontSize: 12)),
      onPressed: () => _open(context, ref),
    );
  }

  // IVE-COMMERCIAL-TARGETED-REMEDIATION-04 (achado do Codex Gate, 2ª
  // rodada) — este era um dos vários pontos de entrada do chat que a
  // consolidação inicial desta missão não tinha encontrado: chamava
  // showCopilotChat() sem NENHUM contextData, caindo no
  // CopilotContextData() vazio padrão do próprio showCopilotChat.
  // Mesma fonte (iveContextDataProvider) e mesma conversão
  // (CopilotContextData.fromIveContext) usadas em todos os outros pontos
  // de entrada agora.
  void _open(BuildContext context, WidgetRef ref) {
    final ctx = ref.read(iveContextDataProvider(projectId)).valueOrNull;
    final contextData = ctx != null ? CopilotContextData.fromIveContext(ctx) : const CopilotContextData();
    showCopilotChat(
      context,
      screenName:     screenName,
      initialMessage: question,
      contextData:    contextData,
      request: IveInteractionRequest(
        projectId:        projectId,
        sourceModule:     sourceModule ?? screenName,
        sourceEntityType: sourceEntityType,
        sourceEntityId:   sourceEntityId,
        operationType:    IveOperationType.explain,
      ),
    );
  }
}
