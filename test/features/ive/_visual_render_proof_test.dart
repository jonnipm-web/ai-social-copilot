// TEMPORARY investigation only -- not part of the permanent suite.
// IVE-VISUAL-CANONICAL-INTEGRATION-07V — captures ACTUAL RENDERED PIXELS
// (via RenderRepaintBoundary.toImage(), Flutter's real Skia rasterizer, not
// a mock/isolated image viewer) of the REAL IveAvatar/IveVisualFallback
// widgets at the exact production sizes/params used by IveOverlay (compact,
// 56dp, showStatusRing:true) and ive_intro_sheet.dart/Meet IVE (large, 96dp,
// showStatusRing:false), for both the OLD (production, main@cdfb5414) and
// NEW (this branch) asset wiring, for direct A/B visual comparison.
//
// The OLD side reconstructs main's exact pre-fix ive_visual_fallback.dart
// code verbatim (verified via `git show origin/main:...`) as a private
// widget here, since that class no longer exists in this checkout's source
// -- not a redesign, a byte-for-byte copy of the widget tree structure that
// is genuinely live in production today.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/features/ive/visual/ive_avatar.dart';
import 'package:ai_social_copilot/features/ive/visual/ive_avatar_state.dart';
import 'package:ai_social_copilot/features/ive/visual/ive_status_ring.dart';
import 'package:ai_social_copilot/features/ive/visual/ive_visual_config.dart';

// ── Verbatim reconstruction of main@cdfb5414's IveVisualFallback ───────────
class _OldProductionFallback extends StatefulWidget {
  final IveVisualState state;
  final double size;
  const _OldProductionFallback({required this.state, required this.size});

  @override
  State<_OldProductionFallback> createState() => _OldProductionFallbackState();
}

class _OldProductionFallbackState extends State<_OldProductionFallback>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = IveVisualStateConfig.forState(widget.state);
    final padding = widget.size * 0.055;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: IveStatusRingPainter(state: widget.state, glowPulse: _pulse.value),
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: ClipOval(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    IveAssetPaths.referenceImage,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF0A0B1A)),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    decoration: BoxDecoration(
                      color: config.overlayColor
                          .withOpacity(config.overlayOpacity * (0.6 + _pulse.value * 0.4)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _capture(WidgetTester tester, Key key, String outPath) async {
  final finder = find.byKey(key);
  final element = finder.evaluate().single;
  final renderObject = element.renderObject! as RenderRepaintBoundary;
  final image = await renderObject.toImage(pixelRatio: 3.0);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(outPath);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(byteData!.buffer.asUint8List());
  // ignore: avoid_print
  print('RENDER_PROOF_CAPTURED $outPath (${image.width}x${image.height})');
}

void main() {
  testWidgets('REAL RENDER PROOF -- OLD (production) vs NEW (branch) at real sizes',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            backgroundColor: const Color(0xFF0A0B1A),
            body: Center(
              child: Wrap(
                spacing: 48,
                runSpacing: 48,
                children: [
                  RepaintBoundary(
                    key: const Key('old_compact_56'),
                    child: const _OldProductionFallback(state: IveVisualState.idle, size: 56),
                  ),
                  RepaintBoundary(
                    key: const Key('old_large_96'),
                    child: const _OldProductionFallback(state: IveVisualState.idle, size: 96),
                  ),
                  // Real IveAvatar, exact params from ive_overlay.dart
                  // (Global IVE, compact/56dp, showStatusRing:true).
                  RepaintBoundary(
                    key: const Key('new_compact_56'),
                    child: const IveAvatar(
                      size: IveAvatarSize.compact,
                      showStatusRing: true,
                      interactive: false,
                    ),
                  ),
                  // Real IveAvatar, exact params from ive_intro_sheet.dart
                  // (Meet IVE, large/96dp, showStatusRing:false).
                  RepaintBoundary(
                    key: const Key('new_large_96'),
                    child: const IveAvatar(
                      size: IveAvatarSize.large,
                      showStatusRing: false,
                      interactive: false,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // IveAvatar's own existing test suite pumps 2s to let it settle past any
    // Rive-attempt window onto the (frozen, always-active) fallback path;
    // matched here for fidelity.
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    // A few more frames to ensure the decoded image bytes have actually
    // painted (Image.asset's first frames can be empty while the asset
    // bundle read completes).
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    await tester.runAsync(() async {
      await _capture(tester, const Key('old_compact_56'), 'render_proof/A_old_production_compact_56dp.png');
      await _capture(tester, const Key('old_large_96'), 'render_proof/A_old_production_large_96dp.png');
      await _capture(tester, const Key('new_compact_56'), 'render_proof/B_new_branch_compact_56dp.png');
      await _capture(tester, const Key('new_large_96'), 'render_proof/B_new_branch_large_96dp.png');
    });

    expect(tester.takeException(), isNull);
  });
}
