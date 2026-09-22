import 'dart:ui';

import 'package:ai_social_copilot/shared/widgets/ive_placement_engine.dart';
import 'package:flutter_test/flutter_test.dart';

// GATE-17-FINAL-CLOSURE (COMMERCIAL-EXPERIENCE-CLOSURE-17A, IVE Adaptive
// Resting Placement) — pure unit tests for the placement algorithm itself,
// independent of any widget tree. Screen/footprint sizes below are
// arbitrary but fixed across tests for readability; only what's varied
// (exclusions, previousPosition) matters to each assertion.
void main() {
  const screenSize = Size(400, 800);
  const footprint = Size(64, 64);
  const safeArea = IveSafeAreaInsets();

  IvePlacementInput input({
    List<Rect> exclusions = const [],
    Offset? previousPosition,
  }) =>
      IvePlacementInput(
        screenSize: screenSize,
        safeArea: safeArea,
        avatarFootprint: footprint,
        exclusions: exclusions,
        previousPosition: previousPosition,
      );

  Rect footprintRectFor(Offset offset) {
    final left = screenSize.width - offset.dx - footprint.width;
    return Rect.fromLTWH(left, offset.dy, footprint.width, footprint.height);
  }

  group('computeRestingPosition', () {
    test('no exclusions -> default bottom-right candidate', () {
      final result = computeRestingPosition(input());
      final rect = footprintRectFor(result);

      // bottom-right: near the right edge, near the bottom.
      expect(rect.right, closeTo(screenSize.width, 16));
      expect(rect.bottom, closeTo(screenSize.height, 32));
    });

    test('deterministic: same input always produces the same output', () {
      final a = computeRestingPosition(input());
      final b = computeRestingPosition(input());
      expect(a.dx, b.dx);
      expect(a.dy, b.dy);
    });

    test('bottom-right blocked -> falls through to the next safe candidate', () {
      final defaultResult = computeRestingPosition(input());
      final blockedAtDefault = footprintRectFor(defaultResult).inflate(4);

      final result = computeRestingPosition(input(exclusions: [blockedAtDefault]));
      final resultRect = footprintRectFor(result);

      expect(resultRect.overlaps(blockedAtDefault), isFalse,
          reason: 'must not rest on top of the physically-reproduced collision zone');
    });

    test('multiple blocked regions -> still finds a safe candidate among the rest', () {
      // Block every right-edge candidate with one tall Rect down that whole
      // column; only the left-side candidates remain safe.
      final rightColumn = Rect.fromLTWH(screenSize.width - 100, 0, 100, screenSize.height);

      final result = computeRestingPosition(input(exclusions: [rightColumn]));
      final resultRect = footprintRectFor(result);

      expect(resultRect.overlaps(rightColumn), isFalse);
    });

    test('no valid candidate anywhere -> falls back to least-overlap, never throws', () {
      // Cover the ENTIRE screen -- every candidate collides.
      final everything = Rect.fromLTWH(0, 0, screenSize.width, screenSize.height);

      expect(
        () => computeRestingPosition(input(exclusions: [everything])),
        returnsNormally,
      );
      final result = computeRestingPosition(input(exclusions: [everything]));
      // Still inside the viewport (clamped), not NaN/garbage.
      final rect = footprintRectFor(result);
      expect(rect.left, greaterThanOrEqualTo(-0.01));
      expect(rect.top, greaterThanOrEqualTo(-0.01));
    });

    test('previous position preserved when still safe (no jitter/oscillation)', () {
      final safePrevious = const Offset(8, 400); // mid-right-ish, arbitrary safe spot
      final result = computeRestingPosition(input(previousPosition: safePrevious));

      expect(result, safePrevious,
          reason: 'must not move away from an already-safe position on every rebuild');
    });

    test('previous position abandoned once it starts colliding', () {
      final previous = const Offset(8, 400);
      final blockingPrevious = footprintRectFor(previous).inflate(4);

      final result = computeRestingPosition(
        input(previousPosition: previous, exclusions: [blockingPrevious]),
      );

      expect(result, isNot(previous));
      expect(footprintRectFor(result).overlaps(blockingPrevious), isFalse);
    });

    test('result is always clamped inside the safe viewport', () {
      final result = computeRestingPosition(input());
      final rect = footprintRectFor(result);

      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(screenSize.width + 0.01));
      expect(rect.bottom, lessThanOrEqualTo(screenSize.height + 0.01));
    });

    test('verticalReserve keeps a bottom-anchored candidate further from the '
        'bottom edge, for a caller whose real anchor is taller than avatarFootprint', () {
      final withoutReserve = computeRestingPosition(input());
      final withReserve = computeRestingPosition(IvePlacementInput(
        screenSize: screenSize,
        safeArea: safeArea,
        avatarFootprint: footprint,
        verticalReserve: 240,
      ));

      expect(withReserve.dy, lessThan(withoutReserve.dy),
          reason: 'a taller verticalReserve must push a bottom-anchored candidate '
              'HIGHER (smaller dy/top) to leave more room below it -- regression: a '
              'candidate computed only from avatarFootprint (ignoring a taller real '
              'anchor, e.g. a speech bubble stacked above it) let the actual '
              'rendered content spill past the bottom of the viewport -- '
              'reproduced physically via ive_overlay_forensic_snapshot_test.dart '
              '(the avatar rendered fully off-screen, so no pointer could ever '
              'hit it to drag it)');
    });

    group('footprintOffsetY (COMMERCIAL-EXPERIENCE-CLOSURE-17A regression)', () {
      // Physically reproduced: an anchor sits far ABOVE where the avatar
      // itself actually renders (anchor.dy + offsetY), because the anchor
      // is the top of a taller, partly-invisible column. Without
      // footprintOffsetY, collision testing validated the anchor's own
      // position instead of the avatar's real one, so a candidate/previous-
      // position/fallback choice that cleared every exclusion at the
      // anchor could still leave the real, displaced avatar resting on top
      // of one (Home's project score, reproduced physically after the
      // full-footprint rework).
      //
      // Codex final audit (P2 ACCEPTED): the original version of this test
      // set `verticalReserve` to the SAME value as `footprintOffsetY`,
      // which independently pushes candidates away from the exclusion --
      // an implementation that silently ignored footprintOffsetY entirely
      // could still have passed. Every test below uses verticalReserve: 0
      // (the default), so only footprintOffsetY can be responsible for the
      // assertions passing.
      const offsetY = 200.0;

      test('primary candidate loop', () {
        final defaultAnchor = computeRestingPosition(input());
        // Covers where the AVATAR really renders (anchor + offsetY) at the
        // default candidate, but deliberately NOT the anchor position
        // itself -- a buggy implementation testing collisions at the
        // anchor would find this candidate falsely "safe" and never move.
        final realAvatarRect = Rect.fromLTWH(
          footprintRectFor(defaultAnchor).left,
          defaultAnchor.dy + offsetY,
          footprint.width,
          footprint.height,
        );

        final result = computeRestingPosition(IvePlacementInput(
          screenSize: screenSize,
          safeArea: safeArea,
          avatarFootprint: footprint,
          footprintOffsetY: offsetY,
          exclusions: [realAvatarRect.inflate(2)],
        ));

        expect(result, isNot(equals(defaultAnchor)),
            reason: 'must move away from the default candidate -- its REAL '
                '(offset) position collides, even though its own anchor position '
                'does not');
        final resultRealRect = Rect.fromLTWH(
          footprintRectFor(result).left,
          result.dy + offsetY,
          footprint.width,
          footprint.height,
        );
        expect(resultRealRect.overlaps(realAvatarRect), isFalse);
      });

      test('previous-position continuity check', () {
        const previous = Offset(8, 300); // arbitrary safe-looking anchor
        final realAvatarRect = Rect.fromLTWH(
          footprintRectFor(previous).left,
          previous.dy + offsetY,
          footprint.width,
          footprint.height,
        );

        final result = computeRestingPosition(IvePlacementInput(
          screenSize: screenSize,
          safeArea: safeArea,
          avatarFootprint: footprint,
          footprintOffsetY: offsetY,
          previousPosition: previous,
          exclusions: [realAvatarRect.inflate(2)],
        ));

        expect(result, isNot(equals(previous)),
            reason: 'previousPosition must be abandoned -- its REAL (offset) '
                'position collides, even though the anchor itself does not, so '
                'keeping it via continuity would be wrong');
      });

      test('fallback least-overlap path', () {
        // Covers the REAL (offset) position of every candidate at once,
        // without covering any candidate's raw anchor position (all
        // anchors sit in y ∈ [0, screenSize.height], so shifting the
        // exclusion down by offsetY and starting it at offsetY leaves
        // every anchor's own row uncovered).
        final everyRealPosition = Rect.fromLTWH(
          0,
          offsetY,
          screenSize.width,
          screenSize.height,
        );

        expect(
          () => computeRestingPosition(IvePlacementInput(
            screenSize: screenSize,
            safeArea: safeArea,
            avatarFootprint: footprint,
            footprintOffsetY: offsetY,
            exclusions: [everyRealPosition],
          )),
          returnsNormally,
        );
        final result = computeRestingPosition(IvePlacementInput(
          screenSize: screenSize,
          safeArea: safeArea,
          avatarFootprint: footprint,
          footprintOffsetY: offsetY,
          exclusions: [everyRealPosition],
        ));
        final resultRealRect = Rect.fromLTWH(
          footprintRectFor(result).left,
          result.dy + offsetY,
          footprint.width,
          footprint.height,
        );
        // Every candidate's REAL position collides by construction (that's
        // what forces the fallback path) -- the only thing to prove here is
        // that it still terminates with a valid, clamped Offset rather than
        // throwing or returning garbage.
        expect(resultRealRect.width, footprint.width);
        expect(result.dx.isFinite, isTrue);
        expect(result.dy.isFinite, isTrue);
      });
    });

    test('clamp fallback still respects verticalReserve, not just avatarFootprint '
        '(Codex final audit, P2 ACCEPTED)', () {
      // Force the fallback-clamp path (everything collides) on a viewport
      // short enough that footprint + reserve barely fits, so the clamp's
      // own maxDy is the thing under test, not the candidate generation.
      const shortScreen = Size(400, 400);
      final result = computeRestingPosition(IvePlacementInput(
        screenSize: shortScreen,
        safeArea: safeArea,
        avatarFootprint: footprint,
        verticalReserve: 240,
        exclusions: [Rect.fromLTWH(0, 0, shortScreen.width, shortScreen.height)],
      ));

      final maxAllowedDy = shortScreen.height - footprint.height - 240;
      expect(result.dy, lessThanOrEqualTo(maxAllowedDy + 0.01),
          reason: 'the clamp must not place the anchor lower than the reserve '
              'allows, even on the fallback path -- a clamp that ignored '
              'verticalReserve could push a short-viewport result back down '
              'past the gap reserved for a taller anchor (e.g. the speech '
              'bubble), reintroducing the off-screen-spill class of bug.');
    });

    test('respects safeArea insets in the clamp', () {
      const inset = IveSafeAreaInsets(top: 40, bottom: 60, left: 10, right: 10);
      final result = computeRestingPosition(IvePlacementInput(
        screenSize: screenSize,
        safeArea: inset,
        avatarFootprint: footprint,
        // Force the fallback-clamp path with an all-covering exclusion so
        // the result is deterministic regardless of candidate order.
        exclusions: [Rect.fromLTWH(0, 0, screenSize.width, screenSize.height)],
      ));
      final rect = footprintRectFor(result);

      expect(rect.top, greaterThanOrEqualTo(inset.top - 0.01));
      expect(rect.bottom, lessThanOrEqualTo(screenSize.height - inset.bottom + 0.01));
    });
  });
}
