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
            ? '영점 확인 중'
            : !connected && !c.demo
            ? '저울을 연결해 주세요'
            : confirmed != null
            ? '원두량 확인 완료'
            : raw == null
            ? '측정값 기다리는 중'
            : isWeighing && grams == null
            ? '기구 준비를 다시 해주세요'
            : isWeighing
            ? '원두 무게 확인'
            : '기구를 올려 주세요';
    return SurfaceCard(
      key: const Key('weighing-panel'),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  instruction,
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
                    width: 60,
                    height: 60,
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
                                    color: copper,
                                  ),
                                ),
                              ],
                    ),
                    key: const Key('live-weight'),
                    semanticsLabel: grams == null ? '저울 연결 대기, 0.0 g' : null,
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _step(
                  '1  기구 준비',
                  !isWeighing,
                  c.canChangeScale ? c.returnToEquipment : null,
                  const Key('dose-step-equipment'),
                  Icons.arrow_back_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _step(
                  '2  원두 담기',
                  isWeighing,
                  c.canEnterDoseWeighing ? c.enterDoseWeighing : null,
                  const Key('dose-step-beans'),
                  Icons.arrow_forward_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _step(
    String label,
    bool selected,
    VoidCallback? onPressed,
    Key key,
    IconData navigationIcon,
  ) => Semantics(
    selected: selected,
    child: TextButton(
      key: key,
      onPressed: selected ? null : onPressed,
      style: TextButton.styleFrom(
        foregroundColor: ink,
        disabledForegroundColor:
            selected ? copperText : muted.withValues(alpha: .6),
        backgroundColor: selected ? softCopper : Colors.white,
        side: BorderSide(
          color: selected ? copper.withValues(alpha: .45) : controlLine,
        ),
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!selected) ...[
            Icon(navigationIcon, size: 15),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
