import 'package:flutter/material.dart';

import '../models/ive_avatar_context.dart';
import '../models/ive_avatar_state_v2.dart';
import '../theme/ive_avatar_theme.dart';
import '../theme/ive_avatar_tokens.dart';
import 'ive_avatar_compact.dart';

// ── IveAvatarCard ─────────────────────────────────────────────────────────────
//
// Card presentation: Business OS, Decision Center, Executive Briefing,
// Project Command Center headers.

class IveAvatarCard extends StatelessWidget {
  final IveAvatarStateV2 state;
  final IveAvatarContext avatarContext;
  final VoidCallback? onTap;
  final bool showLabel;
  final bool showStatus;

  const IveAvatarCard({
    super.key,
    required this.state,
    required IveAvatarContext context,
    this.onTap,
    this.showLabel = true,
    this.showStatus = true,
  }) : avatarContext = context;

  @override
  Widget build(BuildContext context) {
    final theme = IveAvatarTheme.forState(state);

    return AnimatedContainer(
      duration: IveAvatarTokens.stateChangeFade,
      decoration: BoxDecoration(
        color: IveAvatarTokens.surfaceDark,
        borderRadius: BorderRadius.circular(IveAvatarTokens.cardRadius),
        border: Border.all(
          color: theme.ringColor.withOpacity(0.25),
          width: 1.0,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IveAvatarCompact(
            state: state,
            size: IveAvatarTokens.sizeStandard,
            showRing: true,
            interactive: onTap != null,
            onTap: onTap,
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  avatarContext.title ?? 'IVE',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (showStatus) ...[
                  const SizedBox(height: 4),
                  _StatusRow(state: state, theme: theme),
                ],
                if (avatarContext.currentTask != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    avatarContext.currentTask!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (avatarContext.hasUnreadInsight)
            _InsightBadge(color: theme.ringColor),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final IveAvatarStateV2 state;
  final IveAvatarThemeData theme;

  const _StatusRow({required this.state, required this.theme});

  @override
  Widget build(BuildContext context) {
    final config = IveAvatarStateConfigV2.forState(state);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: theme.ringColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          config.fallbackLabel,
          style: theme.labelStyle.copyWith(fontSize: 11),
        ),
      ],
    );
  }
}

class _InsightBadge extends StatelessWidget {
  final Color color;
  const _InsightBadge({required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.4), width: 1),
        ),
        child: Text(
          'Novo',
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
