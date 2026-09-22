import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

// GATE-17-FINAL-CLOSURE (COMMERCIAL-EXPERIENCE-CLOSURE-17A, IVE Adaptive
// Resting Placement) — Owner-approved architectural fix for the P1
// physically confirmed on three core Android screens: the floating IVE
// avatar/bubble's single fixed resting corner (df43d45/6fa7df8) coincides,
// at rest (no scroll needed), with essential content -- a project's
// priority score, "Concluir"/"Trocar Projeto" buttons, a nav card. Per the
// Owner's explicit decision: SAFE/EXCLUSION REGIONS, not per-screen
// offsets or a route-name lookup table. This is the small, reusable
// contract screens opt INTO for the few surfaces that genuinely need
// protecting -- deliberately NOT automatic semantic scanning of every
// card/text in the tree (Section 2 of the mission explicitly rules that
// out), so wrap only elements actually reproduced as colliding or of
// equivalent importance (a primary action button, a key metric), not
// everything on a page.
//
// Global, not Riverpod-scoped: IveOverlay itself is mounted once, globally,
// outside any single screen's widget subtree (app.dart's Stack), and reads
// this the same way it already reads iveModalOpenNotifier/
// iveScrollingNotifier/iveInlineAskVisibleNotifier -- a plain top-level
// ValueNotifier is the established pattern in this file's sibling
// (ive_overlay.dart), not a new mechanism.
final iveExclusionRegionsNotifier = ValueNotifier<List<Rect>>(const []);

final Map<Object, Rect> _iveExclusionRegions = {};

void _publishExclusionRegions() {
  // Defensive copy -- callers (the placement engine) must never be handed
  // a live reference into this private map.
  iveExclusionRegionsNotifier.value = List.unmodifiable(_iveExclusionRegions.values);
}

/// Wrap any widget the app needs the floating IVE avatar to never rest on
/// top of -- a primary action button ("Concluir"), a key metric ("Trocar
/// Projeto", a priority score), a persistent nav card. Purely a geometry
/// reporter: renders [child] completely unchanged, contributes no paint of
/// its own. Safe to use more than once at a time (e.g. one per visible list
/// item) -- each instance registers under its own identity and is removed
/// independently on dispose, exactly like iveModalOpenNotifier's counter
/// but keyed (a list, not a count) since here WHERE each region is matters,
/// not just how many are open.
class IveExclusionRegion extends StatefulWidget {
  const IveExclusionRegion({super.key, required this.child});

  final Widget child;

  @override
  State<IveExclusionRegion> createState() => _IveExclusionRegionState();
}

class _IveExclusionRegionState extends State<IveExclusionRegion> {
  final _boxKey = GlobalKey();
  bool _scheduled = false;
  ScrollPosition? _scrollPosition;

  // GATE-17-FINAL-CLOSURE (Codex final audit, P1 ACCEPTED) — re-measuring
  // only from build() (below) is correct for WHEN a widget mounts/resizes,
  // but not for a list item that stays mounted while its own on-screen
  // position moves purely from an ancestor Scrollable's offset changing --
  // ListView/SingleChildScrollView don't rebuild already-built children
  // just because the user scrolled, so without this, a registered Rect
  // would go stale mid-scroll and the placement engine would keep steering
  // clear of (or fail to steer clear of) wherever the item USED to be, not
  // where it now renders. Listening to the nearest ancestor Scrollable's
  // ScrollPosition directly (not a NotificationListener) is required here
  // because this widget is a DESCENDANT of that Scrollable, not an
  // ancestor -- ScrollNotification only bubbles UP to ancestors of the
  // Scrollable, so a NotificationListener wrapping this widget would never
  // see it. didChangeDependencies (not initState) because Scrollable.of
  // needs an established BuildContext and can legitimately change if this
  // widget's position in the tree changes.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newPosition = Scrollable.maybeOf(context)?.position;
    if (newPosition != _scrollPosition) {
      _scrollPosition?.removeListener(_scheduleMeasure);
      _scrollPosition = newPosition;
      _scrollPosition?.addListener(_scheduleMeasure);
    }
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_scheduleMeasure);
    _iveExclusionRegions.remove(this);
    // GATE-17-FINAL-CLOSURE (Section 8, lifecycle audit) — this session
    // already found and fixed one real "modify a provider during build"
    // crash (9df6c4f); notifying listeners synchronously from dispose()
    // -- itself often triggered mid-build/layout (e.g. a list item
    // scrolling out and being disposed while another rebuilds) -- is
    // exactly that same risk. Deferred the same proven way: immediately
    // if idle, otherwise once the current frame finishes.
    _publishSafely();
    super.dispose();
  }

  void _publishSafely() {
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      _publishExclusionRegions();
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) => _publishExclusionRegions());
    }
  }

  void _measure() {
    _scheduled = false;
    final box = _boxKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !mounted) return;
    final topLeft = box.localToGlobal(Offset.zero);
    final rect = topLeft & box.size;
    if (_iveExclusionRegions[this] == rect) return; // no-op, avoid churn
    _iveExclusionRegions[this] = rect;
    _publishSafely();
  }

  void _scheduleMeasure() {
    if (_scheduled) return;
    _scheduled = true;
    // Always post-frame here regardless of phase: the RenderBox this reads
    // has only just been laid out THIS frame and isn't safe to query until
    // paint has happened, unlike the notifier publish above.
    SchedulerBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  Widget build(BuildContext context) {
    _scheduleMeasure();
    return KeyedSubtree(key: _boxKey, child: widget.child);
  }
}
