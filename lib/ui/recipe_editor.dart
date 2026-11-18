import 'package:flutter/material.dart';
import '../l10n/language.dart';
import '../recipe.dart';
import 'brew_settings.dart';
import 'brew_chart.dart';
import 'style.dart';

class RecipeEditor extends StatefulWidget {
  final BrewRecipe? initial;
  final double dose, ratio;
  final Future<void> Function(BrewRecipe) onSave;
  const RecipeEditor({
    super.key,
    this.initial,
    required this.dose,
    required this.ratio,
    required this.onSave,
  });
  @override
  State<RecipeEditor> createState() => _RecipeEditorState();
}

class _StepFields {
  final TextEditingController start, duration, amount;
  _StepFields(double s, double d, double a)
    : start = TextEditingController(text: number(s, 2)),
      duration = TextEditingController(text: number(d, 2)),
      amount = TextEditingController(text: number(a, 4));
  PourStep get step => PourStep(
    start: parseNumber(start.text),
    duration: parseNumber(duration.text),
    amount: parseNumber(amount.text),
  );
  void dispose() {
    start.dispose();
    duration.dispose();
    amount.dispose();
  }
}

class _RecipeEditorState extends State<RecipeEditor> {
  late final TextEditingController _name, _dose, _ratio, _duration;
  late PourUnit _unit;
  final _rows = <_StepFields>[];
  String? _error;
  bool _busy = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_rows.isNotEmpty) return;
    final initial = widget.initial;
    _name = TextEditingController(
      text:
          initial == null
              ? ''
              : initial.recorded
              ? context.l10n.planFromName(initial.name)
              : initial.name,
    );
    _dose = TextEditingController(text: number(initial?.dose ?? widget.dose));
    _ratio = TextEditingController(
      text: number(initial?.ratio ?? widget.ratio),
    );
    _duration = TextEditingController(
      text: number(initial?.duration.ceilToDouble() ?? 180),
    );
    _unit = initial?.unit ?? PourUnit.percent;
    final steps =
        initial?.steps ??
        [
          const PourStep(start: 0, duration: 10, amount: 20),
          const PourStep(start: 45, duration: 20, amount: 40),
          const PourStep(start: 90, duration: 20, amount: 40),
        ];
    for (final step in steps) {
      _rows.add(_StepFields(step.start, step.duration, step.amount));
    }
    if (_rows.isEmpty) {
      _rows.add(_StepFields(0, 30, _unit == PourUnit.percent ? 100 : _target));
    }
    _rows.first.start.text = '0';
  }

  double get _target => parseNumber(_dose.text) * parseNumber(_ratio.text);
  double get _sum =>
      _rows.fold(0, (sum, row) => sum + parseNumber(row.amount.text));
  void _refresh() => setState(() => _error = null);
  BrewRecipe _draft() {
    final now = DateTime.now();
    return BrewRecipe(
      id:
          widget.initial != null && !widget.initial!.recorded
              ? widget.initial!.id
              : 'plan-${now.microsecondsSinceEpoch}',
      name: _name.text.trim(),
      dose: parseNumber(_dose.text),
      ratio: parseNumber(_ratio.text),
      unit: _unit,
      steps: _rows.map((r) => r.step).toList(),
      duration: parseNumber(_duration.text),
      createdAt: widget.initial?.createdAt ?? now,
      notes: widget.initial?.notes ?? const BrewNotes(),
    );
  }

  void _changeUnit(PourUnit next) {
    if (next == _unit) return;
    if (!_target.isFinite || _target <= 0) {
      setState(() => _error = context.l10n.doseAndRatioFirst);
      return;
    }
    for (final row in _rows) {
      final amount = parseNumber(row.amount.text);
      if (amount.isFinite) {
        row.amount.text = number(
          next == PourUnit.percent
              ? amount / _target * 100
              : amount * _target / 100,
          4,
        );
      }
    }
    setState(() {
      _unit = next;
      _error = null;
    });
  }

  Future<void> _save() async {
    final recipe = _draft();
    final error = recipe.validate(context.l10n);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.onSave(recipe);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = context.l10n.saveError(e);
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft();
    final amountGrams = _unit == PourUnit.percent ? _sum * _target / 100 : _sum;
    final matched =
        amountGrams.isFinite &&
        _target.isFinite &&
        (amountGrams - _target).abs() <= 0.2;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initial == null
              ? context.l10n.createRecipe
              : widget.initial!.recorded
              ? context.l10n.planFromBrew
              : context.l10n.editRecipe,
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(
                    _busy ? context.l10n.saving : context.l10n.saveRecipe,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  key: const Key('recipe-name'),
                  controller: _name,
                  maxLength: 60,
                  decoration: InputDecoration(
                    labelText: context.l10n.recipeName,
                    hintText: context.l10n.recipeNameExample,
                  ),
                  onChanged: (_) => _refresh(),
                ),
                const SizedBox(height: 20),
                DoseRatioFields(
                  dose: _dose,
                  ratio: _ratio,
                  onChanged: _refresh,
                ),
                const SizedBox(height: 30),
                SectionLabel(
                  context.l10n.pourPlan(_rows.length),
                  trailing: TextButton(
                    onPressed: () {
                      if (_target.isFinite && _rows.isNotEmpty) {
                        final each =
                            (_unit == PourUnit.percent ? 100 : _target) /
                            _rows.length;
                        for (final row in _rows) {
                          row.amount.text = number(each, 4);
                        }
                        _refresh();
                      }
                    },
                    child: Text(context.l10n.splitEvenly),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<PourUnit>(
                    segments: [
                      ButtonSegment(
                        value: PourUnit.grams,
                        label: Text(context.l10n.weightUnit),
                      ),
                      ButtonSegment(
                        value: PourUnit.percent,
                        label: Text(context.l10n.percentUnit),
                      ),
                    ],
                    selected: {_unit},
                    onSelectionChanged: (values) => _changeUnit(values.single),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _unit == PourUnit.percent
                      ? context.l10n.pourPercentHint
                      : context.l10n.pourWeightHint,
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 16),
                ...List.generate(_rows.length, (i) {
                  final row = _rows[i];
                  return Container(
                    key: ObjectKey(row),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: mint,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              i == 0
                                  ? context.l10n.firstPour
                                  : context.l10n.pourNumber(i + 1),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: context.l10n.removePour(i + 1),
                              onPressed:
                                  _rows.length == 1
                                      ? null
                                      : () {
                                        setState(() {
                                          _rows.removeAt(i);
                                          _rows.first.start.text = '0';
                                        });
                                        row.dispose();
                                      },
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                size: 19,
                                color: muted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _field(
                                row.start,
                                context.l10n.pourStartSeconds,
                                enabled: i != 0,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _field(
                                row.duration,
                                context.l10n.pourDurationSeconds,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _field(
                                row.amount,
                                _unit == PourUnit.percent
                                    ? context.l10n.pourAddPercent
                                    : context.l10n.pourAddGrams,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
                OutlinedButton.icon(
                  onPressed:
                      _rows.length >= 20
                          ? null
                          : () {
                            final lastEnd = _rows.last.step.end;
                            _rows.add(
                              _StepFields(
                                lastEnd.isFinite ? lastEnd + 20 : 0,
                                20,
                                0,
                              ),
                            );
                            _refresh();
                          },
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(context.l10n.addPour),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: matched ? mint : const Color(0xfff4e7d9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${context.l10n.pourPlanTotal(amountGrams.isFinite ? number(amountGrams) : '—', _target.isFinite ? number(_target) : '—')}'
                    '${_unit == PourUnit.percent ? '  ·  ${_sum.isFinite ? number(_sum, 2) : '—'}%' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 22),
                TextField(
                  controller: _duration,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: context.l10n.totalBrewTime,
                    suffixText: context.l10n.secondsUnit,
                    helperText: context.l10n.totalBrewTimeHint,
                  ),
                  onChanged: (_) => _refresh(),
                ),
                if (draft.validate() == null) ...[
                  const SizedBox(height: 24),
                  SectionLabel(context.l10n.previewPlan),
                  BrewChart(
                    points: const [],
                    reference: draft,
                    target: draft.target,
                    height: 170,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool enabled = true,
  }) => TextField(
    controller: controller,
    enabled: enabled,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(
      labelText: label,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
    ),
    onChanged: (_) => _refresh(),
  );
  @override
  void dispose() {
    _name.dispose();
    _dose.dispose();
    _ratio.dispose();
    _duration.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }
}
