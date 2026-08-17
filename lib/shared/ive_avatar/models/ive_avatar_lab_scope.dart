import 'package:flutter/material.dart';

import 'ive_avatar_state_v2.dart';

// ── IveAvatarLabScope ─────────────────────────────────────────────────────────
//
// InheritedWidget usado exclusivamente no lab/showcase do Avatar V2.
// Não referenciado em código de produção.
// Quando presentationMode = true, suprime badges de desenvolvedor e elementos
// técnicos para uma avaliação limpa pelo Product Owner.

class IveAvatarLabScope extends InheritedWidget {
  final bool presentationMode;

  const IveAvatarLabScope({
    super.key,
    required this.presentationMode,
    required super.child,
  });

  static bool isPresentationMode(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<IveAvatarLabScope>()
            ?.presentationMode ??
        false;
  }

  @override
  bool updateShouldNotify(IveAvatarLabScope old) =>
      old.presentationMode != presentationMode;
}

// ── Famílias de estados ───────────────────────────────────────────────────────
//
// Agrupa os 14 estados do IveAvatarStateV2 em famílias semânticas para
// apresentação organizada no showcase de aprovação.

typedef IveStateFamily = ({
  String label,
  Color color,
  List<IveAvatarStateV2> states,
});

const kIveStateFamilies = <IveStateFamily>[
  (
    label: 'Repouso',
    color: Color(0xFF6C63FF),
    states: [
      IveAvatarStateV2.idle,
      IveAvatarStateV2.waitingForUser,
      IveAvatarStateV2.offline,
      IveAvatarStateV2.disabled,
    ],
  ),
  (
    label: 'Processamento',
    color: Color(0xFF00C6FF),
    states: [
      IveAvatarStateV2.thinking,
      IveAvatarStateV2.analyzing,
      IveAvatarStateV2.researching,
      IveAvatarStateV2.generating,
    ],
  ),
  (
    label: 'Interação',
    color: Color(0xFF4DA6FF),
    states: [
      IveAvatarStateV2.listening,
      IveAvatarStateV2.speaking,
    ],
  ),
  (
    label: 'Resultado',
    color: Color(0xFF00E875),
    states: [
      IveAvatarStateV2.success,
      IveAvatarStateV2.error,
      IveAvatarStateV2.warning,
      IveAvatarStateV2.attention,
    ],
  ),
];
