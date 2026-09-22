import 'dart:ui' show Offset, Rect, Size;

// GATE-17-FINAL-CLOSURE (COMMERCIAL-EXPERIENCE-CLOSURE-17A, IVE Adaptive
// Resting Placement) — pure, side-effect-free placement logic, deliberately
// split from ive_overlay.dart so it's directly unit-testable without a
// widget tree/Flutter binding. Single source of truth for "where does the
// IVE avatar rest" -- ive_overlay.dart's existing scroll-compaction stays
// a purely visual (opacity/scale) treatment layered on TOP of whatever
// position this returns, not a second competing placement mechanism
// (mission Section 7).
//
// Coordinate convention matches the pre-existing _position field in
// ive_overlay.dart exactly, to keep that call site a drop-in replacement:
// Offset(dx, dy) where dx = distance from the RIGHT edge, dy = distance
// from the TOP. This is why "left" candidates below still return a dx
// measured from the right (screenWidth - leftMargin - footprint.width).

/// One fixed candidate resting corner, expressed the same way the rest of
/// this file measures position: distance from the right edge, distance
/// from the top.
class IveRestingCandidate {
  const IveRestingCandidate(this.name, this.offset);
  final String name;
  final Offset offset;
}

class IvePlacementInput {
  const IvePlacementInput({
    required this.screenSize,
    required this.safeArea,
    required this.avatarFootprint,
    this.exclusions = const [],
    this.previousPosition,
    this.isDesktop = false,
    this.verticalReserve = 0,
    this.footprintOffsetY = 0,
  });

  final Size screenSize;
  final IveSafeAreaInsets safeArea;
  final Size avatarFootprint;
  final List<Rect> exclusions;
  final Offset? previousPosition;
  final bool isDesktop;

  /// Extra space reserved ABOVE a bottom-anchored candidate, on top of
  /// [avatarFootprint].height -- for callers whose anchor is the top of a
  /// taller rendered column (e.g. a speech bubble stacked above the avatar
  /// it positions) than what should actually be tested for exclusion
  /// collisions. Defaults to 0 (candidate generation and collision testing
  /// both use exactly [avatarFootprint], the original single-footprint
  /// contract this class shipped with).
  final double verticalReserve;

  /// COMMERCIAL-EXPERIENCE-CLOSURE-17A (IVE Full-Footprint Collision
  /// Closure) — vertical distance from the anchor (a candidate's offset,
  /// or [previousPosition]) down to where [avatarFootprint] actually
  /// starts, for collision testing. Defaults to 0 (the footprint starts
  /// exactly at the anchor -- true whenever the anchor IS the top-left of
  /// what's being protected).
  ///
  /// Needed when the anchor is the top of a taller rendered region than
  /// [avatarFootprint] itself represents -- e.g. a caller whose anchor is
  /// the top of a bubble+avatar column, but whose [avatarFootprint] for
  /// THIS call deliberately covers only the avatar portion (an invisible
  /// bubble isn't blocking anything, so it's excluded from collision
  /// testing -- see [verticalReserve]'s own doc comment for the same
  /// scenario from the viewport-fit side). Without this, the collision
  /// rect would be tested at the ANCHOR's position instead of the
  /// avatar's real position -- exactly the class of bug this field fixes
  /// (Codex final audit follow-up: candidates were being validated against
  /// exclusions at the wrong Y, so a candidate whose anchor cleared every
  /// exclusion could still leave the real, displaced avatar resting on
  /// top of one).
  final double footprintOffsetY;
}

/// Minimal stand-in for Flutter's own EdgeInsets so this file has zero
/// Flutter dependency and stays trivially testable in a plain Dart test.
class IveSafeAreaInsets {
  const IveSafeAreaInsets({this.top = 0, this.bottom = 0, this.left = 0, this.right = 0});
  final double top;
  final double bottom;
  final double left;
  final double right;
}

/// GATE-17-FINAL-CLOSURE (Section 3/4) — candidate resting zones, tried in
/// this priority order. Desktop keeps its own pre-existing safe corner
/// (app.dart's prior _defaultPosition already special-cased desktop; that
/// behavior is preserved, not touched, by computeRestingPosition callers
/// checking `isDesktop` first) -- these five are mobile-only, matching the
/// mission's own suggested set exactly (Section 4 lists them and says "não
/// é obrigatório usar exatamente essas cinco" -- these five cover every
/// screen edge actually reproduced as colliding without inventing more
/// than needed).
List<IveRestingCandidate> _mobileCandidates(Size screenSize,
    IveSafeAreaInsets safeArea, Size footprint, double verticalReserve) {
  const margin = 8.0;
  final maxY = screenSize.height -
      footprint.height -
      verticalReserve -
      safeArea.bottom -
      16;
  final minY = safeArea.top + 16;
  final midY = (minY + maxY) / 2;
  const rightDx = margin;
  final leftDx = screenSize.width - footprint.width - margin - safeArea.left;

  return [
    IveRestingCandidate('bottom-right', Offset(rightDx, maxY)),
    IveRestingCandidate('mid-right', Offset(rightDx, midY)),
    IveRestingCandidate('upper-right', Offset(rightDx, minY)),
    IveRestingCandidate('bottom-left', Offset(leftDx, maxY)),
    IveRestingCandidate('mid-left', Offset(leftDx, midY)),
  ];
}

Rect _footprintRect(
    Offset position, Size footprint, Size screenSize, double offsetY) {
  // position.dx is distance-from-right (matches ive_overlay.dart's own
  // Positioned(right: ..., top: ...) usage) -- convert to a left-based
  // Rect for intersection testing against exclusions, which are reported
  // in ordinary top-left global coordinates by IveExclusionRegion.
  final left = screenSize.width - position.dx - footprint.width;
  return Rect.fromLTWH(
      left, position.dy + offsetY, footprint.width, footprint.height);
}

bool _collides(Rect a, List<Rect> exclusions) =>
    exclusions.any((r) => a.overlaps(r));

/// GATE-17-FINAL-CLOSURE (Section 3, steps 5-10) — the actual algorithm:
/// 1. Desktop keeps its existing fixed safe corner untouched (callers
///    should not even reach here for desktop; see ive_overlay.dart).
/// 2. If the PREVIOUS position is still on-screen and doesn't collide with
///    any current exclusion, keep it -- "preferir continuidade visual: se
///    a posição atual continua segura, não mover" (Section 4), and the
///    concrete mechanism that stops jitter/oscillation (Section 3's "evitar
///    movimento visual constante").
/// 3. Otherwise try each candidate corner in priority order; the first one
///    whose footprint doesn't overlap any exclusion wins.
/// 4. If every candidate collides (a screen with exclusions covering the
///    whole edge column), fall back to whichever candidate collides with
///    the FEWEST/smallest exclusions rather than vanishing or leaving the
///    IVE permanently unreachable (Section 6: "não permitir que ... deixe
///    CTA essencial permanentemente bloqueado" -- applies symmetrically:
///    the IVE itself must also stay reachable).
/// 5. Final clamp keeps the result inside the safe viewport regardless of
///    which path produced it.
Offset computeRestingPosition(IvePlacementInput input) {
  final candidates = _mobileCandidates(
      input.screenSize, input.safeArea, input.avatarFootprint, input.verticalReserve);

  if (input.previousPosition != null) {
    final prevRect = _footprintRect(
        input.previousPosition!, input.avatarFootprint, input.screenSize, input.footprintOffsetY);
    // Plain viewport bound on the REAL footprint rect (already correctly
    // offset by footprintOffsetY above) -- no separate verticalReserve
    // subtraction needed here; that would double-count the same margin
    // this rect's own position already accounts for.
    final withinScreen = prevRect.left >= 0 &&
        prevRect.top >= input.safeArea.top &&
        prevRect.right <= input.screenSize.width &&
        prevRect.bottom <= input.screenSize.height - input.safeArea.bottom;
    if (withinScreen && !_collides(prevRect, input.exclusions)) {
      return input.previousPosition!;
    }
  }

  for (final candidate in candidates) {
    final rect = _footprintRect(
        candidate.offset, input.avatarFootprint, input.screenSize, input.footprintOffsetY);
    if (!_collides(rect, input.exclusions)) {
      return _clamp(candidate.offset, input);
    }
  }

  // Every candidate collides -- pick whichever overlaps the LEAST total
  // exclusion area, so the IVE lands somewhere still-reachable rather than
  // disappearing or defaulting to the worst option.
  var best = candidates.first;
  var bestOverlap = double.infinity;
  for (final candidate in candidates) {
    final rect = _footprintRect(
        candidate.offset, input.avatarFootprint, input.screenSize, input.footprintOffsetY);
    final overlap = input.exclusions.fold<double>(
      0,
      (sum, r) => sum + _intersectionArea(rect, r),
    );
    if (overlap < bestOverlap) {
      bestOverlap = overlap;
      best = candidate;
    }
  }
  return _clamp(best.offset, input);
}

double _intersectionArea(Rect a, Rect b) {
  final intersection = a.intersect(b);
  if (intersection.width <= 0 || intersection.height <= 0) return 0;
  return intersection.width * intersection.height;
}

// GATE-17-FINAL-CLOSURE (Codex final audit, P2 ACCEPTED) — this clamp is
// the last-resort safety net applied to WHATEVER offset the candidate/
// fallback logic produced, including the "every candidate collides"
// fallback path. It must stay consistent with the same verticalReserve
// budget _mobileCandidates used to generate maxY, or a short viewport
// could clamp a candidate BACK DOWN past the reserved gap, defeating it.
Offset _clamp(Offset offset, IvePlacementInput input) {
  final maxDx = input.screenSize.width - input.avatarFootprint.width - input.safeArea.left;
  final minDx = input.safeArea.right;
  final maxDy = input.screenSize.height -
      input.avatarFootprint.height -
      input.verticalReserve -
      input.safeArea.bottom;
  final minDy = input.safeArea.top;
  return Offset(
    offset.dx.clamp(minDx, maxDx < minDx ? minDx : maxDx),
    offset.dy.clamp(minDy, maxDy < minDy ? minDy : maxDy),
  );
}
