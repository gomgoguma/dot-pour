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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SurfaceCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '현재 무게',
                      style: TextStyle(
                        color: muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 92,
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
                                          fontSize: 24,
                                          letterSpacing: 0,
                                          color: copper,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                          ),
                          key: const Key('basic-scale-weight'),
                          style: const TextStyle(
                            fontSize: 64,
                            letterSpacing: -1.5,
                            fontWeight: FontWeight.w600,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        text: '유량 ',
                        children: [
                          TextSpan(
                            text: c.scaleFlow.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const TextSpan(text: ' g/s'),
                        ],
                      ),
                      key: const Key('basic-scale-flow'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: muted,
                        fontSize: 13,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (grams == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          c.scale?.connected == true
                              ? '저울값을 기다리고 있어요.'
                              : '저울을 연결해 주세요.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: muted, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      key: const Key('basic-scale-tare'),
                      onPressed: c.canTare ? c.tare : null,
                      style: secondaryButtonStyle().copyWith(
                        minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
                      ),
                      icon: const Icon(Icons.restart_alt_rounded, size: 20),
                      label: Text(c.taring ? '영점 확인 중…' : '영점 조절 (TARE)'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SurfaceCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '타이머',
                            style: TextStyle(
                              color: muted,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Text(
                          '물줄기 자동 감지',
                          style: TextStyle(color: muted, fontSize: 11),
                        ),
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 42,
                          height: 36,
                          child: FittedBox(
                            child: Switch(
                              key: const Key('scale-auto-start'),
                              value: c.scaleAutoStart,
                              onChanged: c.setScaleAutoStart,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text.rich(
                        TextSpan(
                          text: clockText(elapsed.inMilliseconds / 1000),
                          children: [
                            TextSpan(
                              text: '.$tenths',
                              style: const TextStyle(
                                fontSize: 28,
                                color: muted,
                                letterSpacing: -.5,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                        key: const Key('manual-timer-value'),
                        style: const TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -1.5,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      c.scaleAutoStart
                          ? (timer.running
                              ? '타이머 측정 중'
                              : elapsed > Duration.zero
                              ? '계속 버튼으로 이어서 측정하세요'
                              : '0g에서 물을 부으면 시작해요')
                          : '시작과 멈춤을 직접 조절하세요',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: muted, fontSize: 11),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            key: const Key('manual-timer-reset'),
                            onPressed:
                                elapsed > Duration.zero || timer.running
                                    ? c.resetScaleTimer
                                    : null,
                            style: secondaryButtonStyle(),
                            icon: const Icon(
                              Icons.restart_alt_rounded,
                              size: 18,
                            ),
                            label: const Text('초기화'),
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
                  ],
                ),
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
