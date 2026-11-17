import 'package:flutter/material.dart';
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
      BrewPhase.setup => '시작 대기',
      BrewPhase.ready => '첫 물줄기 대기',
      BrewPhase.pouring => reached ? '목표 도달' : '추출 중',
      BrewPhase.finished => '추출 완료',
      BrewPhase.interrupted => '추출 중단',
    };
    return Semantics(
      label: '추출 시간 ${clockText(seconds)}, $status',
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
