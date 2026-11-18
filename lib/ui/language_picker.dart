import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../l10n/language.dart';
import 'brand_mark.dart';
import 'style.dart';

class LanguagePicker extends StatefulWidget {
  final AppLanguage initialLanguage;
  final bool firstRun;
  final Future<bool> Function(AppLanguage) onApply;

  const LanguagePicker({
    super.key,
    required this.initialLanguage,
    required this.firstRun,
    required this.onApply,
  });

  @override
  State<LanguagePicker> createState() => _LanguagePickerState();
}

class _LanguagePickerState extends State<LanguagePicker> {
  late AppLanguage _selected = widget.initialLanguage;
  late final _wheel = FixedExtentScrollController(
    initialItem: widget.initialLanguage.index,
  );
  bool _saving = false;
  bool _saveFailed = false;

  void _center(AppLanguage language) {
    if (_saving) return;
    final count = AppLanguage.values.length;
    final current = _wheel.selectedItem;
    final forward = (language.index - current) % count;
    final offset = forward <= count ~/ 2 ? forward : forward - count;
    _wheel.animateToItem(
      current + offset,
      duration: const Duration(milliseconds: 230),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _apply() async {
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    final saved = await widget.onApply(_selected);
    if (!mounted) return;
    if (saved && !widget.firstRun) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = false;
      _saveFailed = !saved;
    });
  }

  @override
  void dispose() {
    _wheel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.firstRun ? 'Language' : context.l10n.language;
    final strings = _selected.strings;
    return Scaffold(
      appBar: widget.firstRun ? null : AppBar(),
      body: SafeArea(
        child: LayoutBuilder(
          builder:
              (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (constraints.maxHeight - 48).clamp(
                      0,
                      double.infinity,
                    ),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 340),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.firstRun) ...[
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                BrandMark(size: 35),
                                SizedBox(width: 9),
                                Text(
                                  'dot pour',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -1.1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 58),
                          ],
                          Semantics(
                            header: true,
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -.35,
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          SizedBox(
                            height: 176,
                            child: ScrollConfiguration(
                              behavior: const MaterialScrollBehavior().copyWith(
                                dragDevices: {
                                  PointerDeviceKind.touch,
                                  PointerDeviceKind.mouse,
                                  PointerDeviceKind.stylus,
                                },
                              ),
                              child: CupertinoPicker(
                                key: const Key('language-wheel'),
                                scrollController: _wheel,
                                itemExtent: 56,
                                diameterRatio: 1.7,
                                useMagnifier: true,
                                magnification: 1.13,
                                looping: true,
                                selectionOverlay: null,
                                onSelectedItemChanged:
                                    (index) => setState(() {
                                      _selected = AppLanguage.values[index];
                                      _saveFailed = false;
                                    }),
                                children: [
                                  for (final language in AppLanguage.values)
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => _center(language),
                                      child: Center(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          child: Text(
                                            language.nameInLanguage,
                                            maxLines: 1,
                                            style: TextStyle(
                                              fontSize:
                                                  language == _selected
                                                      ? 23
                                                      : 17,
                                              fontWeight:
                                                  language == _selected
                                                      ? FontWeight.w700
                                                      : FontWeight.w500,
                                              color:
                                                  language == _selected
                                                      ? ink
                                                      : muted,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          FilledButton(
                            key: const Key('apply-language'),
                            onPressed: _saving ? null : _apply,
                            child: Text(
                              widget.firstRun
                                  ? strings.continueAction
                                  : strings.applyLanguage,
                            ),
                          ),
                          if (_saveFailed)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                strings.languageSaveError,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                        ],
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
