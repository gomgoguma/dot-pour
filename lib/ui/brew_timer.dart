import 'package:flutter/material.dart';
import '../l10n/language.dart';
import '../brew_session.dart';
import 'style.dart';

class BrewTimer extends StatelessWidget {
  final double seconds;
  final BrewPhase phase;
  final bool reached;
  const BrewTimer({
    super.key,
    required this.seconds,
    required this.phase,
    required this.reached,
  });

  @override
  Widget build(BuildContext context) {
    final status = switch (phase) {
      BrewPhase.setup => context.l10n.readyToStart,
      BrewPhase.ready => context.l10n.waitingFirstPour,
      BrewPhase.pouring =>
        reached ? context.l10n.targetReached : context.l10n.brewInProgress,
      BrewPhase.finished => context.l10n.brewFinished,
      BrewPhase.interrupted => context.l10n.brewInterrupted,
    };
    return Semantics(
      label: context.l10n.brewTimeStatus(clockText(seconds), status),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(status, style: const TextStyle(fontSize: 11, color: muted)),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              clockText(seconds),
              key: const Key('brew-elapsed'),
              style: const TextStyle(
                fontSize: 52,
                height: 1.05,
                fontWeight: FontWeight.w600,
                letterSpacing: -1.5,
                color: ink,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
