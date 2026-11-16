import 'package:flutter/material.dart';
import 'style.dart';

class BrewMetrics extends StatelessWidget {
  final double water, target, percent, flow;

  const BrewMetrics({
    super.key,
    required this.water,
    required this.target,
    required this.percent,
    required this.flow,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '부은 물 / 목표 물',
          style: TextStyle(
            color: muted,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: '부은 물 ${water.toStringAsFixed(1)}g, 목표 물 ${number(target)}g',
          excludeSemantics: true,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: water.toStringAsFixed(1)),
                  const TextSpan(
                    text: ' / ',
                    style: TextStyle(
                      fontSize: 32,
                      color: muted,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  TextSpan(
                    text: number(target),
                    style: const TextStyle(
                      fontSize: 46,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const TextSpan(
                    text: ' g',
                    style: TextStyle(fontSize: 19, color: muted),
                  ),
                ],
              ),
              key: const Key('brew-water-target'),
              style: const TextStyle(
                fontSize: 56,
                height: 1.15,
                letterSpacing: -1.8,
                fontWeight: FontWeight.w600,
                color: ink,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${percent.toStringAsFixed(1)} %',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: copper,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    key: const Key('brew-progress'),
                    value: (percent / 100).clamp(0.0, 1.0),
                    minHeight: 9,
                    borderRadius: BorderRadius.circular(8),
                    backgroundColor: mint,
                    color: copper,
                    semanticsLabel: '목표 대비 진행률',
                    semanticsValue: '${percent.toStringAsFixed(1)}%',
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 43,
              margin: const EdgeInsets.symmetric(horizontal: 18),
              color: line,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('유량', style: TextStyle(fontSize: 11, color: muted)),
                const SizedBox(height: 5),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: flow.toStringAsFixed(1)),
                      const TextSpan(
                        text: ' g/s',
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                    ],
                  ),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}
