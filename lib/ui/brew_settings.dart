import 'dart:async';
import 'package:flutter/material.dart';
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

class BrewRatioInput extends StatefulWidget {
  final double ratio;
  final bool enabled;
  final Future<void> Function(double) onChanged;
  final ValueChanged<bool> onValidityChanged;

  const BrewRatioInput({
    super.key,
    required this.ratio,
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: TextFieldTapRegion(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('원두 : 물', style: TextStyle(fontSize: 13)),
                ),
                IconButton(
                  key: const Key('decrease-ratio'),
                  tooltip: '비율 0.5 줄이기',
                  onPressed:
                      widget.enabled && widget.ratio > _minimum
                          ? () => _adjust(-_step)
                          : null,
                  icon: const Icon(Icons.remove, size: 17),
                ),
                const Text('1 :', style: TextStyle(fontSize: 23, color: muted)),
                const SizedBox(width: 6),
                SizedBox(
                  width: 66,
                  child: TextField(
                    key: const Key('ratio-input'),
                    controller: _input,
                    focusNode: _focus,
                    enabled: widget.enabled,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.done,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      filled: false,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                      border: UnderlineInputBorder(
                        borderSide: BorderSide(color: line),
                      ),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: line),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: copper),
                      ),
                    ),
                    onChanged: _edit,
                    onSubmitted: (_) => _focus.unfocus(),
                    onTapOutside: (_) => _focus.unfocus(),
                  ),
                ),
                IconButton(
                  key: const Key('increase-ratio'),
                  tooltip: '비율 0.5 늘리기',
                  onPressed:
                      widget.enabled && widget.ratio < _maximum
                          ? () => _adjust(_step)
                          : null,
                  icon: const Icon(Icons.add, size: 17),
                ),
              ],
            ),
            const SizedBox(height: 14),
            DecoratedBox(
              decoration: BoxDecoration(
                color: mint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    for (final ratio in ratioPresets)
                      Expanded(
                        child: Semantics(
                          label: '비율 1:${number(ratio)}',
                          selected: widget.ratio == ratio,
                          button: true,
                          child: Material(
                            color:
                                widget.ratio == ratio
                                    ? ink
                                    : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              key: ValueKey('ratio-preset-${number(ratio)}'),
                              borderRadius: BorderRadius.circular(10),
                              onTap:
                                  widget.enabled ? () => _choose(ratio) : null,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                  horizontal: 2,
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    number(ratio),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          widget.ratio == ratio ? paper : muted,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
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
