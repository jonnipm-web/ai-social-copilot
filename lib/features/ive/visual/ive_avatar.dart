import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers/ive_provider.dart';
import 'ive_avatar_controller.dart';
import 'ive_avatar_state.dart';
import 'ive_visual_config.dart';
import 'ive_visual_fallback.dart';

export 'ive_avatar_state.dart' show IveVisualState;
export 'ive_visual_config.dart' show IveAvatarSize;

// ── IveAvatar — main character widget ────────────────────────────────────────
//
// Usage:
//   IveAvatar(
//     size:           IveAvatarSize.compact,
//     showStatusRing: true,
//     interactive:    true,
//     onTap:          openIveChat,
//   )
//
// IveRiveFeatureGate.enabled = false — always renders IveVisualFallback.
// The Rive display path (_RiveAvatar) was removed alongside the rive package
// to unblock Android APK builds (rive_common JNI Gradle failure). Re-entry
// requires a reviewed code change under Agente Martins/Paulo authorization
// (see docs/ive/IVE_RIVE_FREEZE_RECORD.md §05).

class IveAvatar extends ConsumerStatefulWidget {
  final IveAvatarSize size;
  final bool showStatusRing;
  final bool interactive;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const IveAvatar({
    super.key,
    this.size = IveAvatarSize.standard,
    this.showStatusRing = true,
    this.interactive = true,
    this.onTap,
    this.onLongPress,
  });

  @override
  ConsumerState<IveAvatar> createState() => _IveAvatarState();
}

class _IveAvatarState extends ConsumerState<IveAvatar> {
  final _controller = IveAvatarController();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _tryLoadRive();
  }

  Future<void> _tryLoadRive() async {
    await _controller.initializeRive();
    if (mounted) setState(() => _initialized = true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final iveState = ref.watch(iveProvider);
    final visualState = IveVisualStateMapper.fromIveState(iveState);

    if (_initialized) {
      _controller.applyVisualState(visualState);
    }

    final dp = widget.size.dp;

    final Widget avatar = IveVisualFallback(
      state: visualState,
      size: dp,
    );

    if (!widget.interactive) return avatar;

    return Semantics(
      label: AppLocalizations.of(context)!.iveSemanticsLabel,
      button: true,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: avatar,
      ),
    );
  }
}
