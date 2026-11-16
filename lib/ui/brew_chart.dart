import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../recipe.dart';
import 'style.dart';

class BrewChart extends StatelessWidget {
  final List<BrewPoint> points;
  final BrewRecipe? reference;
  final double target;
  final double seconds;
  final double height;
  const BrewChart({
    super.key,
    required this.points,
    this.reference,
    required this.target,
    this.seconds = 0,
    this.height = 212,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    label:
        '추출 그래프. 가로축 시간, 세로축 질량. 현재 ${seconds.toStringAsFixed(0)}초, ${points.isEmpty ? 0 : points.last.grams.toStringAsFixed(1)}g.',
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
            const Text('이번 추출', style: TextStyle(color: muted, fontSize: 11)),
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
              const Text(
                '레시피 기준',
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
  _ChartPainter(
    this.points,
    this.reference,
    this.target,
    this.seconds,
    this.duration,
    this.labelStyle,
  );
  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Rect.fromLTRB(40, 18, size.width - 12, size.height - 28);
    if (bounds.width <= 0 || bounds.height <= 0) return;
    final requiredTime = math.max(60, math.max(duration, seconds * 1.08));
    const timeSteps = <double>[15, 30, 45, 60, 90, 120, 180, 300, 600, 900];
    final tick = timeSteps.firstWhere(
      (step) => step * 4 >= requiredTime,
      orElse: () => (requiredTime / 240).ceil() * 60.0,
    );
    final maxTime = tick * 4;
    final peak = [
      ...points,
      ...reference,
    ].fold(target, (double value, p) => math.max(value, p.grams));
    final maxMass = (math.max(50, peak * 1.12) / 50).ceil() * 50.0;
    Offset location(BrewPoint p) => Offset(
      bounds.left + p.seconds / maxTime * bounds.width,
      bounds.bottom - p.grams / maxMass * bounds.height,
    );
    void text(String value, Offset offset, {bool right = false}) {
      final painter = TextPainter(
        text: TextSpan(text: value, style: labelStyle),
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
    }
    text('g', const Offset(20, 0));
    text('시간', Offset(bounds.right, 0), right: true);
    canvas.save();
    canvas.clipRect(bounds);
    if (reference.isNotEmpty) {
      final path =
          Path()..moveTo(
            location(reference.first).dx,
            location(reference.first).dy,
          );
      for (final p in reference.skip(1)) {
        final at = location(p);
        path.lineTo(at.dx, at.dy);
      }
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
      final path =
          Path()..moveTo(location(points.first).dx, location(points.first).dy);
      for (final point in points.skip(1)) {
        final at = location(point);
        path.lineTo(at.dx, at.dy);
      }
      final fill =
          Path.from(path)
            ..lineTo(location(points.last).dx, bounds.bottom)
            ..lineTo(location(points.first).dx, bounds.bottom)
            ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [ink.withValues(alpha: 0.12), ink.withValues(alpha: 0.01)],
          ).createShader(bounds),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = ink
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
      canvas.drawCircle(location(points.last), 4, Paint()..color = ink);
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
  bool shouldRepaint(covariant _ChartPainter oldDelegate) => true;
}
