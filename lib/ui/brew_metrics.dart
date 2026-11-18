import 'package:flutter/material.dart';
import '../l10n/language.dart';
import '../brew_session.dart';
import 'brew_timer.dart';
import 'style.dart';

class BrewMetrics extends StatelessWidget {
  final double water, target, percent, flow, seconds;
  final BrewPhase phase;
  final bool reached;
  final bool holdingMeasurement;

  const BrewMetrics({
    super.key,
    required this.water,
    required this.target,
    required this.percent,
    required this.flow,
    required this.seconds,
    required this.phase,
    required this.reached,
    this.holdingMeasurement = false,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: Text(
              context.l10n.waterPoured,
              style: TextStyle(
                color: muted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (holdingMeasurement)
            Tooltip(
              message: context.l10n.waitingStableWeight,
              child: Icon(
                Icons.circle,
                key: Key('weight-hold-indicator'),
                size: 7,
                color: Color(0xffbc8638),
                semanticLabel: context.l10n.waitingStableWeight,
              ),
            ),
        ],
      ),
      Semantics(
        label: context.l10n.waterAndTarget(
          water.toStringAsFixed(1),
          number(target),
        ),
        excludeSemantics: true,
        child: Row(
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text.rich(
                  TextSpan(
                    text: water.toStringAsFixed(1),
                    children: const [
                      TextSpan(
                        text: ' g',
                        style: TextStyle(
                          fontSize: 24,
                          color: copper,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                  key: const Key('brew-water-target'),
                  style: const TextStyle(
                    fontSize: 64,
                    height: 1.1,
                    letterSpacing: -1.5,
                    fontWeight: FontWeight.w600,
                    color: ink,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 84),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text.rich(
                  TextSpan(
                    text: context.l10n.targetLine,
                    children: [
                      TextSpan(
                        text: '${number(target)} g',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  key: const Key('brew-target'),
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: muted,
                    fontSize: 12,
                    height: 1.5,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 4),
      Text.rich(
        TextSpan(
          text: context.l10n.flowPrefix,
          children: [
            TextSpan(
              text: flow.toStringAsFixed(1),
              style: const TextStyle(
                color: ink,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const TextSpan(text: ' g/s'),
          ],
        ),
        key: const Key('brew-flow'),
        style: const TextStyle(
          color: muted,
          fontSize: 12,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
      const Divider(height: 20),
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            flex: 6,
            child: BrewTimer(seconds: seconds, phase: phase, reached: reached),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  context.l10n.progress,
                  style: TextStyle(fontSize: 11, color: muted),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text.rich(
                    TextSpan(
                      text: percent.toStringAsFixed(1),
                      children: const [
                        TextSpan(
                          text: ' %',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    key: const Key('brew-percent'),
                    style: const TextStyle(
                      fontSize: 32,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: copper,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      LinearProgressIndicator(
        key: const Key('brew-progress'),
        value: (percent / 100).clamp(0.0, 1.0),
        minHeight: 6,
        borderRadius: BorderRadius.circular(8),
        backgroundColor: mint,
        color: copper,
        semanticsLabel: context.l10n.progressTowardTarget,
        semanticsValue: '${percent.clamp(0, 100).toStringAsFixed(1)}%',
      ),
    ],
  );
}
