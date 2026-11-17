import 'dart:async';
import 'package:flutter/material.dart';
import 'style.dart';

const _ratioPresetGroups = [
  (label: 'ICE', ratios: <double>[9, 10, 11]),
  (label: 'HOT', ratios: <double>[15, 16.7, 17]),
];

class _RatioPresets extends StatelessWidget {
  final double selectedRatio;
  final ValueChanged<double>? onChanged;

  const _RatioPresets({required this.selectedRatio, required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < _ratioPresetGroups.length; i++) ...[
        if (i > 0) const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _ratioPresetGroups[i].label,
                style: const TextStyle(
                  color: muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  for (
                    var j = 0;
                    j < _ratioPresetGroups[i].ratios.length;
                    j++
                  ) ...[
                    if (j > 0) const SizedBox(width: 5),
                    Expanded(
                      child: _preset(
                        _ratioPresetGroups[i].ratios[j],
                        _ratioPresetGroups[i].label,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    ],
  );

  Widget _preset(double ratio, String group) {
    final selected = selectedRatio == ratio;
    return Semantics(
      label: '$group 비율 1:${number(ratio)}',
      selected: selected,
      button: true,
      child: Material(
        color: selected ? ink : Colors.white,
        elevation: selected ? 1 : 0,
        shadowColor: const Color(0x20211f1c),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? ink : line),
        ),
        child: InkWell(
          key: ValueKey('ratio-preset-${number(ratio)}'),
          borderRadius: BorderRadius.circular(12),
          onTap: onChanged == null ? null : () => onChanged!(ratio),
          child: SizedBox(
            height: 40,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    number(ratio),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? Colors.white : ink,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
        _RatioPresets(
          selectedRatio: parseNumber(ratio.text),
          onChanged: (value) {
            ratio.text = number(value);
            onChanged();
          },
        ),
      ],
    );
  }
}

class BrewRatioInput extends StatefulWidget {
  final double ratio;
  final double? target;
  final bool enabled;
  final Future<void> Function(double) onChanged;
  final ValueChanged<bool> onValidityChanged;

  const BrewRatioInput({
    super.key,
    required this.ratio,
    this.target,
    required this.enabled,
    required this.onChanged,
    required this.onValidityChanged,
  });

  @override
  State<BrewRatioInput> createState() => _BrewRatioInputState();
}

class _BrewRatioInputState extends State<BrewRatioInput> {
  static const _minimum = 1.0;
  static const _maximum = 30.0;
  static const _step = 0.5;
  late final _input = TextEditingController(text: _display(widget.ratio));
  late final _focus = FocusNode()..addListener(_focusChanged);
  bool _valid = true;
  String? _saveError;

  String _display(double ratio) =>
      ratio == ratio.roundToDouble()
          ? ratio.toInt().toString()
          : ratio.toString();

  double? _parse(String text) {
    final value = parseNumber(text);
    return value.isFinite && value >= _minimum && value <= _maximum
        ? value
        : null;
  }

  void _writeRatio(double ratio) {
    final text = _display(ratio);
    _input.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _setValidity(bool valid) {
    if (valid == _valid) return;
    setState(() => _valid = valid);
    widget.onValidityChanged(valid);
  }

  void _focusChanged() {
    if (_focus.hasFocus) {
      _input.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _input.text.length,
      );
    } else if (!_valid) {
      _writeRatio(widget.ratio);
      _setValidity(true);
    }
  }

  @override
  void didUpdateWidget(covariant BrewRatioInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Preserve the decimal separator and cursor during an active edit.
    if (oldWidget.ratio != widget.ratio &&
        _parse(_input.text) != widget.ratio &&
        (!_focus.hasFocus || _valid)) {
      _writeRatio(widget.ratio);
    }
  }

  Future<void> _apply(double ratio) async {
    if (_saveError != null) setState(() => _saveError = null);
    try {
      await widget.onChanged(ratio);
    } catch (_) {
      if (mounted && _parse(_input.text) == ratio) {
        setState(() => _saveError = '비율을 저장하지 못했습니다.');
      }
    }
  }

  void _edit(String text) {
    final ratio = _parse(text);
    _setValidity(ratio != null);
    if (ratio != null) unawaited(_apply(ratio));
  }

  void _adjust(double delta) {
    final current = _parse(_input.text) ?? widget.ratio;
    final ratio = double.parse(
      (current + delta).clamp(_minimum, _maximum).toStringAsFixed(6),
    );
    _choose(ratio);
  }

  void _choose(double ratio) {
    _writeRatio(ratio);
    _setValidity(true);
    unawaited(_apply(ratio));
  }

  @override
  Widget build(BuildContext context) {
    final error = _valid ? _saveError : '비율은 1:1~1:30으로 입력해 주세요.';
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: TextFieldTapRegion(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '추출 비율',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  widget.target == null
                      ? '목표 —'
                      : '목표 ${number(widget.target!)}g',
                  style: TextStyle(
                    color: widget.target == null ? muted : copperText,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton.outlined(
                    key: const Key('decrease-ratio'),
                    style: circleControlStyle(),
                    tooltip: '비율 0.5 줄이기',
                    onPressed:
                        widget.enabled && widget.ratio > _minimum
                            ? () => _adjust(-_step)
                            : null,
                    icon: const Icon(Icons.remove, size: 19),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              '1 :',
                              style: TextStyle(
                                fontSize: 22,
                                color: muted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            SizedBox(
                              width: 68,
                              child: TextField(
                                key: const Key('ratio-input'),
                                controller: _input,
                                focusNode: _focus,
                                enabled: widget.enabled,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                textInputAction: TextInputAction.done,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -.8,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  filled: false,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                ),
                                onChanged: _edit,
                                onSubmitted: (_) => _focus.unfocus(),
                                onTapOutside: (_) => _focus.unfocus(),
                              ),
                            ),
                          ],
                        ),
                        const Text(
                          '원두 : 물',
                          style: TextStyle(fontSize: 10, color: muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton.outlined(
                    key: const Key('increase-ratio'),
                    style: circleControlStyle(),
                    tooltip: '비율 0.5 늘리기',
                    onPressed:
                        widget.enabled && widget.ratio < _maximum
                            ? () => _adjust(_step)
                            : null,
                    icon: const Icon(Icons.add, size: 19),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
            _RatioPresets(
              selectedRatio: widget.ratio,
              onChanged: widget.enabled ? _choose : null,
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  error,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _focus.removeListener(_focusChanged);
    _focus.dispose();
    _input.dispose();
    super.dispose();
  }
}
