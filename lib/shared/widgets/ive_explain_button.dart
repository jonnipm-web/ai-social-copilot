import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'context_copilot_widget.dart' show showCopilotChat;
import '../../data/models/copilot_context_data.dart';
import '../../providers/ive_context_provider.dart';

/// Botão "Explicar com IVE" — qualquer componente pode adicionar.
///
/// Ao tocar, abre o chat da IVE já com a pergunta pre-enviada.
class IveExplainButton extends ConsumerWidget {
  final String question;
  final String screenName;
  final String? label;
  final bool compact;

  const IveExplainButton({
    super.key,
    required this.question,
    required this.screenName,
    this.label,
    this.compact = false,
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
    final ctx = ref.read(iveContextDataProvider).valueOrNull;
    final contextData = ctx != null ? CopilotContextData.fromIveContext(ctx) : CopilotContextData();
    showCopilotChat(
      context,
      screenName:     screenName,
      initialMessage: question,
      contextData:    contextData,
    );
  }
}
