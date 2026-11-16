import 'package:flutter/material.dart';
import '../brew_controller.dart';
import 'brand_mark.dart';
import 'style.dart';

class ScaleSelectionScreen extends StatefulWidget {
  final BrewController controller;
  final bool firstRun;
  const ScaleSelectionScreen({
    super.key,
    required this.controller,
    this.firstRun = false,
  });
  @override
  State<ScaleSelectionScreen> createState() => _ScaleSelectionScreenState();
}

class _ScaleSelectionScreenState extends State<ScaleSelectionScreen> {
  late String selected =
      widget.controller.scale?.info.id ??
      widget.controller.scaleRegistry.models.first.info.id;
  bool saving = false;
  String? error;

  Future<void> _select() async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.controller.selectScale(selected);
      if (mounted && !widget.firstRun) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = '$e';
          saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: !widget.firstRun,
      title: Text(widget.firstRun ? 'dot pour' : '저울 선택'),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          children: [
            const Center(child: BrandMark(size: 72)),
            const SizedBox(height: 24),
            Text(
              '저울 모델 선택',
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              widget.firstRun
                  ? '사용할 모델을 선택하세요.\n추출 화면에서 변경할 수 있습니다.'
                  : '모델 변경 시 기존 연결이 해제됩니다.\n원두량과 저장된 레시피는 유지됩니다.',
              style: const TextStyle(color: muted, height: 1.7),
            ),
            const SizedBox(height: 32),
            for (final model in widget.controller.scaleRegistry.models)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: selected == model.info.id ? mint : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  child: InkWell(
                    key: ValueKey('scale-${model.info.id}'),
                    borderRadius: BorderRadius.circular(22),
                    onTap:
                        saving
                            ? null
                            : () => setState(() => selected = model.info.id),
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  model.info.manufacturer,
                                  style: const TextStyle(
                                    color: copper,
                                    fontSize: 11,
                                    letterSpacing: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  model.info.name,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '${model.info.modelCode} · 최대 ${number(model.info.capacityGrams)}g',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Icon(
                            selected == model.info.id
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            color: selected == model.info.id ? ink : muted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            const Text(
              '저울 선택 후 블루투스로 연결합니다.',
              style: TextStyle(fontSize: 12, color: muted, height: 1.6),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: saving ? null : _select,
                child: Text(
                  saving
                      ? '저장 중…'
                      : widget.firstRun
                      ? '이 저울로 시작'
                      : '이 저울 사용',
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
