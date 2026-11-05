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
