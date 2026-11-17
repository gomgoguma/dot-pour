import 'package:flutter/material.dart';
import '../brew_controller.dart';
import 'style.dart';

class BasicScale extends StatelessWidget {
  final BrewController controller;
  const BasicScale({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final grams = c.currentGrams;
    final overloaded = !c.demo && c.scale?.reading?.overloaded == true;
    final timer = c.scaleTimer;
    final elapsed = timer.elapsed;
    final tenths = elapsed.inMilliseconds ~/ 100 % 10;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 608),
        child: SingleChildScrollView(
          key: const Key('basic-scale'),
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('현재 무게', style: TextStyle(color: muted, fontSize: 13)),
              const SizedBox(height: 16),
              SizedBox(
                height: 136,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text.rich(
                    TextSpan(
                      text:
                          overloaded
                              ? '용량 초과'
                              : grams?.toStringAsFixed(1) ?? '0.0',
                      children:
                          overloaded
                              ? null
                              : const [
                                TextSpan(
                                  text: ' g',
                                  style: TextStyle(
                                    fontSize: 32,
                                    letterSpacing: 0,
                                    color: muted,
                                  ),
                                ),
                              ],
                    ),
                    key: const Key('basic-scale-weight'),
                    style: const TextStyle(
                      fontSize: 88,
                      letterSpacing: -3,
                      fontWeight: FontWeight.w400,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              if (grams == null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    c.scale?.connected == true
                        ? '저울값을 기다리고 있어요.'
                        : '저울을 연결해 주세요.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: muted, fontSize: 13),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('basic-scale-tare'),
                onPressed: c.canTare ? c.tare : null,
                style: FilledButton.styleFrom(
                  backgroundColor: mint,
                  foregroundColor: ink,
                ),
                child: Text(c.taring ? '영점 확인 중…' : 'TARE'),
              ),
              const Divider(height: 56),
              const Text(
                '수동 타이머',
                style: TextStyle(color: muted, fontSize: 13),
              ),
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${clockText(elapsed.inMilliseconds / 1000)}.$tenths',
                  key: const Key('manual-timer-value'),
                  style: const TextStyle(
                    fontSize: 58,
                    fontWeight: FontWeight.w400,
                    letterSpacing: -1.5,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('manual-timer-reset'),
                      onPressed:
                          elapsed > Duration.zero || timer.running
                              ? c.resetScaleTimer
                              : null,
                      child: const Text('초기화'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('manual-timer-toggle'),
                      onPressed: c.toggleScaleTimer,
                      icon: Icon(
                        timer.running
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 20,
                      ),
                      label: Text(
                        timer.running
                            ? '일시정지'
                            : elapsed > Duration.zero
                            ? '계속'
                            : '시작',
                      ),
                    ),
                  ),
                ],
              ),
              if (c.notice != null || c.scale?.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    c.notice ?? c.scale!.error!,
                    style: const TextStyle(color: copper, fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
