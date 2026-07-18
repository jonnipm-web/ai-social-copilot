import 'package:flutter/material.dart';

import 'context_copilot_widget.dart' show openIveChat;

/// Botão "Explicar com IVE" — qualquer componente pode adicionar.
///
/// Ao tocar, abre o chat da IVE já com a pergunta pre-enviada.
class IveExplainButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (compact) {
      return GestureDetector(
        onTap: () => _open(context),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💬', style: TextStyle(fontSize: 12)),
            const SizedBox(width: 3),
            Text(
              label ?? 'Entender',
              style: const TextStyle(
                color: Color(0xFF9B8FFF),
                fontSize: 11,
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
      label: Text(label ?? 'Explicar com IVE',
          style: const TextStyle(fontSize: 12)),
      onPressed: () => _open(context),
    );
  }

  void _open(BuildContext context) {
    openIveChat(
      context,
      screenName: screenName,
      initialMessage: question,
    );
  }
}
