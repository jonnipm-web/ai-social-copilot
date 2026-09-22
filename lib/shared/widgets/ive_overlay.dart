import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/diagnostics/ive_forensic_snapshot.dart';
import '../../data/models/copilot_context_data.dart';
import '../../data/models/ive_interaction_request.dart';
import '../../data/models/ive_issue.dart';
import '../../data/models/ive_state.dart';
import '../../features/ive/visual/ive_avatar.dart';
import '../../features/ive/visual/ive_visual_config.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ive_context_provider.dart';
import '../../providers/ive_memory_provider.dart';
import '../../providers/ive_provider.dart';
import '../../providers/profile_provider.dart';
import 'context_copilot_widget.dart'
    show showCopilotChat, iveChatOpenNotifier, iveInlineAskVisibleNotifier;
import 'ive_exclusion_region.dart' show iveExclusionRegionsNotifier;
import 'ive_placement_engine.dart'
    show computeRestingPosition, IvePlacementInput, IveSafeAreaInsets;

// ── Route bridge ──────────────────────────────────────────────────────────────
final iveRouteNotifier = ValueNotifier<String>('');

// COMMERCIAL-EXPERIENCE-CLOSURE-16R (mission Section 07) — owner-supplied
// physical evidence (Performance -> Nova Métrica): IveOverlay is a Stack
// SIBLING of the router's own content (STABILITY-09/10 topology), painted
// AFTER it, so it visually sits on top of ANY modal (showDialog,
// showModalBottomSheet) too, since a modal's content still lives inside
// that same `child` subtree, not in some separate layer above IveOverlay.
// iveChatOpenNotifier (context_copilot_widget.dart) already fixed this for
// the ONE known case (the copilot chat sheet/dialog), but that required
// every call site to explicitly set it -- exactly the "per-screen hack"
// mission Section 07 says to avoid for the GENERAL problem. This instead
// generalizes via the NavigatorObserver already registered on the app's
// single root Navigator (app.dart's `observers: [_iveObserver]`): every
// dialog and modal bottom sheet in Flutter is a PopupRoute under the hood,
// so counting PopupRoute push/pop here catches EVERY modal in the app,
// present and future, with zero changes required at any call site --
// "Nova Métrica" included, with no Performance-specific fix needed.
final iveModalOpenNotifier = ValueNotifier<bool>(false);
int _iveOpenModalCount = 0;

void _iveModalCountChanged(int delta) {
  _iveOpenModalCount = (_iveOpenModalCount + delta).clamp(0, 1 << 30);
  iveModalOpenNotifier.value = _iveOpenModalCount > 0;
}

// GATE-17-FINAL-CLOSURE (Section 03, Agente Martins Decision 1-3) — the
// modal/chat notifiers above only stop IveOverlay from covering something
// that itself OWNS the whole screen (a dialog/sheet/chat). They do nothing
// for the far more common case physical testing actually found: ordinary
// scrolled page content (a card, a FAB) passing UNDER the overlay's own
// fixed viewport position. A per-screen fix was explicitly rejected
// (Decision 2) unless no simpler centralized signal exists — one already
// does, the same way PopupRoute did for modals: Flutter's ScrollNotification
// bubbles up from ANY Scrollable (ListView, CustomScrollView, a
// SingleChildScrollView, GridView -- every scrollable screen in this app)
// to a SINGLE NotificationListener wrapped around the router's `child` in
// app.dart, with zero opt-in required at any call site, present or future.
// Used to temporarily compact/fade the overlay WHILE the user is actively
// scrolling content through its position -- it does not (and structurally
// cannot) guarantee zero overlap with a screen that is at rest without
// ever having been scrolled, which is why this is paired with a smaller,
// edge-anchored resting footprint (see _defaultPosition/build below), not
// relied on alone.
final iveScrollingNotifier = ValueNotifier<bool>(false);
Timer? _iveScrollIdleTimer;

bool ivePageScrollNotification(ScrollNotification notification) {
  if (notification is ScrollStartNotification ||
      notification is ScrollUpdateNotification) {
    _iveScrollIdleTimer?.cancel();
    if (!iveScrollingNotifier.value) iveScrollingNotifier.value = true;
  } else if (notification is ScrollEndNotification) {
    _iveScrollIdleTimer?.cancel();
    // Debounced, not immediate -- an instant snap-back the moment velocity
    // hits zero reads as flicker on a fast, short scroll (very common
    // flicking through a list); 400ms is long enough to settle past that
    // without meaningfully delaying the avatar's return once reading resumes.
    _iveScrollIdleTimer = Timer(const Duration(milliseconds: 400), () {
      iveScrollingNotifier.value = false;
    });
  }
  return false; // never consume -- let it keep bubbling to real listeners.
}

class IveRouteObserver extends NavigatorObserver {
  void _notify(Route route) {
    final name = route.settings.name ?? '';
    if (name.isNotEmpty) iveRouteNotifier.value = name;
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    _notify(route);
    if (route is PopupRoute) _iveModalCountChanged(1);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    if (previousRoute != null) _notify(previousRoute);
    if (route is PopupRoute) _iveModalCountChanged(-1);
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    // Codex Gate precedent (COMMERCIAL-EXPERIENCE-CLOSURE-16 P2) — a modal
    // can leave the tree via removal (e.g. programmatic dismissal) rather
    // than a "normal" pop; only counting didPop would leak this counter
    // upward forever in that path, permanently hiding IveOverlay.
    if (route is PopupRoute) _iveModalCountChanged(-1);
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    if (newRoute != null) _notify(newRoute);
    if (oldRoute is PopupRoute) _iveModalCountChanged(-1);
    if (newRoute is PopupRoute) _iveModalCountChanged(1);
  }
}

// ── Overlay ───────────────────────────────────────────────────────────────────

class IveOverlay extends ConsumerStatefulWidget {
  const IveOverlay({super.key, required this.navigatorKey});

  // STABILITY-10 — app.dart's MaterialApp.router `builder` mounts this
  // widget as a Stack SIBLING of `child` (the real GoRouter-managed
  // Router/Navigator), never a DESCENDANT of it -- the exact same
  // structural position IveIntroGate occupied (mission STABILITY-09-FIX).
  // A symbolicated production crash (same signature: "Null check operator
  // used on a null value" -> showModalBottomSheet -> Navigator.of)
  // confirmed _openChat's ancestor-based Navigator lookup fails from here
  // just as it did for IveIntroGate. This is the SAME GlobalKey app.dart
  // passes as GoRouter's own `navigatorKey` (and to IveIntroGate) -- the
  // existing root navigator GoRouter already manages, not a second,
  // competing Navigator architecture.
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  ConsumerState<IveOverlay> createState() => _IveOverlayState();
}

class _IveOverlayState extends ConsumerState<IveOverlay> {
  Offset? _position;
  bool _dragging = false;

  // COMMERCIAL-EXPERIENCE-CLOSURE-17A (IVE Full-Footprint Collision
  // Closure, Codex final-audit P1 ACCEPTED) — placement must react to
  // the CURRENT IVE VISUAL FOOTPRINT (whatever is actually being shown:
  // avatar alone, or avatar+bubble+actions), not just the avatar's own
  // 56x56. `_bubbleKey` measures the bubble's real rendered size (it's
  // always laid out, even while invisible -- see `_IveBubble`'s own
  // wiring below -- so this is kept fresh continuously, not only once
  // the bubble becomes visible). `_measuredBubbleSize` is the
  // last-known-good real measurement; `_bubbleMeasureScheduled` is the
  // same once-per-frame guard `IveExclusionRegion` already uses, so this
  // never measures more than once per frame and never loops (a stable
  // measurement is a no-op; see `_measureBubble` below).
  final GlobalKey _bubbleKey = GlobalKey();
  Size? _measuredBubbleSize;
  bool _bubbleMeasureScheduled = false;
  // COMMERCIAL-EXPERIENCE-CLOSURE-17A (Codex final audit, P2 ACCEPTED) —
  // which content `_measuredBubbleSize` actually describes. Without this,
  // a stale measurement from a SHORTER previous message/issue could be
  // reused for a frame after content changes to something taller, before
  // the next post-frame measurement catches up -- `_effectiveFootprint`
  // falls back to the conservative bound instead whenever this doesn't
  // match the current content (see its own doc comment).
  Object? _measuredBubbleContentKey;

  @override
  void initState() {
    super.initState();
    iveRouteNotifier.addListener(_onRouteChange);
    // COMMERCIAL-EXPERIENCE-CLOSURE-16 — owner feedback (live physical +
    // web QA): the floating avatar/bubble must disappear while the chat
    // dialog/sheet is open (redundant with the portrait now shown inside
    // it) and reappear once it closes. Same listener pattern as
    // iveRouteNotifier just above, not a new mechanism.
    iveChatOpenNotifier.addListener(_onChatOpenChange);
    // COMMERCIAL-EXPERIENCE-CLOSURE-16R — generic modal-collision guard
    // (see iveModalOpenNotifier's own doc comment above); same listener
    // pattern, not a new mechanism.
    iveModalOpenNotifier.addListener(_onChatOpenChange);
    // GATE-17-FINAL-CLOSURE (Section 03) — same listener pattern, driving
    // the scroll-aware compaction in build() below; see
    // ivePageScrollNotification's doc comment for the mechanism itself.
    iveScrollingNotifier.addListener(_onChatOpenChange);
    // GATE-17-FINAL-CLOSURE (physical Android feedback, 2026-09-21) — same
    // listener pattern, driving the Android-only redundant-CTA guard in
    // build() below; see iveInlineAskVisibleNotifier's own doc comment.
    iveInlineAskVisibleNotifier.addListener(_onChatOpenChange);
    // GATE-17-FINAL-CLOSURE (IVE Adaptive Resting Placement) — same listener
    // pattern; a screen registering/updating/unregistering an
    // IveExclusionRegion must be able to push the avatar off it even with
    // no other state change (route/scroll/modal all unchanged).
    iveExclusionRegionsNotifier.addListener(_onChatOpenChange);
    // IVE-COMMERCIAL-STABILITY-09O — reuses this already-existing lifecycle
    // callback; no new listener.
    IveForensicSnapshot.overlayMounted = true;
  }

  @override
  void dispose() {
    iveRouteNotifier.removeListener(_onRouteChange);
    iveChatOpenNotifier.removeListener(_onChatOpenChange);
    iveModalOpenNotifier.removeListener(_onChatOpenChange);
    iveScrollingNotifier.removeListener(_onChatOpenChange);
    iveInlineAskVisibleNotifier.removeListener(_onChatOpenChange);
    iveExclusionRegionsNotifier.removeListener(_onChatOpenChange);
    // IVE-COMMERCIAL-STABILITY-09O (Codex Gate, P2 ACCEPTED) — a dispose
    // mid-drag (e.g. a fast sign-out while dragging) would otherwise leave
    // overlayDragging stuck true forever, misleadingly implying an
    // in-progress drag at the moment of some LATER, unrelated crash.
    IveForensicSnapshot.overlayMounted = false;
    IveForensicSnapshot.overlayDragging = false;
    super.dispose();
  }

  void _onRouteChange() {
    final route = iveRouteNotifier.value;
    ref.read(iveProvider.notifier).setRoute(route);
    ref.read(iveMemoryProvider.notifier).setRoute(route);
  }

  void _onChatOpenChange() => setState(() {});

  bool get _isDesktop => MediaQuery.of(context).size.width >= 1024;

  // IVE-EXPERIENCE-V1-06QA (live-QA gate-2 defect, Codex-confirmed P1) —
  // `_position.dx` is the column's distance from the RIGHT edge of the
  // screen, not a left-x coordinate. The column (bubble + avatar, sized to
  // fit its widest child, up to the bubble's `maxWidth: 220`) used to be
  // anchored via `Positioned(left: screen.width - 88, ...)`. That assumed
  // the column was only ~88px wide (avatar + margin), but the bubble is up
  // to 220px wide, so the right-aligned avatar rendered `220 - 88 = 132px`
  // past the visible edge on every desktop-width screen -- unreachable,
  // regardless of viewport width, whenever the bubble was wide enough to
  // hit maxWidth (e.g. any real alert message). Anchoring with `right:`
  // instead (see build() below) makes the column grow leftward from a
  // fixed right margin, so its right-aligned avatar is always exactly
  // `dx` away from the screen's right edge no matter how wide the bubble
  // gets -- structurally immune to this class of overflow.
  // GATE-17-FINAL-CLOSURE (mission Section 03, owner-supplied physical
  // evidence across 6 screens: Command Center, Cofre de Conhecimento,
  // Business Dashboard, Biblioteca de Conteúdo, Opportunity Lab, Action
  // Engine) — the previous mobile default (right:80, top:height-200) sat
  // squarely inside the same fixed viewport band that: (a) wide/labeled
  // FloatingActionButtons ("+ Novo Item", "+ Nova Oportunidade") occupy
  // near the bottom-right, since a label-width FAB's left edge extends
  // well past a plain circular FAB's, and (b) ordinary scrolled card
  // content (e.g. Command Center's "Inteligência do Ecossistema" card,
  // a Persona card's trailing score label) naturally passes through when
  // scrolled into view, because this overlay is pinned to the VIEWPORT,
  // not to any one screen's content. A plain circular FAB (Performance's
  // "+") happened to clear the old offset, which is why mission 16R's
  // fix (hiding the overlay for actual PopupRoute modals) looked
  // sufficient from that one screen alone. This does not claim to make
  // collision with arbitrary scrolled content structurally impossible
  // (that would need each screen's Scaffold to reserve space for this
  // overlay, a bigger architectural change flagged separately) — it only
  // pushes the DEFAULT (undragged) position higher and closer to the true
  // corner, clearing the common single-row FAB band confirmed by physical
  // testing. A user who has dragged the bubble keeps their own position
  // (see _position's drag-persists behavior below); this only changes
  // where a FRESH session starts.
  //
  // GATE-17-FINAL-CLOSURE (IVE Adaptive Resting Placement) — the mobile
  // branch this used to have (a single fixed Offset(8, height-320)) is
  // exactly the per-screen-agnostic-but-still-fixed-corner problem the
  // Owner-approved placement engine (ive_placement_engine.dart) replaces:
  // a corner that happens to clear the FAB band on most screens still
  // coincides with essential content on others (Home's project score,
  // Action Engine's "Concluir", Knowledge Vault's "Trocar Projeto",
  // Dashboard's "Campanhas" card). Desktop keeps this untouched fixed
  // corner (Section 3 of the mission: only mobile gets adaptive
  // placement) -- see build()'s `_isDesktop` branch below.
  Offset _defaultDesktopPosition(Size screen) {
    // Desktop: safe corner — bottom-right with extra margin to avoid overlapping content
    return Offset(88, screen.height - 220);
  }

  // The avatar's own on-screen footprint -- used as the WHOLE placement
  // footprint only while no bubble is actively shown (see
  // `_effectiveFootprint` below for the bubble-active case).
  static const _avatarFootprint = Size(56, 56); // IveAvatarSize.compact.dp

  // Matches the SizedBox(height: 6) between the bubble and the avatar in
  // the Column below -- part of the real combined footprint whenever the
  // bubble is active.
  static const _kBubbleGap = 6.0;

  // COMMERCIAL-EXPERIENCE-CLOSURE-17A (IVE Full-Footprint Collision
  // Closure) — a real measurement (`_measuredBubbleSize`) isn't available
  // until at least one frame has completed. This is the conservative
  // bound used only until then, or transiently for one frame after a
  // brand-new message/issue lands that's taller than anything measured
  // before. `_IveBubble`'s own `maxLines: 5` + ellipsis on the message,
  // and `recommendedActions` being a small hardcoded set (at most 3 short
  // static labels -- see IveIssue's factory constructors, not open-ended
  // backend data), make this a genuine upper bound, not a guess: 220
  // matches the bubble's own `maxWidth`; 180 comfortably covers 5 text
  // lines + icon row + up to 3 wrapped action chips + container padding.
  static const _kFallbackBubbleFootprint = Size(220, 180);

  // Small residual safety margin, NOT the primary bound anymore (Codex
  // final audit, P1 ACCEPTED: a fixed reserve alone isn't a guarantee for
  // dynamic content). Real measurement (`_measuredBubbleSize`) is the
  // primary source of truth; this only absorbs sub-pixel rounding and the
  // rare single-frame lag between a message changing and its next
  // measurement landing.
  static const _kFootprintSafetyMargin = 16.0;

  // COMMERCIAL-EXPERIENCE-CLOSURE-17A (IVE Full-Footprint Collision
  // Closure, Codex final-audit P1 ACCEPTED) — "avatar safe" is not the
  // same as "the whole visible IVE is safe": when the bubble is showing,
  // it can extend up to 220px wide and well above the avatar, and could
  // still cover an exclusion region even while the 56x56 avatar itself
  // does not. This returns the footprint that ACTUALLY represents what's
  // currently rendered, matching the mission's STATE A/B/C model:
  // STATE A (avatar only, no bubble) -> avatar footprint alone.
  // STATE B/C (avatar + bubble, +actions) -> the real measured combined
  // box (falls back to a conservative bound only until a measurement is
  // available -- see `_kFallbackBubbleFootprint`).
  // STATE D (chat/modal open) -> unreached; build() already returns
  // SizedBox.shrink() before computing any footprint in that case.
  //
  // COMMERCIAL-EXPERIENCE-CLOSURE-17A (Codex final audit, P2 ACCEPTED) —
  // `_measuredBubbleSize` only describes the content it was actually
  // measured for (`_measuredBubbleContentKey`). If the message/issue just
  // changed to something the layout hasn't been measured for YET, a stale
  // (possibly smaller) old measurement must not be trusted -- fall back to
  // the conservative bound for that one transitional frame instead,
  // exactly like the "no measurement at all yet" case already did.
  Size _effectiveFootprint(bool bubbleActive, Object currentContentKey) {
    if (!bubbleActive) return _avatarFootprint;
    final measurementIsCurrent = _measuredBubbleSize != null &&
        _measuredBubbleContentKey == currentContentKey;
    final bubbleSize =
        measurementIsCurrent ? _measuredBubbleSize! : _kFallbackBubbleFootprint;
    return Size(
      bubbleSize.width > _avatarFootprint.width
          ? bubbleSize.width
          : _avatarFootprint.width,
      bubbleSize.height + _kBubbleGap + _avatarFootprint.height,
    );
  }

  // COMMERCIAL-EXPERIENCE-CLOSURE-17A — identity proxy for "what the bubble
  // is currently showing," cheap to compute every build (no Equatable
  // dependency on IveState/IveIssue). Message text plus the issue's error
  // code and action count is enough to distinguish any content change that
  // could plausibly change the bubble's rendered height.
  Object _bubbleContentKey(IveState state) => (
        state.message,
        state.activeIssue?.errorCode,
        state.activeIssue?.recommendedActions.length ?? 0,
      );

  // COMMERCIAL-EXPERIENCE-CLOSURE-17A — same once-per-frame guarded
  // post-frame measurement pattern as IveExclusionRegion (this file's own
  // sibling mechanism), applied to the overlay's OWN bubble instead of a
  // screen's content. Scheduled on every build (regardless of whether the
  // bubble is currently visible -- it's always laid out, see the Column
  // below) so a fresh measurement is ready by the time the bubble
  // actually becomes active, not just after.
  void _scheduleBubbleMeasure() {
    if (_bubbleMeasureScheduled) return;
    _bubbleMeasureScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) => _measureBubble());
  }

  void _measureBubble() {
    _bubbleMeasureScheduled = false;
    if (!mounted) return;
    final box = _bubbleKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    final size = box.size;
    // COMMERCIAL-EXPERIENCE-CLOSURE-17A — the content key this RenderBox
    // was actually laid out for. ref.read is safe here: postFrameCallbacks
    // run outside build, so this is an ordinary read, not a subscription.
    final measuredForKey = _bubbleContentKey(ref.read(iveProvider));
    if (_measuredBubbleSize == size && _measuredBubbleContentKey == measuredForKey) {
      return; // no-op, avoid churn/loops
    }
    _measuredBubbleSize = size;
    _measuredBubbleContentKey = measuredForKey;
    // COMMERCIAL-EXPERIENCE-CLOSURE-17A — a changed measurement can affect
    // placement whether or not the bubble is currently VISIBLE: it always
    // affects `_bubbleLayoutHeight` (the viewport-fit reserve, below,
    // which applies regardless of visibility because the bubble is always
    // laid out), and additionally affects the collision footprint itself
    // when the bubble is active. So always resync, not just while active.
    setState(() {});
  }

  // COMMERCIAL-EXPERIENCE-CLOSURE-17A (regression found and fixed while
  // implementing full-footprint collision closure) — the bubble is ALWAYS
  // laid out in the Column below, opacity/IgnorePointer only hide it
  // visually; the avatar renders BELOW it regardless. So even in STATE A
  // (avatar only, bubbleActive == false), the candidate/clamp Y math still
  // needs to reserve real room for that always-present layout height, or
  // the avatar spills off-screen exactly like the bug this mission
  // already fixed once for a fixed-constant reserve -- just now for a
  // dynamic one. This is DELIBERATELY separate from the collision
  // footprint (`_effectiveFootprint`): an invisible bubble reserves
  // layout space (viewport-fit concern) but isn't actually blocking
  // anything visually (collision concern) -- see `_effectiveFootprint`'s
  // own doc comment for why collision stays avatar-only in STATE A.
  // COMMERCIAL-EXPERIENCE-CLOSURE-17A (Codex final audit, P2 ACCEPTED) —
  // same staleness guard as `_effectiveFootprint`: a measurement that
  // predates the current message/issue could understate the real height,
  // which is exactly backwards for a reserve meant to be a safe upper
  // bound. Falls back to the conservative bound whenever the last
  // measurement doesn't match current content.
  double _bubbleLayoutHeight(Object currentContentKey) {
    final measurementIsCurrent = _measuredBubbleSize != null &&
        _measuredBubbleContentKey == currentContentKey;
    return (measurementIsCurrent ? _measuredBubbleSize! : _kFallbackBubbleFootprint)
        .height;
  }

  @override
  Widget build(BuildContext context) {
    // IVE-EXPERIENCE-V1-06QA (live-QA defect) — this overlay is mounted
    // globally in app.dart's Stack with NO route awareness at all, so
    // before this fix it rendered on every screen including /login and
    // /splash. IveIntroGate (mounted in the same Stack) already gated
    // itself on `currentProfileProvider` resolving to a non-null profile
    // — the exact same "authenticated and app-state stable" signal used
    // elsewhere in app.dart — but that comment explicitly (and wrongly)
    // assumed IveOverlay needed no equivalent gate ("Never shown on
    // Splash/Login" referred only to the intro sheet, not this widget).
    //
    // Codex adversarial review (this fix, P1, ACCEPTED) — gating on
    // `currentProfileProvider` alone fails closed for the unauthenticated/
    // loading/error states, but not for an IN-FLIGHT sign-out: AuthNotifier.
    // signOut() awaits the Supabase call BEFORE invalidating the profile
    // provider (auth_provider.dart), so a previously-resolved non-null
    // profile can briefly remain cached while sign-out is still in
    // progress. Also requiring `authStateProvider`'s session to be
    // non-null closes this: that stream reflects Supabase's own
    // client-side auth state change directly, independent of when this
    // app's own profile-invalidation call happens to run afterward.
    final hasSession =
        ref.watch(authStateProvider).valueOrNull?.session != null;
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    // IVE-COMMERCIAL-STABILITY-09O — reuses this already-existing provider
    // watch; no new subscription.
    IveForensicSnapshot.profileResolved = profile != null;
    if (!hasSession || profile == null) {
      // IVE-COMMERCIAL-STABILITY-09O (Codex Gate, P2 ACCEPTED) — this early
      // return skips the `issuePresent`/`overlayDragging` writes below, so
      // without this, a stale `true` from BEFORE sign-out/session-loss
      // would misleadingly survive into a later crash's forensic snapshot
      // even though the overlay (and its issue bubble) is no longer shown.
      IveForensicSnapshot.issuePresent = false;
      IveForensicSnapshot.overlayDragging = false;
      return const SizedBox.shrink();
    }

    // COMMERCIAL-EXPERIENCE-CLOSURE-16 — hide the floating avatar+bubble
    // entirely while the chat dialog/sheet is open (see
    // context_copilot_widget.dart's iveChatOpenNotifier doc comment).
    // Deliberately does NOT skip the issuePresent/overlayDragging writes
    // below like the auth early-return above does -- unlike sign-out,
    // this is a purely visual, momentary state with no forensic
    // implication, and the underlying IVE state itself is unchanged while
    // the chat is open.
    // COMMERCIAL-EXPERIENCE-CLOSURE-16R — generalizes the check above to
    // ANY open modal (dialog/bottom sheet), not just the copilot chat one
    // -- see iveModalOpenNotifier's doc comment for why this is a single
    // app-wide NavigatorObserver check rather than a per-screen fix.
    // GATE-17-FINAL-CLOSURE (Section 03/04, "react correctly to keyboard")
    // — a form's Save/submit button routinely sits directly above an open
    // keyboard (Performance's "Nova Métrica" among others); the floating
    // avatar has no safe place to sit in that band, so it hides rather than
    // guess. MediaQuery.viewInsets.bottom is the standard, centralized
    // Flutter signal for "the keyboard is currently showing" -- true on
    // every screen with a focused text field, again with no per-screen
    // wiring required.
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    // GATE-17-FINAL-CLOSURE (physical Android feedback, 2026-09-21) —
    // Android only, per owner instruction ("somente no Android a versão web
    // deve ficar intocada"): the floating avatar is redundant with a
    // screen's own dedicated "Perguntar à IVE" CTA (see
    // iveInlineAskVisibleNotifier's doc comment for which ones and why web
    // is excluded).
    // COMMERCIAL-EXPERIENCE-CLOSURE-17A (Codex final audit, P2 ACCEPTED) —
    // `!kIsWeb` is "not web", not "is Android": this project currently has
    // no windows/macos/linux platform folders at all (Android+Web only),
    // so the two were equivalent in practice, but a real desktop target
    // added later would have silently inherited this Android-only guard
    // too. `defaultTargetPlatform` names the actual platform instead.
    final inlineAskRedundant = defaultTargetPlatform == TargetPlatform.android &&
        iveInlineAskVisibleNotifier.value;
    if (iveChatOpenNotifier.value ||
        iveModalOpenNotifier.value ||
        keyboardOpen ||
        inlineAskRedundant) {
      return const SizedBox.shrink();
    }

    final state = ref.watch(iveProvider);
    // IVE-COMMERCIAL-STABILITY-09O — reuses the `state` already read above
    // for the widget's own rendering; no new watch.
    IveForensicSnapshot.issuePresent = state.activeIssue != null;
    final screen = MediaQuery.of(context).size;
    final mediaPadding = MediaQuery.of(context).padding;
    final safeBottom = mediaPadding.bottom;
    // COMMERCIAL-EXPERIENCE-CLOSURE-17A — same condition the Column below
    // uses for the bubble's own opacity/ignoring (state.bubbleVisible &&
    // !_dragging): "is the bubble actually the thing on screen right now."
    final bubbleActive = state.bubbleVisible && !_dragging;
    // COMMERCIAL-EXPERIENCE-CLOSURE-17A (Codex final audit, P2 ACCEPTED) —
    // computed once per build, threaded into every place that needs to
    // know whether `_measuredBubbleSize` is trustworthy for THIS content.
    final contentKey = _bubbleContentKey(state);
    // GATE-17-FINAL-CLOSURE (IVE Adaptive Resting Placement, mission
    // Section 3/6) — desktop keeps its pre-existing fixed safe corner
    // untouched. Mobile recomputes through the placement engine on every
    // non-dragging build: cheap pure geometry (a handful of candidate
    // Rects against whatever IveExclusionRegions are currently mounted,
    // no tree scanning), and its continuity preference means a
    // still-safe `_position` comes back unchanged, so this does not
    // reintroduce jitter. Skipped entirely while `_dragging` so the
    // engine never fights an in-progress pan gesture; the drag handler's
    // own clamp already keeps mid-drag positions on-screen, and the
    // first build AFTER the drag ends re-validates the dropped position
    // here (Section 6: "re-validar ao final do drag") -- safe, it's kept
    // (continuity); colliding with a region, the engine moves it to the
    // nearest safe candidate.
    if (_isDesktop) {
      _position ??= _defaultDesktopPosition(screen);
    } else if (!_dragging) {
      // COMMERCIAL-EXPERIENCE-CLOSURE-17A (real regression found and fixed
      // during physical verification) — `_position.dy` (the anchor) is the
      // TOP of the whole rendered column (Positioned(top: _position.dy,
      // ...) below); the bubble is ALWAYS laid out there (opacity/
      // IgnorePointer only hide it visually), regardless of `bubbleActive`.
      // When NOT active (STATE A), `avatarFootprint` below deliberately
      // covers only the avatar (an invisible bubble isn't blocking
      // anything) -- but the avatar itself still renders BELOW the anchor
      // by this same distance, since the invisible bubble still occupies
      // that space. Physically reproduced: the engine validated a
      // candidate/previous position using the AVATAR footprint positioned
      // AT the anchor, while the real avatar rendered `bubbleOffsetY`
      // lower -- so a candidate that cleared every exclusion at the
      // anchor's own Y still left the real, displaced avatar resting on
      // a project's score. `footprintOffsetY` (passed below) is what
      // fixes this: it tells the engine exactly how far below the anchor
      // the collision footprint actually starts.
      final bubbleOffsetY =
          bubbleActive ? 0.0 : _bubbleLayoutHeight(contentKey) + _kBubbleGap;
      _position = computeRestingPosition(IvePlacementInput(
        screenSize: screen,
        safeArea: IveSafeAreaInsets(
          top: mediaPadding.top,
          bottom: safeBottom,
          left: mediaPadding.left,
          right: mediaPadding.right,
        ),
        // COMMERCIAL-EXPERIENCE-CLOSURE-17A (IVE Full-Footprint Collision
        // Closure, Codex final-audit P1 ACCEPTED) — this used to be the
        // fixed 56x56 avatar footprint unconditionally, which meant
        // "avatar safe" got reported as "IVE safe" even while a wide,
        // tall bubble was actually the thing rendered on screen and could
        // still cover an exclusion region the avatar itself cleared. Now
        // reflects whatever is ACTUALLY currently visible -- see
        // `_effectiveFootprint`'s own doc comment for the STATE A/B/C
        // model this implements.
        avatarFootprint: _effectiveFootprint(bubbleActive, contentKey),
        // See `bubbleOffsetY` above -- this is what makes the engine test
        // collisions at the avatar's REAL position, not the anchor's.
        footprintOffsetY: bubbleOffsetY,
        // Total space to reserve between the anchor and the true bottom
        // edge for VIEWPORT-FIT purposes: `bubbleOffsetY` (the same real,
        // always-laid-out displacement) plus a small rounding margin.
        verticalReserve: bubbleOffsetY + _kFootprintSafetyMargin,
        exclusions: iveExclusionRegionsNotifier.value,
        previousPosition: _position,
      ));
    }
    // COMMERCIAL-EXPERIENCE-CLOSURE-17A — keeps `_measuredBubbleSize`
    // fresh every build (the bubble is always laid out, see the Column
    // below), so a real measurement is ready by the time the bubble
    // actually becomes active rather than only starting to measure once
    // it already is.
    _scheduleBubbleMeasure();
    // GATE-17-FINAL-CLOSURE (Section 03) — true only while a page is
    // actively being scrolled AND there's nothing important currently
    // shown (no open alert bubble, not mid-drag); see
    // ivePageScrollNotification's doc comment for the underlying signal.
    // Deliberately does not apply while `state.bubbleVisible` -- a message
    // the user hasn't dismissed yet must stay fully legible even if they
    // happen to scroll the page behind it.
    final isCompactingForScroll =
        iveScrollingNotifier.value && !_dragging && !state.bubbleVisible;

    // On desktop clamp to avoid navigation bars / toolbars.
    // COMMERCIAL-EXPERIENCE-CLOSURE-17A (Codex final audit, P2 ACCEPTED) —
    // the mobile branch used to be a flat `screen.height - 100`, independent
    // of the bubble's real (always-laid-out, even while hidden mid-drag)
    // height -- the same class of bug already fixed for the resting
    // (non-dragging) placement engine, just reachable here via a manual
    // drag instead. Dragging always renders with the bubble inactive (see
    // `bubbleActive`/IgnorePointer above), so the real avatar bottom while
    // dragging is `anchor.dy + _bubbleLayoutHeight + _kBubbleGap +
    // _avatarFootprint.height` -- this bounds THAT, not just the anchor.
    final maxY = _isDesktop
        ? screen.height - 140 - safeBottom
        : screen.height -
            safeBottom -
            _bubbleLayoutHeight(contentKey) -
            _kBubbleGap -
            _avatarFootprint.height -
            16;

    return Positioned(
      right: _position!.dx,
      top: _position!.dy,
      child: GestureDetector(
        onPanStart: (_) => setState(() {
          _dragging = true;
          IveForensicSnapshot.overlayDragging = true;
        }),
        onPanUpdate: (d) => setState(() {
          // dx tracks distance-from-right: dragging right (positive delta.dx)
          // moves the widget closer to the right edge, so dx DECREASES.
          _position =
              Offset(_position!.dx - d.delta.dx, _position!.dy + d.delta.dy)
                  .clamp(
            Offset.zero,
            Offset(screen.width - 72, maxY),
          );
        }),
        onPanEnd: (_) => setState(() {
          _dragging = false;
          IveForensicSnapshot.overlayDragging = false;
        }),
        // GATE-17-FINAL-CLOSURE (Section 03) — recedes (faded + shrunk,
        // never fully invisible so spatial continuity isn't lost) while
        // isCompactingForScroll is true, i.e. while content is actively
        // scrolling underneath with no alert bubble open. Still tappable
        // at reduced opacity -- during an active scroll gesture, touch
        // input is on the list being dragged, not this small a target.
        child: AnimatedOpacity(
          // Key exists only so tests can assert on this specific
          // AnimatedOpacity's current value unambiguously -- the bubble
          // below has its own, separate AnimatedOpacity.
          key: const ValueKey('iveScrollCompactionOpacity'),
          duration: const Duration(milliseconds: 200),
          opacity: isCompactingForScroll ? 0.35 : 1.0,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 200),
            scale: isCompactingForScroll ? 0.7 : 1.0,
            alignment: Alignment.bottomRight,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Speech bubble — IgnorePointer evita hitbox invisível quando opacity=0
                IgnorePointer(
                  ignoring: !bubbleActive,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 350),
                    opacity: bubbleActive ? 1.0 : 0.0,
                    child: AnimatedSlide(
                      duration: const Duration(milliseconds: 350),
                      offset: bubbleActive ? Offset.zero : const Offset(0, 0.15),
                      curve: Curves.easeOut,
                      // COMMERCIAL-EXPERIENCE-CLOSURE-17A — this key is
                      // what `_measureBubble` reads via
                      // `_bubbleKey.currentContext?.findRenderObject()`.
                      // Always built (even while invisible via opacity 0
                      // above), so its size stays measurable continuously
                      // -- see `_scheduleBubbleMeasure`'s own doc comment.
                      child: _IveBubble(
                        key: _bubbleKey,
                        message: state.message,
                        expression: state.expression,
                        activeIssue: state.activeIssue,
                        onDismiss: () {
                          // Overlay global, sem projeto específico em foco — ver
                          // comentário do provider em ive_context_provider.dart.
                          final ctx = ref
                              .read(iveContextDataProvider(null))
                              .valueOrNull;
                          if (ctx != null && ctx.alertId.isNotEmpty) {
                            ref
                                .read(iveMemoryProvider.notifier)
                                .dismissAlert(ctx.alertId);
                          }
                          ref.read(iveProvider.notifier).dismissBubble();
                        },
                        onChat: state.activeIssue == null
                            ? () => _openChat(state.screenName)
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                // ── New IveAvatar (replaces old IveAvatarWidget) ─────────────────
                // IVE-AVATAR-COMMERCIAL-FALLBACK-04 (Codex P2): the avatar is
                // mounted with interactive:false (overlay owns the tap), which
                // skips IveAvatar's own Semantics wrapper — so the overlay
                // provides the screen-reader label/button role here instead.
                Semantics(
                  label: AppLocalizations.of(context)!.iveSemanticsLabel,
                  button: true,
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: () {
                      if (_dragging) return;
                      if (state.bubbleVisible) {
                        ref.read(iveProvider.notifier).dismissBubble();
                      } else {
                        _openChat(state.screenName);
                      }
                    },
                    child: AnimatedScale(
                      scale: _dragging ? 0.92 : 1.0,
                      duration: const Duration(milliseconds: 150),
                      child: IveAvatar(
                        size: IveAvatarSize.compact,
                        showStatusRing: true,
                        interactive: false, // overlay owns the tap
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openChat(String screenName) {
    // STABILITY-10 — `context` (this State's own BuildContext) sits ABOVE
    // the real Router/Navigator, same as IveIntroGate did; showCopilotChat
    // internally calls showModalBottomSheet, whose Navigator.of lookup
    // would fail from there exactly like the original STABILITY-09 crash.
    // widget.navigatorKey.currentState.overlay.context is a genuine
    // Navigator DESCENDANT (the Overlay the Navigator builds internally),
    // from which ancestor lookup correctly finds this same Navigator --
    // the Navigator's own context would NOT qualify (Navigator.of's
    // ancestor search starts at the given context's PARENT, so calling it
    // from the Navigator's own context searches ABOVE the Navigator, not
    // the Navigator itself). Unlike IveIntroGate's app-boot race, this
    // fires from a synchronous user tap -- the Navigator/Overlay are
    // already mounted by the time a user can interact with anything, so no
    // bounded retry is needed here; the null case is purely defensive.
    final overlayContext = widget.navigatorKey.currentState?.overlay?.context;
    if (overlayContext == null) return;

    ref.read(iveMemoryProvider.notifier).incrementInteraction();
    // Overlay global — sempre projectId: null. Se o usuário estiver
    // dentro do Project Command Center de um projeto específico, esse
    // botão de tela usa seu próprio showCopilotChat com o projectId real
    // (ver project_command_center_screen.dart); este é o avatar
    // FLUTUANTE, presente em toda tela, sem noção de "projeto atual".
    final ctx = ref.read(iveContextDataProvider(null)).valueOrNull;
    // IVE-COMMERCIAL-TARGETED-REMEDIATION-04 — conversão movida para
    // CopilotContextData.fromIveContext() (fonte única, também usada por
    // ive_detail_sheet.dart) em vez de uma cópia privada só deste widget.
    final contextData = ctx != null
        ? CopilotContextData.fromIveContext(ctx)
        : const CopilotContextData();
    showCopilotChat(
      overlayContext,
      screenName: _routeToName(screenName),
      contextData: contextData,
      request: IveInteractionRequest(
        sourceModule: 'global_overlay',
        operationType: IveOperationType.ask,
      ),
    );
  }

  String _routeToName(String route) {
    const map = <String, String>{
      '/projects': 'Projetos',
      '/opportunity-lab': 'Oportunidades',
      '/ecosystem': 'Decisões',
      '/ecosystem/briefing': 'Briefing',
      '/ecosystem/resources': 'Recursos',
      '/personas': 'Personas',
      '/knowledge': 'Conhecimento',
      '/action-engine': 'Ações',
      '/intelligence-debug': 'Debug Hub',
      '/market-intelligence': 'Inteligência de Mercado',
      '/roi-tracker': 'ROI Tracker',
    };
    return map[route] ?? route;
  }
}

// ── Speech bubble ─────────────────────────────────────────────────────────────

class _IveBubble extends StatelessWidget {
  final String message;
  final IveExpression expression;
  final IveIssue? activeIssue;
  final VoidCallback onDismiss;
  final VoidCallback? onChat;

  const _IveBubble({
    super.key,
    required this.message,
    required this.expression,
    required this.onDismiss,
    this.activeIssue,
    this.onChat,
  });

  bool get _hasIssue => activeIssue != null;

  String get _moodIcon {
    if (_hasIssue) return '⚠';
    switch (expression) {
      case IveExpression.excited:
        return '✦';
      case IveExpression.thinking:
        return '◈';
      case IveExpression.winking:
        return '◉';
      case IveExpression.neutral:
        return '⬡';
      case IveExpression.happy:
        return '◈';
    }
  }

  Color get _accentColor =>
      _hasIssue ? const Color(0xFFFF4560) : const Color(0xFF7B5CF6);

  Color get _iconColor =>
      _hasIssue ? const Color(0xFFFF4560) : const Color(0xFF9B8FFF);

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1535),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
              bottomLeft: Radius.circular(14),
              bottomRight: Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: _accentColor.withOpacity(0.45)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    // COMMERCIAL-EXPERIENCE-CLOSURE-17A (Codex final audit,
                    // P1 ACCEPTED, carried into the full-footprint rework)
                    // — since Section 6 explicitly says the placement
                    // shouldn't lean on a fixed constant as "architectural
                    // truth" for dynamic content, `_measureBubble` now
                    // measures this bubble's REAL rendered size instead of
                    // assuming a budget -- but that measurement is only as
                    // trustworthy as this content actually being bounded.
                    // `message` interpolates caller-supplied strings (a
                    // knowledge item's name, an action's title -- see
                    // IveIssue's factory constructors), which aren't
                    // length-bounded upstream. Capping lines here is what
                    // makes the widget's own height genuinely bounded
                    // (recommendedActions, the other variable-height piece,
                    // is a small hardcoded set --
                    // at most 3 short static labels per IveIssue factory --
                    // not open-ended).
                    child: RichText(
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '$_moodIcon ',
                            style: TextStyle(color: _iconColor, fontSize: 11),
                          ),
                          TextSpan(
                            text: message,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onDismiss,
                    child: const Icon(Icons.close_rounded,
                        size: 14, color: Colors.white24),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_hasIssue)
                _IssueActions(issue: activeIssue!)
              else if (onChat != null)
                GestureDetector(
                  onTap: onChat,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: Color(0xFF7B5CF6),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        AppLocalizations.of(context)!.iveBubbleChatCta,
                        style: const TextStyle(
                          color: Color(0xFF9B8FFF),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Issue action buttons ──────────────────────────────────────────────────────

class _IssueActions extends StatelessWidget {
  const _IssueActions({required this.issue});
  final IveIssue issue;

  @override
  Widget build(BuildContext context) {
    final actions = issue.recommendedActions;
    if (actions.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: actions.map((a) => _IssueActionChip(action: a)).toList(),
    );
  }
}

class _IssueActionChip extends StatelessWidget {
  const _IssueActionChip({required this.action});
  final IveIssueAction action;

  static const _color = Color(0xFFFF4560);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (action.actionKey == 'dismiss') {
          Navigator.of(context, rootNavigator: true).maybePop();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _color.withOpacity(0.4)),
        ),
        child: Text(
          action.label,
          style: const TextStyle(
            color: _color,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

extension on Offset {
  Offset clamp(Offset min, Offset max) => Offset(
        dx.clamp(min.dx, max.dx),
        dy.clamp(min.dy, max.dy),
      );
}
