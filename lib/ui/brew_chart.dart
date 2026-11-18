import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../l10n/language.dart';
import '../recipe.dart';
import 'style.dart';

const espressoFlowBlue = Color(0xff4c697a);

class BrewChart extends StatelessWidget {
  final List<BrewPoint> points;
  final BrewRecipe? reference;
  final double target;
  final double seconds;
  final double height;
  final bool showFlow;
  const BrewChart({
    super.key,
    required this.points,
    this.reference,
    required this.target,
    this.seconds = 0,
    this.height = 212,
    this.showFlow = false,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    label: (showFlow
        ? context.l10n.espressoChartDescription
        : context.l10n.chartDescription)(
      seconds.toStringAsFixed(0),
      points.isEmpty ? 0 : points.last.grams.toStringAsFixed(1),
    ),
    child: Column(
      children: [
        SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _ChartPainter(
              points,
              reference?.curve ?? [],
              target,
              seconds,
              reference?.duration ?? 0,
              context.l10n.time,
              showFlow,
              Theme.of(
                context,
              ).textTheme.bodySmall!.copyWith(fontSize: 10, color: muted),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.horizontal_rule, color: ink, size: 20),
            const SizedBox(width: 5),
            Text(
              showFlow ? context.l10n.espressoYield : context.l10n.currentBrew,
              style: TextStyle(color: muted, fontSize: 11),
            ),
            if (showFlow) ...[
              const SizedBox(width: 16),
              const SizedBox(
                width: 20,
                height: 1,
                child: ColoredBox(color: espressoFlowBlue),
              ),
              const SizedBox(width: 5),
              Text(
                context.l10n.flowPrefix.trim(),
                style: const TextStyle(color: espressoFlowBlue, fontSize: 11),
              ),
            ],
            if (reference != null) ...[
              const SizedBox(width: 20),
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 6,
                    height: 2,
                    child: ColoredBox(color: copper),
                  ),
                  SizedBox(width: 3),
                  SizedBox(
                    width: 6,
                    height: 2,
                    child: ColoredBox(color: copper),
                  ),
                ],
              ),
              const SizedBox(width: 5),
              Text(
                context.l10n.recipeReference,
                style: TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ],
        ),
      ],
    ),
  );
}

class _ChartPainter extends CustomPainter {
  final List<BrewPoint> points, reference;
  final double target, seconds, duration;
  final TextStyle labelStyle;
  final String timeLabel;
  final bool showFlow;
  _ChartPainter(
    this.points,
    this.reference,
    this.target,
    this.seconds,
    this.duration,
    this.timeLabel,
    this.showFlow,
    this.labelStyle,
  );
  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Rect.fromLTRB(
      showFlow ? 32 : 40,
      18,
      size.width - (showFlow ? 35 : 12),
      size.height - 28,
    );
    if (bounds.width <= 0 || bounds.height <= 0) return;
    final requiredTime = math.max(
      showFlow ? 40 : 60,
      math.max(duration, seconds * 1.08),
    );
    final timeSteps = <double>[
      if (showFlow) 10,
      15,
      30,
      45,
      60,
      90,
      120,
      180,
      300,
      600,
      900,
    ];
    final tick = timeSteps.firstWhere(
      (step) => step * 4 >= requiredTime,
      orElse: () => (requiredTime / 240).ceil() * 60.0,
    );
    final maxTime = tick * 4;
    final peak = [
      ...points,
      ...reference,
    ].fold(target, (double value, p) => math.max(value, p.grams));
    final maxMass =
        showFlow
            ? (math.max(40, peak * 1.12) / 20).ceil() * 20.0
            : (math.max(50, peak * 1.12) / 50).ceil() * 50.0;
    final maxFlow =
        showFlow
            ? (points.fold(4.0, (peak, p) => math.max(peak, p.flow * 1.12)) / 4)
                    .ceil() *
                4.0
            : 0.0;
    Offset location(BrewPoint p) => Offset(
      bounds.left + p.seconds / maxTime * bounds.width,
      bounds.bottom - p.grams / maxMass * bounds.height,
    );
    Path tracePath(List<BrewPoint> trace) {
      var previous = location(trace.first);
      final path = Path()..moveTo(previous.dx, previous.dy);
      for (final point in trace.skip(1)) {
        final current = location(point);
        if (point.breakBefore) path.lineTo(current.dx, previous.dy);
        path.lineTo(current.dx, current.dy);
        previous = current;
      }
      return path;
    }

    void text(String value, Offset offset, {bool right = false, Color? color}) {
      final painter = TextPainter(
        text: TextSpan(
          text: value,
          style: color == null ? labelStyle : labelStyle.copyWith(color: color),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset(offset.dx - (right ? painter.width : 0), offset.dy),
      );
    }

    final grid =
        Paint()
          ..color = line
          ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = bounds.bottom - bounds.height * i / 4;
      canvas.drawLine(Offset(bounds.left, y), Offset(bounds.right, y), grid);
      text(
        (maxMass * i / 4).toStringAsFixed(0),
        Offset(bounds.left - 8, y - 6),
        right: true,
      );
      final x = bounds.left + bounds.width * i / 4;
      text(clockText(maxTime * i / 4), Offset(x - 12, bounds.bottom + 9));
      if (showFlow) {
        text(
          (maxFlow * i / 4).toStringAsFixed(0),
          Offset(bounds.right + 7, y - 6),
          color: espressoFlowBlue,
        );
      }
    }
    text('g', const Offset(20, 0));
    if (showFlow) {
      text(
        'g/s',
        Offset(size.width - 4, 0),
        right: true,
        color: espressoFlowBlue,
      );
    } else {
      text(timeLabel, Offset(bounds.right, 0), right: true);
    }
    canvas.save();
    canvas.clipRect(bounds);
    if (reference.isNotEmpty) {
      final path = tracePath(reference);
      final paint =
          Paint()
            ..color = copper.withValues(alpha: 0.8)
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke;
      for (final metric in path.computeMetrics()) {
        for (double start = 0; start < metric.length; start += 10) {
          canvas.drawPath(
            metric.extractPath(start, math.min(start + 5, metric.length)),
            paint,
          );
        }
      }
    }
    if (points.isNotEmpty) {
      final path = tracePath(points);
      final last = location(points.last);
      canvas.drawPath(
        Path.from(path)
          ..lineTo(last.dx, bounds.bottom)
          ..lineTo(location(points.first).dx, bounds.bottom)
          ..close(),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [ink.withValues(alpha: 0.12), ink.withValues(alpha: 0.01)],
          ).createShader(bounds),
      );
      if (showFlow) {
        final flowPath = Path();
        for (final (index, point) in points.indexed) {
          final x = location(point).dx;
          final y = bounds.bottom - (point.flow / maxFlow) * bounds.height;
          if (index == 0) {
            flowPath.moveTo(x, y);
          } else {
            flowPath.lineTo(x, y);
          }
        }
        canvas.drawPath(
          flowPath,
          Paint()
            ..color = espressoFlowBlue.withValues(alpha: .82)
            ..strokeWidth = 1
            ..strokeJoin = StrokeJoin.round
            ..style = PaintingStyle.stroke,
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = ink
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
      canvas.drawCircle(last, 4, Paint()..color = ink);
    }
    if (seconds > 0) {
      final x = bounds.left + seconds / maxTime * bounds.width;
      canvas.drawLine(
        Offset(x, bounds.top),
        Offset(x, bounds.bottom),
        Paint()..color = ink.withValues(alpha: 0.12),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) =>
      points != oldDelegate.points ||
      reference != oldDelegate.reference ||
      target != oldDelegate.target ||
      seconds != oldDelegate.seconds ||
      duration != oldDelegate.duration ||
      timeLabel != oldDelegate.timeLabel ||
      showFlow != oldDelegate.showFlow ||
      labelStyle != oldDelegate.labelStyle;
}
