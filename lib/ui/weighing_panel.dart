import 'package:flutter/material.dart';
import '../brew_controller.dart';
import 'style.dart';

class WeighingPanel extends StatelessWidget {
  final BrewController controller;
  const WeighingPanel({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final grams = c.currentGrams;
    final overloaded = !c.demo && c.scale?.reading?.overloaded == true;
    return Container(
      key: const Key('weighing-panel'),
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Text(
            c.starting ? '영점 설정 중' : '현재 무게',
            style: const TextStyle(color: muted, fontSize: 14),
          ),
          const SizedBox(height: 18),
          FittedBox(
            child: Text(
              overloaded ? '용량 초과' : '${grams?.toStringAsFixed(1) ?? '—'} g',
              key: const Key('live-weight'),
              style: const TextStyle(
                fontSize: 66,
                letterSpacing: -2,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            c.canStart
                ? '이 무게로 시작하면 목표 ${number(grams! * c.brew.ratio)} g'
                : c.demo || c.scale?.connected == true
                ? '서버·드리퍼는 TARE, 원두는 그대로 올려주세요.'
                : '저울을 연결하면 무게가 표시됩니다.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted, fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('tare'),
              onPressed: c.canTare ? c.tare : null,
              icon: const Icon(Icons.exposure_zero_rounded),
              label: const Text('TARE · 영점'),
            ),
          ),
          if (c.demo) ...[
            const SizedBox(height: 12),
            const Text(
              '데모 · 원두 무게',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            Slider(
              key: const Key('demo-dose'),
              value: c.demoWeight.clamp(0, 100),
              max: 100,
              divisions: 200,
              onChanged: c.starting ? null : c.setDemoWeight,
            ),
          ],
        ],
      ),
    );
  }
}
