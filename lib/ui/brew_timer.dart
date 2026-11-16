import 'package:flutter/material.dart';
import '../brew_session.dart';
import 'style.dart';

class BrewTimer extends StatelessWidget {
  final double seconds;
  final BrewPhase phase;
  final bool reached;
  final bool holdingMeasurement;
  const BrewTimer({
    super.key,
    required this.seconds,
    required this.phase,
    required this.reached,
    this.holdingMeasurement = false,
  });

  @override
  Widget build(BuildContext context) {
    final status =
        holdingMeasurement &&
                (phase == BrewPhase.ready || phase == BrewPhase.pouring)
            ? '무게 안정 대기 · 기록 유지'
            : switch (phase) {
              BrewPhase.setup => '시작을 기다려요',
              BrewPhase.ready => '첫 물줄기 대기',
              BrewPhase.pouring => reached ? '목표 물량 도달' : '추출 중',
              BrewPhase.finished => '추출 완료',
              BrewPhase.interrupted => '추출 중단',
            };
    return Semantics(
      label: '추출 시간 ${clockText(seconds)}, $status',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: mint,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '추출 시간',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status,
                    style: const TextStyle(fontSize: 11, color: muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 6,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  clockText(seconds),
                  key: const Key('brew-elapsed'),
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -1.2,
                    color: ink,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
