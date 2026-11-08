import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import 'package:ai_social_copilot/core/theme/app_motion.dart';
import 'package:ai_social_copilot/core/theme/app_tokens.dart';

/// InsightValues Dark Premium — shared UI kit.
///
/// Every screen builds from these instead of hand-rolled Containers, so
/// surfaces, spacing, motion and icon treatment stay identical app-wide.

// ── Background ──────────────────────────────────────────────────────────────

/// App-wide backdrop: graphite ground with two soft light fades (accent at
/// top-left, info at top-right) that dissolve into the ground. Painted once
/// behind the router; scaffolds are transparent so every screen sits on it.
class IvBackground extends StatelessWidget {
  const IvBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const RepaintBoundary(child: _Backdrop()),
        child,
      ],
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.ground),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Accent fade, top-left
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.9, -1.1),
                radius: 1.1,
                colors: [
                  AppColors.accent.withOpacity(0.13),
                  AppColors.accent.withOpacity(0.04),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
          // Info fade, top-right
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(1.1, -0.9),
                radius: 0.9,
                colors: [
                  AppColors.info.withOpacity(0.07),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // Vignette toward the bottom so long pages settle into the ground
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, AppColors.ground],
                stops: [0.55, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Motion ──────────────────────────────────────────────────────────────────

/// Fades a child in while it rises [offsetY] px. [index] staggers siblings.
/// Uses a single controller with an Interval for the delay (no timers), and
/// shows the final state immediately when reduced motion is requested.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.offsetY = 14,
    this.duration = AppMotion.medium,
  });

  final Widget child;
  final int index;
  final double offsetY;
  final Duration duration;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _t;

  @override
  void initState() {
    super.initState();
    final delay = AppMotion.stagger * math.min(widget.index, 10);
    final total = delay + widget.duration;
    _c = AnimationController(vsync: this, duration: total);
    final start = delay.inMicroseconds / total.inMicroseconds;
    _t = CurvedAnimation(
      parent: _c,
      curve: Interval(start, 1.0, curve: AppMotion.enter),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.isAnimating || _c.isCompleted) return;
    if (AppMotion.reduced(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _t.value,
        child: Transform.translate(
          offset: Offset(0, (1 - _t.value) * widget.offsetY),
          child: child,
        ),
      ),
    );
  }
}

/// Column whose children enter one after another.
class IvStagger extends StatelessWidget {
  const IvStagger({
    super.key,
    required this.children,
    this.gap = AppSpace.s4,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
  });

  final List<Widget> children;
  final double gap;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final out = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) out.add(SizedBox(height: gap));
      out.add(FadeSlideIn(index: i, child: children[i]));
    }
    return Column(crossAxisAlignment: crossAxisAlignment, children: out);
  }
}

/// Number that counts up to [value] when it first appears.
class IvCountUp extends StatelessWidget {
  const IvCountUp({
    super.key,
    required this.value,
    this.style,
    this.suffix = '',
    this.duration = AppMotion.chart,
  });

  final num value;
  final TextStyle? style;
  final String suffix;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final isInt = value is int;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: AppMotion.reduced(context) ? Duration.zero : duration,
      curve: AppMotion.emphasized,
      builder: (context, v, _) => Text(
        '${isInt ? v.round() : v.toStringAsFixed(1)}$suffix',
        style: (style ?? const TextStyle())
            .copyWith(fontFeatures: AppType.tabular),
      ),
    );
  }
}

// ── Surfaces ────────────────────────────────────────────────────────────────

/// The one card. Surface with a faint top-light fade, 1px line border,
/// hover lift + accent border on web/desktop, and press feedback.
class IvCard extends StatefulWidget {
  const IvCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpace.s4),
    this.accent,
    this.highlight = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// Optional colour for the border glow on hover / highlight.
  final Color? accent;

  /// Draws a soft tinted wash from the top-left (used for hero cards).
  final bool highlight;

  @override
  State<IvCard> createState() => _IvCardState();
}

class _IvCardState extends State<IvCard> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final tint = widget.accent ?? AppColors.accent;
    final interactive = widget.onTap != null;
    final active = interactive && _hover;

    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(
        color: active
            ? tint.withOpacity(0.45)
            : widget.highlight
                ? tint.withOpacity(0.28)
                : AppColors.line,
      ),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: widget.highlight
            ? [tint.withOpacity(0.14), AppColors.surface, AppColors.surface]
            : [
                Color.lerp(AppColors.surface, AppColors.ink, 0.025)!,
                AppColors.surface,
              ],
        stops: widget.highlight ? const [0.0, 0.55, 1.0] : null,
      ),
      boxShadow: active
          ? [
              BoxShadow(
                color: tint.withOpacity(0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ]
          : const [],
    );

    Widget card = AnimatedContainer(
      duration: AppMotion.short,
      curve: AppMotion.enter,
      decoration: decoration,
      child: Padding(padding: widget.padding, child: widget.child),
    );

    if (!interactive) return card;

    card = AnimatedScale(
      duration: AppMotion.micro,
      curve: AppMotion.enter,
      scale: _down ? 0.985 : 1,
      child: AnimatedSlide(
        duration: AppMotion.short,
        curve: AppMotion.enter,
        offset: Offset(0, active ? -0.006 : 0),
        child: card,
      ),
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _down = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: Semantics(button: true, child: card),
      ),
    );
  }
}

/// Icon in a tinted rounded tile with a soft fade — the single icon
/// treatment for cards, lists and recommendations.
class IvIconTile extends StatelessWidget {
  const IvIconTile(
    this.icon, {
    super.key,
    this.color = AppColors.accent,
    this.size = 40,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.22), color.withOpacity(0.06)],
        ),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

/// Small uppercase label above a value.
class IvEyebrow extends StatelessWidget {
  const IvEyebrow(this.text, {super.key, this.color = AppColors.inkSubtle});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: AppType.caption,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }
}

/// Section title row with an optional trailing action.
class IvSectionHeader extends StatelessWidget {
  const IvSectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.iconColor = AppColors.accent,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final IconData? icon;
  final Color iconColor;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          IvIconTile(icon!, color: iconColor, size: 28),
          const SizedBox(width: AppSpace.s3),
        ],
        Expanded(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: AppType.body,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(actionLabel!,
                    style: const TextStyle(fontSize: AppType.label)),
                const SizedBox(width: 2),
                const Icon(Icons.arrow_forward_rounded, size: 16),
              ],
            ),
          ),
      ],
    );
  }
}

/// Status / plan pill.
class IvBadge extends StatelessWidget {
  const IvBadge(
    this.label, {
    super.key,
    this.color = AppColors.inkMuted,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s2, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// KPI tile: eyebrow, animated value, optional footnote and trailing visual.
class IvStatCard extends StatelessWidget {
  const IvStatCard({
    super.key,
    required this.label,
    required this.value,
    this.valueText,
    this.suffix = '',
    this.footnote,
    this.footnoteColor = AppColors.inkMuted,
    this.icon,
    this.color = AppColors.accent,
    this.trailing,
    this.onTap,
  });

  final String label;

  /// Numeric value (counts up). Ignored when [valueText] is given.
  final num value;
  final String? valueText;
  final String suffix;
  final String? footnote;
  final Color footnoteColor;
  final IconData? icon;
  final Color color;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const valueStyle = TextStyle(
      color: AppColors.ink,
      fontSize: AppType.title,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
      height: 1.15,
    );
    return IvCard(
      onTap: onTap,
      accent: color,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 14, color: color),
                      const SizedBox(width: 6),
                    ],
                    Expanded(child: IvEyebrow(label)),
                  ],
                ),
                const SizedBox(height: AppSpace.s2),
                valueText != null
                    ? Text(valueText!, style: valueStyle)
                    : IvCountUp(value: value, suffix: suffix, style: valueStyle),
                if (footnote != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    footnote!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: footnoteColor,
                      fontSize: AppType.caption,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpace.s3),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Primary call to action: accent gradient, inner light, soft glow,
/// press + hover feedback.
class IvPrimaryAction extends StatefulWidget {
  const IvPrimaryAction({
    super.key,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.icon = Icons.arrow_forward_rounded,
  });

  final String label;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<IvPrimaryAction> createState() => _IvPrimaryActionState();
}

class _IvPrimaryActionState extends State<IvPrimaryAction> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _down = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: Semantics(
          button: true,
          child: AnimatedScale(
            duration: AppMotion.micro,
            scale: _down ? 0.985 : 1,
            child: AnimatedContainer(
              duration: AppMotion.short,
              curve: AppMotion.enter,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s4, vertical: AppSpace.s4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(AppColors.accent, Colors.white, 0.12)!,
                    AppColors.accent,
                    Color.lerp(AppColors.accent, AppColors.info, 0.35)!,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(_hover ? 0.38 : 0.22),
                    blurRadius: _hover ? 32 : 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.onAccent.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(widget.icon,
                        color: AppColors.onAccent, size: 22),
                  ),
                  const SizedBox(width: AppSpace.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.label,
                          style: const TextStyle(
                            color: AppColors.onAccent,
                            fontSize: AppType.body,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (widget.subtitle != null)
                          Text(
                            widget.subtitle!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.onAccent.withOpacity(0.78),
                              fontSize: AppType.caption,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  AnimatedSlide(
                    duration: AppMotion.short,
                    offset: Offset(_hover ? 0.15 : 0, 0),
                    child: const Icon(Icons.arrow_forward_rounded,
                        color: AppColors.onAccent, size: 20),
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

/// Loading placeholder with a slow shimmer.
class IvSkeleton extends StatelessWidget {
  const IvSkeleton({super.key, this.height = 88, this.radius = AppRadius.lg});

  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.surfaceRaised,
      period: const Duration(milliseconds: 1400),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Responsive grid of equal-width tiles (2 cols on phones, 3–4 wider).
class IvGrid extends StatelessWidget {
  const IvGrid({
    super.key,
    required this.children,
    this.minTileWidth = 160,
    this.gap = AppSpace.s3,
    this.maxColumns = 4,
  });

  final List<Widget> children;
  final double minTileWidth;
  final double gap;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = math.max(
          1,
          math.min(
              maxColumns, ((c.maxWidth + gap) / (minTileWidth + gap)).floor()));
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (var i = 0; i < children.length; i++)
            SizedBox(
              width: w,
              child: FadeSlideIn(index: i, child: children[i]),
            ),
        ],
      );
    });
  }
}

// ── Emoji → vector icon ─────────────────────────────────────────────────────

/// Legacy emoji glyphs still passed around as data (IVE evidence, verdicts)
/// rendered as vector icons instead (ui-ux-pro-max: no emoji as icons).
const Map<String, (IconData, Color)> _kEmojiIcons = {
  '🎯': (Icons.gps_fixed_rounded, AppColors.accent),
  '📋': (Icons.assignment_rounded, AppColors.info),
  '💬': (Icons.chat_bubble_outline_rounded, AppColors.info),
  '⚙': (Icons.tune_rounded, AppColors.inkMuted),
  '📊': (Icons.bar_chart_rounded, AppColors.info),
  '📈': (Icons.trending_up_rounded, AppColors.positive),
  '📉': (Icons.trending_down_rounded, AppColors.negative),
  '💡': (Icons.lightbulb_rounded, AppColors.gold),
  '⚡': (Icons.bolt_rounded, AppColors.warning),
  '🗑': (Icons.delete_outline_rounded, AppColors.negative),
  '🔗': (Icons.link_rounded, AppColors.info),
  '💰': (Icons.payments_rounded, AppColors.gold),
  '🏃': (Icons.directions_run_rounded, AppColors.accent),
  '⚠': (Icons.warning_amber_rounded, AppColors.warning),
  '🚀': (Icons.rocket_launch_rounded, AppColors.accent),
  '✅': (Icons.check_circle_rounded, AppColors.positive),
  '🔍': (Icons.manage_search_rounded, AppColors.info),
  '🧠': (Icons.psychology_rounded, AppColors.accent),
  '⭐': (Icons.star_rounded, AppColors.gold),
  '🔥': (Icons.local_fire_department_rounded, AppColors.warning),
  '❌': (Icons.cancel_rounded, AppColors.negative),
  '🏆': (Icons.emoji_events_rounded, AppColors.gold),
  '🌱': (Icons.spa_rounded, AppColors.positive),
  '🌳': (Icons.park_rounded, AppColors.positive),
  '🔬': (Icons.biotech_rounded, AppColors.info),
  '⏸': (Icons.pause_circle_rounded, AppColors.inkMuted),
  '🔴': (Icons.circle, AppColors.negative),
  '🟠': (Icons.circle, AppColors.warning),
  '🟡': (Icons.circle, AppColors.warning),
  '🟢': (Icons.circle, AppColors.positive),
  '🔵': (Icons.circle, AppColors.info),
  '📚': (Icons.menu_book_rounded, AppColors.info),
  '🎓': (Icons.school_rounded, AppColors.accent),
  '🤖': (Icons.smart_toy_rounded, AppColors.accent),
  '⭕': (Icons.radio_button_unchecked_rounded, AppColors.inkMuted),
  '📖': (Icons.auto_stories_rounded, AppColors.info),
  '📝': (Icons.edit_note_rounded, AppColors.accent),
  '📁': (Icons.folder_rounded, AppColors.info),
  '📄': (Icons.description_rounded, AppColors.info),
  '🕸': (Icons.hub_rounded, AppColors.accent),
  '💎': (Icons.diamond_rounded, AppColors.accent),
  '👥': (Icons.groups_rounded, AppColors.info),
  '✨': (Icons.auto_awesome_rounded, AppColors.accent),
};

(IconData, Color)? ivEmojiIcon(String emoji) =>
    _kEmojiIcons[emoji.replaceAll('️', '').trim()];

/// Renders a legacy emoji as an [IvIconTile]; unknown glyphs fall back to
/// a neutral dot icon rather than a font-dependent emoji.
class IvEmojiIcon extends StatelessWidget {
  const IvEmojiIcon(this.emoji, {super.key, this.size = 32});

  final String emoji;
  final double size;

  @override
  Widget build(BuildContext context) {
    final m = ivEmojiIcon(emoji);
    return IvIconTile(
      m?.$1 ?? Icons.auto_awesome_rounded,
      color: m?.$2 ?? AppColors.accent,
      size: size,
    );
  }
}

// ── App frame (proportion on large screens) ─────────────────────────────────

/// Keeps every route at a readable width on desktop: content is centred in
/// a frame of at most [maxWidth] (the background glow stays full-bleed),
/// MediaQuery reports the frame width so per-screen breakpoints stay
/// correct, and text scales up slightly on large screens so mobile-sized
/// type doesn't look tiny on a 1900px monitor.
class IvAppFrame extends StatelessWidget {
  const IvAppFrame({super.key, required this.child, this.maxWidth = 1240});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final frameW = math.min(w, maxWidth);
    final boost = w >= 1440
        ? 1.12
        : w >= 1024
            ? 1.08
            : 1.0;
    final base = mq.textScaler.scale(100) / 100;
    final framed = MediaQuery(
      data: mq.copyWith(
        size: Size(frameW, mq.size.height),
        textScaler: TextScaler.linear(base * boost),
      ),
      child: child,
    );
    if (w <= maxWidth) return framed;
    return Center(
      child: SizedBox(width: frameW, child: ClipRect(child: framed)),
    );
  }
}

// ── Page body width ─────────────────────────────────────────────────────────

/// Caps a page body at [maxWidth] on wide screens by adding symmetric side
/// padding. Padding (not Center/ConstrainedBox) keeps the child's
/// constraints exactly as tight as before, so layouts never change on
/// phones and nothing re-flows unexpectedly on desktop.
class IvBody extends StatelessWidget {
  const IvBody({super.key, required this.child, this.maxWidth = 1120});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (!c.hasBoundedWidth || c.maxWidth <= maxWidth) return child;
      final side = (c.maxWidth - maxWidth) / 2;
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: side),
        child: child,
      );
    });
  }
}

// ── Loading & empty states ──────────────────────────────────────────────────

/// Standard list-page loading state: three shimmering card placeholders.
class IvLoadingSkeleton extends StatelessWidget {
  const IvLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      // Inside a Column/Row slot (unbounded) render a compact block instead
      // of a scrollable list, so it is safe wherever a spinner was.
      if (!c.hasBoundedHeight || !c.hasBoundedWidth || c.maxHeight < 200) {
        return SizedBox(
          width: c.hasBoundedWidth ? c.maxWidth : 240,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpace.s2),
            child: IvSkeleton(height: 56, radius: AppRadius.md),
          ),
        );
      }
      return ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpace.s4),
        children: const [
          IvSkeleton(height: 88),
          SizedBox(height: AppSpace.s3),
          IvSkeleton(height: 132),
          SizedBox(height: AppSpace.s3),
          IvSkeleton(height: 132),
        ],
      );
    });
  }
}

/// Standard empty state: icon tile, title, optional message and action.
class IvEmptyState extends StatelessWidget {
  const IvEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.color = AppColors.accent,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.s6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: FadeSlideIn(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IvIconTile(icon, color: color, size: 64),
                const SizedBox(height: AppSpace.s4),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: AppType.heading,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: AppSpace.s2),
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.inkMuted,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: AppSpace.s6),
                  FilledButton.icon(
                    onPressed: onAction,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
