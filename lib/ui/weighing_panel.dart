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
                initialValue: number(c.setupDose ?? c.brew.dose),
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
    final raw = c.currentGrams;
    final isWeighing = c.isDoseWeighing;
    final grams = isWeighing ? c.setupDose : raw;
    final confirmed = c.confirmedDose;
    final suggested = c.suggestedDose;
    final busy = c.starting || c.taring;
    final connected = c.scale?.connected == true;
    final overloaded = !c.demo && c.scale?.reading?.overloaded == true;
    final instruction =
        busy
            ? '저울의 영점을 확인하고 있어요.'
            : !connected && !c.demo
            ? '저울을 연결한 뒤\n서버와 드리퍼를 올려 주세요.'
            : confirmed != null
            ? '원두량을 확인했어요. 추출을 시작해 주세요.'
            : raw == null
            ? '저울값을 기다리고 있어요.'
            : isWeighing && grams == null
            ? '기구 준비에서 기준 무게를 다시 잡아 주세요.'
            : isWeighing
            ? '원두를 담아 무게를 확인해 주세요.'
            : '서버와 드리퍼를 올린 뒤\n원두 담기로 넘어가 주세요.';
    return Container(
      key: const Key('weighing-panel'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _step(
                  isWeighing ? '← 기구 준비' : '1  기구 준비',
                  !isWeighing,
                  c.canChangeScale ? c.returnToEquipment : null,
                  const Key('dose-step-equipment'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _step(
                  '2  원두 담기',
                  isWeighing,
                  c.canEnterDoseWeighing ? c.enterDoseWeighing : null,
                  const Key('dose-step-beans'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                key: const Key('weighing-reading-group'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    isWeighing
                        ? 'assets/illustrations/coffee-beans.png'
                        : 'assets/illustrations/pour-over-setup.png',
                    key: const Key('setup-illustration'),
                    width: 88,
                    height: 88,
                    cacheHeight: 264,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    semanticLabel: isWeighing ? '커피 원두' : '저울 위에 놓인 서버와 드리퍼',
                  ),
                  const SizedBox(width: 16),
                  Text.rich(
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
                                    fontSize: 26,
                                    letterSpacing: 0,
                                    color: muted,
                                  ),
                                ),
                              ],
                    ),
                    key: const Key('live-weight'),
                    semanticsLabel: grams == null ? '저울 연결 대기, 0.0 g' : null,
                    style: const TextStyle(
                      fontSize: 64,
                      height: 1.1,
                      letterSpacing: -2,
                      fontWeight: FontWeight.w400,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isWeighing)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  raw == null
                      ? '저울 전체 — g'
                      : '저울 전체 ${raw.toStringAsFixed(1)} g',
                  key: const Key('setup-total-weight'),
                  style: const TextStyle(color: muted, fontSize: 11),
                ),
              ),
            ),
          const SizedBox(height: 12),
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
              if (!isWeighing) ...[
                const SizedBox(width: 8),
                TextButton(
                  key: const Key('manual-dose'),
                  onPressed: busy ? null : () => _editDose(context),
                  child: const Text('직접 입력', style: TextStyle(fontSize: 12)),
                ),
              ],
            ],
          ),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        key: const Key('apply-suggested-dose'),
                        onPressed: busy ? null : () => c.setDose(suggested),
                        child: Text('${number(suggested)}g 적용'),
                      ),
                    ],
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
                  key: Key(isWeighing ? 'manual-dose' : 'tare'),
                  onPressed:
                      isWeighing
                          ? (busy ? null : () => _editDose(context))
                          : (c.canTare ? c.tare : null),
                  style: FilledButton.styleFrom(
                    backgroundColor: mint,
                    foregroundColor: ink,
                  ),
                  child: Text(isWeighing ? '원두량 직접 입력' : 'TARE'),
                ),
              ),
              if (!isWeighing) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('enter-dose-weighing'),
                    onPressed:
                        c.canEnterDoseWeighing ? c.enterDoseWeighing : null,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: const Text('원두 담기'),
                  ),
                ),
              ],
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

  Widget _step(String label, bool selected, VoidCallback? onPressed, Key key) =>
      Semantics(
        selected: selected,
        child: TextButton(
          key: key,
          onPressed: selected ? null : onPressed,
          style: TextButton.styleFrom(
            foregroundColor: muted,
            disabledForegroundColor: selected ? ink : muted,
            backgroundColor: selected ? mint : Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      );
}
