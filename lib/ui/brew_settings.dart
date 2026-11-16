import 'package:flutter/material.dart';
import '../brew_session.dart';
import 'style.dart';

const ratioPresets = <double>[9, 10, 11, 15, 16.7, 17];

class DoseRatioFields extends StatelessWidget {
  final TextEditingController dose, ratio;
  final VoidCallback onChanged;
  const DoseRatioFields({
    super.key,
    required this.dose,
    required this.ratio,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    void adjust(double delta) {
      final value = parseNumber(dose.text);
      dose.text = number(
        ((value.isFinite ? value : 20) + delta).clamp(0.1, 100),
      );
      onChanged();
    }

    final target = parseNumber(dose.text) * parseNumber(ratio.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('추출 기준'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                key: const Key('dose-input'),
                controller: dose,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w600,
                ),
                decoration: const InputDecoration(
                  labelText: '원두량',
                  suffixText: 'g',
                ),
                onChanged: (_) => onChanged(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                key: const Key('ratio-input'),
                controller: ratio,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w600,
                ),
                decoration: const InputDecoration(
                  labelText: '원두 : 물',
                  prefixText: '1 : ',
                ),
                onChanged: (_) => onChanged(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            IconButton.outlined(
              tooltip: '원두 1g 줄이기',
              onPressed: () => adjust(-1),
              icon: const Icon(Icons.remove, size: 16),
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              tooltip: '원두 1g 늘리기',
              onPressed: () => adjust(1),
              icon: const Icon(Icons.add, size: 16),
            ),
            const Spacer(),
            Text(
              target.isFinite ? '목표 ${number(target)} g' : '목표 — g',
              style: const TextStyle(color: muted, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text('자주 쓰는 비율', style: TextStyle(color: muted, fontSize: 12)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children:
              ratioPresets
                  .map(
                    (value) => ChoiceChip(
                      label: Text('1:${number(value)}'),
                      selected: parseNumber(ratio.text) == value,
                      onSelected: (_) {
                        ratio.text = number(value);
                        onChanged();
                      },
                    ),
                  )
                  .toList(),
        ),
      ],
    );
  }
}

class BrewSettingsSheet extends StatefulWidget {
  final double ratio;
  final bool scaling;
  final Future<void> Function(double) onSave;
  const BrewSettingsSheet({
    super.key,
    required this.ratio,
    required this.onSave,
    this.scaling = false,
  });
  @override
  State<BrewSettingsSheet> createState() => _BrewSettingsSheetState();
}

class _BrewSettingsSheetState extends State<BrewSettingsSheet> {
  late final _ratio = TextEditingController(text: number(widget.ratio));
  String? error;
  bool busy = false;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionLabel('추출 비율'),
            TextField(
              key: const Key('ratio-input'),
              controller: _ratio,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                labelText: '원두 : 물',
                prefixText: '1 : ',
              ),
              onChanged: (_) => setState(() => error = null),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final value in ratioPresets)
                  ChoiceChip(
                    label: Text('1:${number(value)}'),
                    selected: parseNumber(_ratio.text) == value,
                    onSelected:
                        (_) => setState(() {
                          _ratio.text = number(value);
                          error = null;
                        }),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              widget.scaling
                  ? '추출 시작 시 계량한 원두량과 비율에 맞춰 붓기 계획을 조정합니다.'
                  : '원두량은 저울로 계량합니다. 추출 시작 시 목표 물의 무게를 계산합니다.',
              style: const TextStyle(color: muted, fontSize: 12),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed:
                  busy
                      ? null
                      : () async {
                        final ratio = parseNumber(_ratio.text);
                        final validation = BrewSession.validate(1, ratio);
                        if (validation != null) {
                          setState(() => error = validation);
                          return;
                        }
                        setState(() => busy = true);
                        try {
                          await widget.onSave(ratio);
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          if (mounted) {
                            setState(() {
                              error = '$e';
                              busy = false;
                            });
                          }
                        }
                      },
              key: const Key('confirm-ratio'),
              child: const Text('설정 완료'),
            ),
          ],
        ),
      ),
    ),
  );
  @override
  void dispose() {
    _ratio.dispose();
    super.dispose();
  }
}
