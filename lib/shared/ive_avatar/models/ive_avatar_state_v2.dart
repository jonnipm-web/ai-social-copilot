import 'package:flutter/material.dart';

// ── V2 State Enum ─────────────────────────────────────────────────────────────

enum IveAvatarStateV2 {
  idle,
  listening,
  thinking,
  analyzing,
  researching,
  generating,
  speaking,
  success,
  warning,
  error,
  offline,
  disabled,
  attention,
  waitingForUser,
}

// ── Per-state visual config ───────────────────────────────────────────────────

class IveAvatarStateConfigV2 {
  final Color  ringColor;
  final Color  glowColor;
  final double glowIntensity;
  final Color  overlayColor;
  final double overlayOpacity;
  final int    stateIndex;
  final Duration animationDuration;
  final double   animationIntensity;
  final String   semanticLabel;
  final String   fallbackLabel;
  final RepeatPolicy repeatPolicy;

  const IveAvatarStateConfigV2({
    required this.ringColor,
    required this.glowColor,
    required this.glowIntensity,
    required this.overlayColor,
    required this.overlayOpacity,
    required this.stateIndex,
    required this.animationDuration,
    required this.animationIntensity,
    required this.semanticLabel,
    required this.fallbackLabel,
    this.repeatPolicy = RepeatPolicy.loop,
  });

  static IveAvatarStateConfigV2 forState(IveAvatarStateV2 state) {
    switch (state) {
      case IveAvatarStateV2.idle:
        return const IveAvatarStateConfigV2(
          ringColor:         Color(0xFF6C63FF),
          glowColor:         Color(0xFF6C63FF),
          glowIntensity:     0.30,
          overlayColor:      Color(0xFF6C63FF),
          overlayOpacity:    0.0,
          stateIndex:        0,
          animationDuration: Duration(milliseconds: 2400),
          animationIntensity: 0.4,
          semanticLabel:     'IVE disponível para ajudar',
          fallbackLabel:     'IVE',
          repeatPolicy:      RepeatPolicy.loop,
        );

      case IveAvatarStateV2.listening:
        return const IveAvatarStateConfigV2(
          ringColor:         Color(0xFF4DA6FF),
          glowColor:         Color(0xFF4DA6FF),
          glowIntensity:     0.65,
          overlayColor:      Color(0xFF4DA6FF),
          overlayOpacity:    0.05,
          stateIndex:        1,
          animationDuration: Duration(milliseconds: 900),
          animationIntensity: 0.8,
          semanticLabel:     'IVE ouvindo',
          fallbackLabel:     'Ouvindo...',
          repeatPolicy:      RepeatPolicy.loop,
        );

      case IveAvatarStateV2.thinking:
        return const IveAvatarStateConfigV2(
          ringColor:         Color(0xFF00C6FF),
          glowColor:         Color(0xFF00C6FF),
          glowIntensity:     0.55,
          overlayColor:      Color(0xFF00C6FF),
          overlayOpacity:    0.04,
          stateIndex:        2,
          animationDuration: Duration(milliseconds: 1600),
          animationIntensity: 0.6,
          semanticLabel:     'IVE processando',
          fallbackLabel:     'Pensando...',
          repeatPolicy:      RepeatPolicy.loop,
        );

      case IveAvatarStateV2.analyzing:
        return const IveAvatarStateConfigV2(
          ringColor:         Color(0xFF9B8FFF),
          glowColor:         Color(0xFF9B8FFF),
          glowIntensity:     0.60,
          overlayColor:      Color(0xFF9B8FFF),
          overlayOpacity:    0.05,
          stateIndex:        3,
          animationDuration: Duration(milliseconds: 1400),
          animationIntensity: 0.65,
          semanticLabel:     'IVE analisando o projeto',
          fallbackLabel:     'Analisando...',
          repeatPolicy:      RepeatPolicy.loop,
        );

      case IveAvatarStateV2.researching:
        return const IveAvatarStateConfigV2(
          ringColor:         Color(0xFF00E0FF),
          glowColor:         Color(0xFF00E0FF),
          glowIntensity:     0.55,
          overlayColor:      Color(0xFF00E0FF),
          overlayOpacity:    0.04,
          stateIndex:        4,
          animationDuration: Duration(milliseconds: 1800),
          animationIntensity: 0.55,
          semanticLabel:     'IVE pesquisando informações',
          fallbackLabel:     'Pesquisando...',
          repeatPolicy:      RepeatPolicy.loop,
        );

      case IveAvatarStateV2.generating:
        return const IveAvatarStateConfigV2(
          ringColor:         Color(0xFFB47AFF),
          glowColor:         Color(0xFFB47AFF),
          glowIntensity:     0.70,
          overlayColor:      Color(0xFFB47AFF),
          overlayOpacity:    0.06,
          stateIndex:        5,
          animationDuration: Duration(milliseconds: 1200),
          animationIntensity: 0.75,
          semanticLabel:     'IVE gerando conteúdo',
          fallbackLabel:     'Gerando...',
          repeatPolicy:      RepeatPolicy.loop,
        );

      case IveAvatarStateV2.speaking:
        return const IveAvatarStateConfigV2(
          ringColor:         Color(0xFF7B5CF6),
          glowColor:         Color(0xFF7B5CF6),
          glowIntensity:     0.70,
          overlayColor:      Color(0xFF7B5CF6),
          overlayOpacity:    0.06,
          stateIndex:        6,
          animationDuration: Duration(milliseconds: 800),
          animationIntensity: 0.85,
          semanticLabel:     'IVE respondendo',
          fallbackLabel:     'Falando...',
          repeatPolicy:      RepeatPolicy.loop,
        );

      case IveAvatarStateV2.success:
        return const IveAvatarStateConfigV2(
          ringColor:         Color(0xFF00E875),
          glowColor:         Color(0xFF00E875),
          glowIntensity:     0.75,
          overlayColor:      Color(0xFF00E875),
          overlayOpacity:    0.08,
          stateIndex:        7,
          animationDuration: Duration(milliseconds: 600),
          animationIntensity: 0.9,
          semanticLabel:     'IVE concluiu com sucesso',
          fallbackLabel:     'Concluído',
          repeatPolicy:      RepeatPolicy.once,
        );

      case IveAvatarStateV2.warning:
        return const IveAvatarStateConfigV2(
          ringColor:         Color(0xFFFFB020),
          glowColor:         Color(0xFFFFB020),
          glowIntensity:     0.65,
          overlayColor:      Color(0xFFFFB020),
          overlayOpacity:    0.07,
          stateIndex:        8,
          animationDuration: Duration(milliseconds: 1000),
          animationIntensity: 0.70,
          semanticLabel:     'IVE encontrou um aviso',
          fallbackLabel:     'Atenção',
          repeatPolicy:      RepeatPolicy.loop,
        );

      case IveAvatarStateV2.error:
        return const IveAvatarStateConfigV2(
          ringColor:         Color(0xFFFF3D5A),
          glowColor:         Color(0xFFFF3D5A),
          glowIntensity:     0.80,
          overlayColor:      Color(0xFFFF3D5A),
          overlayOpacity:    0.10,
          stateIndex:        9,
          animationDuration: Duration(milliseconds: 700),
          animationIntensity: 0.85,
          semanticLabel:     'IVE não conseguiu concluir a análise',
          fallbackLabel:     'Erro',
          repeatPolicy:      RepeatPolicy.once,
        );

      case IveAvatarStateV2.offline:
        return const IveAvatarStateConfigV2(
          ringColor:         Color(0xFF555577),
          glowColor:         Color(0xFF555577),
          glowIntensity:     0.20,
          overlayColor:      Color(0xFF555577),
          overlayOpacity:    0.12,
          stateIndex:        10,
          animationDuration: Duration(milliseconds: 3000),
          animationIntensity: 0.20,
          semanticLabel:     'IVE sem conexão',
          fallbackLabel:     'Offline',
          repeatPolicy:      RepeatPolicy.none,
        );

      case IveAvatarStateV2.disabled:
        return const IveAvatarStateConfigV2(
          ringColor:         Color(0xFF333355),
          glowColor:         Color(0xFF333355),
          glowIntensity:     0.10,
          overlayColor:      Color(0xFF333355),
          overlayOpacity:    0.15,
          stateIndex:        11,
          animationDuration: Duration(milliseconds: 4000),
          animationIntensity: 0.10,
          semanticLabel:     'IVE desativada',
          fallbackLabel:     'Desativada',
          repeatPolicy:      RepeatPolicy.none,
        );

      case IveAvatarStateV2.attention:
        return const IveAvatarStateConfigV2(
          ringColor:         Color(0xFFFFD700),
          glowColor:         Color(0xFFFFD700),
          glowIntensity:     0.75,
          overlayColor:      Color(0xFFFFD700),
          overlayOpacity:    0.07,
          stateIndex:        12,
          animationDuration: Duration(milliseconds: 500),
          animationIntensity: 0.90,
          semanticLabel:     'IVE encontrou uma recomendação',
          fallbackLabel:     'Recomendação',
          repeatPolicy:      RepeatPolicy.loop,
        );

      case IveAvatarStateV2.waitingForUser:
        return const IveAvatarStateConfigV2(
          ringColor:         Color(0xFF8080C0),
          glowColor:         Color(0xFF8080C0),
          glowIntensity:     0.35,
          overlayColor:      Color(0xFF8080C0),
          overlayOpacity:    0.03,
          stateIndex:        13,
          animationDuration: Duration(milliseconds: 2800),
          animationIntensity: 0.35,
          semanticLabel:     'IVE aguardando sua resposta',
          fallbackLabel:     'Aguardando...',
          repeatPolicy:      RepeatPolicy.loop,
        );
    }
  }
}

// ── Repeat policy ─────────────────────────────────────────────────────────────

enum RepeatPolicy { loop, once, none }

// ── Placement enum ────────────────────────────────────────────────────────────

enum IveAvatarPlacement {
  automatic,
  inline,
  floatingBottomRight,
  floatingBottomLeft,
  appBar,
  cardHeader,
  hidden,
}

// ── Display mode enum ─────────────────────────────────────────────────────────

enum IveAvatarDisplayMode {
  compact,
  assistantButton,
  card,
  full,
}
