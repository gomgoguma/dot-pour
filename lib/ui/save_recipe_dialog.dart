import 'package:flutter/material.dart';
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
    text: '${DateTime.now().month}월 ${DateTime.now().day}일 추출',
  );
  final _beans = TextEditingController();
  final _memo = TextEditingController();
  int _acidity = 0, _sweetness = 0, _body = 0;
  bool _busy = false;
  String? _error;

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = '이름을 입력해 주세요.');
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
          _error = '저장하지 못했습니다. 다시 시도해 주세요.';
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
      title: const Text(
        '레시피 저장',
        style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${number(widget.controller.brew.water)}g · ${clockText(widget.controller.brew.seconds)}${widget.controller.demo ? ' · 데모 기록' : ''}',
              style: const TextStyle(
                color: copper,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '추출 그래프와 함께, 오늘의 한 잔을 남겨보세요.',
              style: TextStyle(color: muted, fontSize: 12, height: 1.6),
            ),
            const SizedBox(height: 20),
            TextField(
              key: const Key('save-recipe-name'),
              controller: _name,
              enabled: !_busy,
              maxLength: 60,
              decoration: const InputDecoration(
                labelText: '레시피 이름',
                counterText: '',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('save-recipe-beans'),
              controller: _beans,
              enabled: !_busy,
              maxLength: 100,
              decoration: const InputDecoration(
                labelText: '원두 · 선택',
                hintText: '예: 에티오피아 예가체프',
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
              decoration: const InputDecoration(
                labelText: '추출 메모 · 선택',
                hintText: '분쇄도, 물 온도, 기억하고 싶은 맛',
                alignLabelWithHint: true,
                counterText: '',
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              '오늘의 맛',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              '선택 사항 · 선택한 별을 다시 누르면 해제돼요.',
              style: TextStyle(color: muted, fontSize: 10),
            ),
            const SizedBox(height: 8),
            TasteRating(
              label: '산미',
              id: 'acidity',
              value: _acidity,
              onChanged: _busy ? null : (v) => setState(() => _acidity = v),
            ),
            TasteRating(
              label: '단맛',
              id: 'sweetness',
              value: _sweetness,
              onChanged: _busy ? null : (v) => setState(() => _sweetness = v),
            ),
            TasteRating(
              label: '바디감',
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
          child: const Text('나중에'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? '저장 중…' : '저장'),
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
            tooltip: '$label $star점',
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
        const SectionLabel(
          '한 잔의 기록',
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
          (label: '산미', value: notes.acidity),
          (label: '단맛', value: notes.sweetness),
          (label: '바디감', value: notes.body),
        ])
          if (rating.value > 0)
            Semantics(
              label: '${rating.label} ${rating.value}점 / 5점',
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
