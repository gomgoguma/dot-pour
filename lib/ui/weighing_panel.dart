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
    final isWeighing = c.isDoseWeighing;
    final compact = MediaQuery.sizeOf(context).width < 360;
    final grams = c.setupDose;
    final suggested = c.suggestedDose;
    final busy = c.starting || c.taring;
    final connected = c.scale?.connected == true;
    final overloaded = !c.demo && c.scale?.reading?.overloaded == true;
    final status =
        busy
            ? '영점 확인 중'
            : !connected && !c.demo
            ? '저울을 연결해 주세요'
            : overloaded
            ? '저울 용량을 초과했어요'
            : c.currentGrams == null
            ? '측정값을 기다리고 있어요'
            : c.addingEquipment
            ? '기구 무게 확인 중'
            : isWeighing && grams == null
            ? '기구를 다시 준비해 주세요'
            : null;
    final ready = status == null && c.equipmentReady && suggested == null;
    return SurfaceCard(
      key: const Key('weighing-panel'),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isWeighing ? '원두 계량' : '기구 준비',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                key: const Key('manual-dose'),
                onPressed: busy ? null : () => _editDose(context),
                style: TextButton.styleFrom(
                  foregroundColor: muted,
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.edit_outlined, size: 14),
                label: const Text(
                  '원두량 직접 입력',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (isWeighing) ...[
            Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  key: const Key('weighing-reading-group'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _illustration(true),
                    const SizedBox(width: 16),
                    Text.rich(
                      TextSpan(
                        text:
                            overloaded
                                ? '용량 초과'
                                : grams?.toStringAsFixed(1) ?? '—',
                        children:
                            overloaded || grams == null
                                ? null
                                : const [
                                  TextSpan(
                                    text: ' g',
                                    style: TextStyle(
                                      fontSize: 26,
                                      letterSpacing: 0,
                                      color: copper,
                                    ),
                                  ),
                                ],
                      ),
                      key: const Key('live-weight'),
                      semanticsLabel: grams == null ? '원두량 확인 필요' : null,
                      style: const TextStyle(
                        fontSize: 56,
                        height: 1.1,
                        letterSpacing: -1.5,
                        fontWeight: FontWeight.w600,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    status ??
                        (c.confirmedDose != null
                            ? '원두량 확인 완료'
                            : (grams ?? 0) > 0
                            ? '원두 무게 확인'
                            : '원두를 담아 주세요'),
                    key: const Key('weighing-instruction'),
                    style: const TextStyle(
                      color: muted,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  key: const Key('dose-step-equipment'),
                  onPressed: c.canChangeScale ? c.returnToEquipment : null,
                  style: TextButton.styleFrom(
                    foregroundColor: muted,
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.arrow_back_rounded, size: 14),
                  label: const Text('기구 다시 준비', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  _illustration(false, size: compact ? 48 : 60),
                  SizedBox(width: compact ? 12 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          status ??
                              (c.preparingAgain
                                  ? '다시 준비해 주세요'
                                  : '서버와 드리퍼를 올려 주세요'),
                          key: const Key('weighing-instruction'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          c.preparingAgain
                              ? '원두를 빼고 기구만 올려 주세요.'
                              : ready
                              ? '준비됐어요. 원두 계량을 시작해 주세요.'
                              : '원두는 다음 단계에서 담아 주세요.',
                          key: ready ? const Key('equipment-ready-hint') : null,
                          style: TextStyle(
                            color: ready ? copperText : muted,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (suggested != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: softCopper,
                border: Border.all(color: copper.withValues(alpha: .25)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('원두를 담으셨나요?', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: TextButton(
                      key: const Key('apply-suggested-dose'),
                      onPressed: busy ? null : () => c.setDose(suggested),
                      style: TextButton.styleFrom(foregroundColor: copperText),
                      child: Text(
                        '감지된 ${number(suggested)}g 사용',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (!isWeighing) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('dose-step-beans'),
              onPressed:
                  c.canEnterDoseWeighing
                      ? () {
                        FocusScope.of(context).unfocus();
                        c.enterDoseWeighing();
                      }
                      : null,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
                backgroundColor: ready ? softCopper : mint,
                foregroundColor: ready ? copperText : ink,
                side: BorderSide(
                  color: ready ? copper.withValues(alpha: .45) : controlLine,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('원두 계량 시작', style: TextStyle(fontSize: 13)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          ],
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

  Widget _illustration(bool isWeighing, {double size = 60}) => Image.asset(
    isWeighing
        ? 'assets/illustrations/coffee-beans.png'
        : 'assets/illustrations/pour-over-setup.png',
    key: const Key('setup-illustration'),
    width: size,
    height: size,
    cacheHeight: 264,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.high,
    semanticLabel: isWeighing ? '커피 원두' : '저울 위에 놓인 서버와 드리퍼',
  );
}
