import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:ai_social_copilot/core/theme/app_motion.dart';
import 'package:ai_social_copilot/core/theme/app_tokens.dart';

/// InsightValues Dark Premium — animated data visuals (no extra package).
///
/// Rules (ui-ux-pro-max, Charts & Data): colour never carries meaning
/// alone — every chart shows its numbers as text too; every visual has a
/// Semantics label; reduced motion draws the final state immediately.

/// Score colour scale shared by every chart (80+ good, 60+ attention).
Color ivScoreColor(num score) {
  if (score >= 80) return AppColors.positive;
  if (score >= 60) return AppColors.warning;
  return AppColors.negative;
}

// ── Ring gauge ─────────────────────────────────────────────────────────────

/// Circular progress ring with a gradient arc that draws in, plus the value
/// in the centre.
class IvRingGauge extends StatelessWidget {
  const IvRingGauge({
    super.key,
    required this.value,
    this.max = 100,
    this.size = 64,
    this.stroke = 7,
    this.color,
    this.center,
    this.semanticsLabel,
  });

  final double value;
  final double max;
  final double size;
  final double stroke;
  final Color? color;
  final Widget? center;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final target = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    final c = color ?? ivScoreColor(value / (max <= 0 ? 1 : max) * 100);
    return Semantics(
      label: semanticsLabel ?? '${value.round()} / ${max.round()}',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: target),
        duration: AppMotion.reduced(context) ? Duration.zero : AppMotion.chart,
        curve: AppMotion.emphasized,
        builder: (context, t, _) => SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RingPainter(progress: t, color: c, stroke: stroke),
            child: Center(
              child: center ??
                  Text(
                    '${(t * max).round()}',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: size * 0.28,
                      fontWeight: FontWeight.w700,
                      fontFeatures: AppType.tabular,
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.color, required this.stroke});

  final double progress;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AppColors.line;
    canvas.drawArc(r, 0, math.pi * 2, false, track);
    if (progress <= 0) return;
    final sweep = math.pi * 2 * progress;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + math.pi * 2,
        colors: [color.withOpacity(0.35), color],
        stops: [0.0, progress.clamp(0.01, 1.0)],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect);
    canvas.drawArc(r, -math.pi / 2, sweep, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

// ── Horizontal bars ─────────────────────────────────────────────────────────

class IvBarDatum {
  const IvBarDatum(this.label, this.value, {this.color});
  final String label;
  final double value;
  final Color? color;
}

/// Ranked horizontal bars: label + value text, bar grows in, staggered.
class IvBarList extends StatelessWidget {
  const IvBarList({
    super.key,
    required this.data,
    this.max,
    this.valueSuffix = '',
  });

  final List<IvBarDatum> data;
  final double? max;
  final String valueSuffix;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final top = max ?? data.map((d) => d.value).reduce(math.max);
    final reduced = AppMotion.reduced(context);
    return Column(
      children: [
        for (var i = 0; i < data.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : AppSpace.s3),
            child: Semantics(
              label: '${data[i].label}: ${data[i].value.round()}$valueSuffix',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          data[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.inkMuted,
                            fontSize: AppType.label,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpace.s2),
                      Text(
                        '${data[i].value.round()}$valueSuffix',
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: AppType.label,
                          fontWeight: FontWeight.w600,
                          fontFeatures: AppType.tabular,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TweenAnimationBuilder<double>(
                    tween: Tween(
                        begin: 0,
                        end: top <= 0
                            ? 0
                            : (data[i].value / top).clamp(0.0, 1.0)),
                    duration: reduced
                        ? Duration.zero
                        : AppMotion.chart + AppMotion.stagger * i,
                    curve: AppMotion.emphasized,
                    builder: (context, t, _) {
                      final c = data[i].color ?? ivScoreColor(data[i].value);
                      return Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.line,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: t,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              gradient: LinearGradient(
                                colors: [c.withOpacity(0.55), c],
                              ),
                              boxShadow: [
                                BoxShadow(
                                    color: c.withOpacity(0.35),
                                    blurRadius: 8),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ── Area / line chart ───────────────────────────────────────────────────────

/// Smooth line with a gradient fill that fades to transparent, drawn in
/// left-to-right. Shows first/last labels and the latest value as text.
class IvAreaChart extends StatelessWidget {
  const IvAreaChart({
    super.key,
    required this.values,
    this.labels = const [],
    this.height = 140,
    this.color = AppColors.accent,
    this.semanticsLabel,
  });

  final List<double> values;
  final List<String> labels;
  final double height;
  final Color color;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) return const SizedBox.shrink();
    return Semantics(
      label: semanticsLabel ??
          values.map((v) => v.toStringAsFixed(0)).join(', '),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: AppMotion.reduced(context) ? Duration.zero : AppMotion.chart,
        curve: AppMotion.emphasized,
        builder: (context, t, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: height,
              child: CustomPaint(
                painter: _AreaPainter(values: values, t: t, color: color),
              ),
            ),
            if (labels.length >= 2) ...[
              const SizedBox(height: AppSpace.s2),
              Row(
                children: [
                  Text(labels.first,
                      style: const TextStyle(
                          color: AppColors.inkSubtle,
                          fontSize: AppType.caption)),
                  const Spacer(),
                  Text(labels.last,
                      style: const TextStyle(
                          color: AppColors.inkSubtle,
                          fontSize: AppType.caption)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AreaPainter extends CustomPainter {
  _AreaPainter({required this.values, required this.t, required this.color});

  final List<double> values;
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final lo = values.reduce(math.min);
    final hi = values.reduce(math.max);
    final span = (hi - lo).abs() < 1e-9 ? 1.0 : hi - lo;
    const padTop = 8.0;
    final h = size.height - padTop;

    // grid
    final grid = Paint()
      ..color = AppColors.line.withOpacity(0.6)
      ..strokeWidth = 1;
    for (var i = 1; i <= 3; i++) {
      final y = padTop + h * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    Offset pt(int i) => Offset(
          size.width * i / (values.length - 1),
          padTop + h - (values[i] - lo) / span * h * 0.9,
        );

    final line = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < values.length; i++) {
      final p0 = pt(i - 1);
      final p1 = pt(i);
      final mx = (p0.dx + p1.dx) / 2;
      line.cubicTo(mx, p0.dy, mx, p1.dy, p1.dx, p1.dy);
    }

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * t, size.height));

    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.32), color.withOpacity(0.0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
    canvas.restore();

    if (t >= 0.999) {
      final last = pt(values.length - 1);
      canvas.drawCircle(last, 6, Paint()..color = color.withOpacity(0.25));
      canvas.drawCircle(last, 3.2, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_AreaPainter old) =>
      old.t != t || old.values != values || old.color != color;
}

// ── Segmented progress (journey steps) ─────────────────────────────────────

/// Row of segments filled up to [done] of [total], each filling in turn.
class IvStepProgress extends StatelessWidget {
  const IvStepProgress({super.key, required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final reduced = AppMotion.reduced(context);
    return Semantics(
      label: '$done / $total',
      child: Row(
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: AppSpace.s1),
            Expanded(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: i < done ? 1 : 0),
                duration: reduced
                    ? Duration.zero
                    : AppMotion.medium + AppMotion.stagger * 2 * i,
                curve: AppMotion.emphasized,
                builder: (context, t, _) => Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: t,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        gradient: const LinearGradient(colors: [
                          AppColors.accent,
                          AppColors.info,
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
