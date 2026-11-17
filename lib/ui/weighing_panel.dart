import 'package:flutter/material.dart';
import '../brew_controller.dart';
import 'style.dart';

class WeighingPanel extends StatelessWidget {
  final BrewController controller;
  const WeighingPanel({super.key, required this.controller});

  Future<void> _editDose(BuildContext context) async {
    final c = controller;
    final form = GlobalKey<FormState>();
    double? dose;
    final selected = await showDialog<double>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            scrollable: true,
            title: const Text('원두량 직접 입력'),
            content: Form(
              key: form,
              child: TextFormField(
                key: const Key('manual-dose-field'),
                initialValue: number(c.confirmedDose ?? c.brew.dose),
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: '원두량',
                  suffixText: 'g',
                ),
                validator: (value) => c.validateDose(parseNumber(value ?? '')),
                onSaved: (value) => dose = parseNumber(value ?? ''),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () {
                  final state = form.currentState!;
                  if (!state.validate()) return;
                  state.save();
                  Navigator.pop(dialogContext, dose);
                },
                child: const Text('원두량 적용'),
              ),
            ],
          ),
    );
    if (context.mounted && selected != null) c.setDose(selected);
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final grams = c.currentGrams;
    final dose = c.setupDose;
    final confirmed = c.confirmedDose;
    final suggested = c.suggestedDose;
    final busy = c.starting || c.taring;
    final isWeighing = c.isDoseTared || confirmed != null;
    final connected = c.scale?.connected == true;
    final overloaded = !c.demo && c.scale?.reading?.overloaded == true;
    final instruction =
        busy
            ? '저울의 영점을 확인하고 있어요.'
            : !connected && !c.demo
            ? '저울을 연결한 뒤\n서버와 드리퍼를 올려 주세요.'
            : confirmed != null
            ? '원두량을 확인했어요. 추출을 시작해 주세요.'
            : c.isDoseTared
            ? '원두를 담아 무게를 확인해 주세요.'
            : c.hasSetupWeight
            ? 'TARE를 누른 뒤 원두를 담아 주세요.'
            : '서버와 드리퍼를 올리고\nTARE를 눌러 주세요.';
    return Container(
      key: const Key('weighing-panel'),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Row(
            children: [
              Image.asset(
                isWeighing
                    ? 'assets/illustrations/coffee-beans.png'
                    : 'assets/illustrations/pour-over-setup.png',
                key: const Key('setup-illustration'),
                width: 64,
                height: 64,
                cacheHeight: 192,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                semanticLabel: isWeighing ? '커피 원두' : '저울 위에 놓인 서버와 드리퍼',
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    overloaded
                        ? '용량 초과'
                        : '${grams?.toStringAsFixed(1) ?? '0.0'} g',
                    key: const Key('live-weight'),
                    semanticsLabel: grams == null ? '저울 연결 대기, 0.0 g' : null,
                    style: const TextStyle(
                      fontSize: 64,
                      letterSpacing: -2,
                      fontWeight: FontWeight.w400,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!isWeighing && c.hasSetupWeight) ...[
            DecoratedBox(
              decoration: BoxDecoration(
                color: mint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline, size: 16, color: ink),
                    SizedBox(width: 6),
                    Text(
                      '세팅 안정',
                      style: TextStyle(color: ink, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
          if (suggested == null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    instruction,
                    key: const Key('weighing-instruction'),
                    style: const TextStyle(
                      color: ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.6,
                    ),
                  ),
                ),
                if (isWeighing) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    key: const Key('restart-scale-setup'),
                    onPressed: c.canChangeScale ? c.restartDoseSetup : null,
                    child: const Text('세팅 다시', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ],
            ),
          if (dose != null && c.validateDose(dose) == null) ...[
            const SizedBox(height: 8),
            Text(
              '원두 ${number(dose)}g · 목표 물 ${number(dose * c.brew.ratio)}g',
              key: const Key('setup-dose-preview'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
          if (suggested != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: mint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Text(
                    '원두를 담으셨나요? ${number(suggested)}g 늘었어요.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13),
                  ),
                  TextButton(
                    key: const Key('apply-suggested-dose'),
                    onPressed: busy ? null : () => c.setDose(suggested),
                    child: Text('${number(suggested)}g 적용'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  key: const Key('tare'),
                  onPressed: c.canTare ? c.tare : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: mint,
                    foregroundColor: ink,
                  ),
                  child: const Text('TARE'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  key: const Key('manual-dose'),
                  onPressed: busy ? null : () => _editDose(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 50),
                  ),
                  child: const Text('직접 입력'),
                ),
              ),
            ],
          ),
          if (c.demo) ...[
            const SizedBox(height: 12),
            const Text(
              '데모 · 저울값',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            Slider(
              key: const Key('demo-dose'),
              value: c.demoWeight.clamp(0, 100),
              max: 100,
              divisions: 200,
              onChanged: busy ? null : c.setDemoWeight,
            ),
          ],
        ],
      ),
    );
  }
}
