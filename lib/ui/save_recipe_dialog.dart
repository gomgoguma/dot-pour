import 'package:flutter/material.dart';
import '../l10n/language.dart';
import '../brew_controller.dart';
import '../recipe.dart';
import 'style.dart';

class SaveRecipeDialog extends StatefulWidget {
  final BrewController controller;
  const SaveRecipeDialog({super.key, required this.controller});

  @override
  State<SaveRecipeDialog> createState() => _SaveRecipeDialogState();
}

class _SaveRecipeDialogState extends State<SaveRecipeDialog> {
  late final _name = TextEditingController(
    text: context.l10n.datedBrewName(DateTime.now().month, DateTime.now().day),
  );
  final _beans = TextEditingController();
  final _memo = TextEditingController();
  int _acidity = 0, _sweetness = 0, _body = 0;
  bool _busy = false;
  String? _error;

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = context.l10n.nameRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.controller.saveFinished(
        _name.text.trim(),
        notes: BrewNotes(
          beans: _beans.text.trim(),
          memo: _memo.text.trim(),
          acidity: _acidity,
          sweetness: _sweetness,
          body: _body,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = context.l10n.saveRetry;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      scrollable: true,
      title: Text(
        context.l10n.saveRecipe,
        style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${number(widget.controller.brew.water)}g · ${clockText(widget.controller.brew.seconds)}${widget.controller.demo ? context.l10n.demoRecordSuffix : ''}',
              style: const TextStyle(
                color: copper,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.saveBrewHint,
              style: TextStyle(color: muted, fontSize: 12, height: 1.6),
            ),
            const SizedBox(height: 20),
            TextField(
              key: const Key('save-recipe-name'),
              controller: _name,
              enabled: !_busy,
              maxLength: 60,
              decoration: InputDecoration(
                labelText: context.l10n.recipeName,
                counterText: '',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('save-recipe-beans'),
              controller: _beans,
              enabled: !_busy,
              maxLength: 100,
              decoration: InputDecoration(
                labelText: context.l10n.optionalBeans,
                hintText: context.l10n.beansExample,
                counterText: '',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('save-recipe-memo'),
              controller: _memo,
              enabled: !_busy,
              maxLength: 1000,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: context.l10n.optionalNotes,
                hintText: context.l10n.notesExample,
                alignLabelWithHint: true,
                counterText: '',
              ),
            ),
            const SizedBox(height: 22),
            Text(
              context.l10n.tastingNotes,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.ratingHint,
              style: TextStyle(color: muted, fontSize: 10),
            ),
            const SizedBox(height: 8),
            TasteRating(
              label: context.l10n.acidity,
              id: 'acidity',
              value: _acidity,
              onChanged: _busy ? null : (v) => setState(() => _acidity = v),
            ),
            TasteRating(
              label: context.l10n.sweetness,
              id: 'sweetness',
              value: _sweetness,
              onChanged: _busy ? null : (v) => setState(() => _sweetness = v),
            ),
            TasteRating(
              label: context.l10n.body,
              id: 'body',
              value: _body,
              onChanged: _busy ? null : (v) => setState(() => _body = v),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(context.l10n.later),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? context.l10n.saving : context.l10n.save),
        ),
      ],
    ),
  );

  @override
  void dispose() {
    _name.dispose();
    _beans.dispose();
    _memo.dispose();
    super.dispose();
  }
}

class TasteRating extends StatelessWidget {
  final String label, id;
  final int value;
  final ValueChanged<int>? onChanged;
  const TasteRating({
    super.key,
    required this.label,
    required this.id,
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(label, style: const TextStyle(fontSize: 13, color: muted)),
      ),
      for (var star = 1; star <= 5; star++)
        SizedBox(
          width: 36,
          height: 44,
          child: IconButton(
            key: ValueKey('rating-$id-$star'),
            tooltip: context.l10n.ratingOption(label, star),
            isSelected: star <= value,
            padding: EdgeInsets.zero,
            onPressed:
                onChanged == null
                    ? null
                    : () => onChanged!(value == star ? 0 : star),
            icon: Icon(
              star <= value ? Icons.star_rounded : Icons.star_border_rounded,
              size: 27,
              color: star <= value ? copper : line,
            ),
          ),
        ),
    ],
  );
}

class RecipeNotesCard extends StatelessWidget {
  final BrewNotes notes;
  const RecipeNotesCard({super.key, required this.notes});

  @override
  Widget build(BuildContext context) => SurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(
          context.l10n.cupRecord,
          trailing: Icon(Icons.edit_note_rounded, size: 22, color: copper),
        ),
        if (notes.beans.isNotEmpty)
          Text(
            notes.beans,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        if (notes.memo.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Text(
              notes.memo,
              style: const TextStyle(fontSize: 13, height: 1.7, color: muted),
            ),
          ),
        for (final rating in [
          (label: context.l10n.acidity, value: notes.acidity),
          (label: context.l10n.sweetness, value: notes.sweetness),
          (label: context.l10n.body, value: notes.body),
        ])
          if (rating.value > 0)
            Semantics(
              label: context.l10n.ratingOutOfFive(rating.label, rating.value),
              excludeSemantics: true,
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        rating.label,
                        style: const TextStyle(fontSize: 12, color: muted),
                      ),
                    ),
                    for (var star = 1; star <= 5; star++)
                      Icon(
                        star <= rating.value
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: star <= rating.value ? copper : line,
                        size: 21,
                      ),
                  ],
                ),
              ),
            ),
      ],
    ),
  );
}
