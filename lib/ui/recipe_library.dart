import 'package:flutter/material.dart';
import '../brew_controller.dart';
import '../recipe.dart';
import 'brew_chart.dart';
import 'recipe_editor.dart';
import 'style.dart';

class RecipeLibrary extends StatelessWidget {
  final BrewController controller;
  const RecipeLibrary({super.key, required this.controller});
  Future<void> _edit(BuildContext context, [BrewRecipe? recipe]) =>
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder:
              (_) => RecipeEditor(
                initial: recipe,
                dose: controller.brew.dose,
                ratio: controller.brew.ratio,
                onSave: controller.upsertRecipe,
              ),
        ),
      );
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder:
        (context, _) => Scaffold(
          appBar: AppBar(
            title: const Text('내 레시피'),
            actions: [
              IconButton(
                tooltip: '수동 레시피 만들기',
                onPressed: () => _edit(context),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child:
                  controller.recipes.isEmpty
                      ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.menu_book_rounded,
                                size: 48,
                                color: copper,
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                '좋았던 한 잔을 다시',
                                style: TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                '붓기 계획을 미리 만들거나\n추출을 마친 뒤 그래프를 저장해 보세요.',
                                style: TextStyle(color: muted, height: 1.7),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              FilledButton.icon(
                                onPressed: () => _edit(context),
                                icon: const Icon(Icons.add),
                                label: const Text('첫 레시피 만들기'),
                              ),
                            ],
                          ),
                        ),
                      )
                      : ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          Text(
                            '${controller.recipes.length}개의 레시피 · 이 기기에 저장됨',
                            style: const TextStyle(color: muted, fontSize: 12),
                          ),
                          const SizedBox(height: 18),
                          ...controller.recipes.map(
                            (recipe) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Material(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(22),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(22),
                                  onTap: () async {
                                    final loaded = await Navigator.push<bool>(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) => RecipeDetail(
                                              recipe: recipe,
                                              controller: controller,
                                            ),
                                      ),
                                    );
                                    if (context.mounted && loaded == true) {
                                      Navigator.pop(context);
                                    }
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              recipe.recorded
                                                  ? Icons.show_chart
                                                  : Icons.format_list_numbered,
                                              size: 17,
                                              color: copper,
                                            ),
                                            const SizedBox(width: 7),
                                            Text(
                                              recipe.isDemo
                                                  ? '데모 기록'
                                                  : recipe.recorded
                                                  ? '추출 기록'
                                                  : '수동 계획',
                                              style: const TextStyle(
                                                color: copper,
                                                fontSize: 11,
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              '${recipe.createdAt.month}.${recipe.createdAt.day}',
                                              style: const TextStyle(
                                                color: muted,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          recipe.name,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '${number(recipe.dose)}g  ·  1:${number(recipe.ratio)}  ·  ${recipe.steps.length}차  ·  ${clockText(recipe.duration)}',
                                                style: const TextStyle(
                                                  color: muted,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            const Icon(
                                              Icons.arrow_forward_rounded,
                                              size: 18,
                                            ),
                                          ],
                                        ),
                                      ],
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
        ),
  );
}

class RecipeDetail extends StatelessWidget {
  final BrewRecipe recipe;
  final BrewController controller;
  const RecipeDetail({
    super.key,
    required this.recipe,
    required this.controller,
  });
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder:
        (context, _) => Scaffold(
          appBar: AppBar(
            title: const Text('레시피'),
            actions: [
              IconButton(
                tooltip: '레시피 삭제',
                icon: const Icon(Icons.delete_outline, size: 21),
                onPressed:
                    controller.libraryBusy
                        ? null
                        : () async {
                          final yes = await showDialog<bool>(
                            context: context,
                            builder:
                                (context) => AlertDialog(
                                  title: const Text('레시피를 삭제할까요?'),
                                  content: Text(recipe.name),
                                  actions: [
                                    TextButton(
                                      onPressed:
                                          () => Navigator.pop(context, false),
                                      child: const Text('취소'),
                                    ),
                                    TextButton(
                                      onPressed:
                                          () => Navigator.pop(context, true),
                                      child: const Text('삭제'),
                                    ),
                                  ],
                                ),
                          );
                          if (yes == true) {
                            try {
                              await controller.deleteRecipe(recipe.id);
                              if (context.mounted) Navigator.pop(context);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('삭제 실패: $e')),
                                );
                              }
                            }
                          }
                        },
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: FilledButton.icon(
                onPressed:
                    controller.brew.active
                        ? null
                        : () async {
                          try {
                            await controller.loadRecipe(recipe);
                            if (context.mounted) Navigator.pop(context, true);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text('$e')));
                            }
                          }
                        },
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(
                  controller.brew.active ? '진행 중인 추출을 먼저 마쳐 주세요' : '이 레시피로 추출',
                ),
              ),
            ),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.isDemo
                          ? 'DEMO RECORD'
                          : recipe.recorded
                          ? 'BREW RECORD'
                          : 'POUR PLAN',
                      style: const TextStyle(
                        color: copper,
                        fontSize: 11,
                        letterSpacing: 1.8,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      recipe.name,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '${number(recipe.dose)}g  ·  1:${number(recipe.ratio)}  ·  목표 ${number(recipe.target)}g  ·  ${clockText(recipe.duration)}',
                      style: const TextStyle(color: muted),
                    ),
                    const SizedBox(height: 28),
                    const SectionLabel('추출 곡선'),
                    BrewChart(
                      points: recipe.recorded ? recipe.trace : const [],
                      reference: recipe.recorded ? null : recipe,
                      target: recipe.target,
                      seconds: recipe.duration,
                    ),
                    const SizedBox(height: 28),
                    SectionLabel('${recipe.steps.length}번의 붓기'),
                    if (recipe.recorded)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 14),
                        child: Text(
                          '붓기 단계는 실제 무게 변화에서 추정했어요. 재현 기준선에는 저장된 원본 그래프를 사용합니다.',
                          style: TextStyle(
                            color: muted,
                            fontSize: 12,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ...List.generate(recipe.steps.length, (index) {
                      final step = recipe.steps[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: mint,
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: ink,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${clockText(step.start)}–${clockText(step.end)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '추가 ${number(recipe.gramsFor(step))}g · ${number(recipe.gramsFor(step) / recipe.target * 100)}%',
                                    style: const TextStyle(
                                      color: muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '누적 ${number(recipe.cumulativeAt(index))}g',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder:
                                (_) => RecipeEditor(
                                  initial: recipe,
                                  dose: recipe.dose,
                                  ratio: recipe.ratio,
                                  onSave: controller.upsertRecipe,
                                ),
                          ),
                        );
                        if (context.mounted) Navigator.pop(context);
                      },
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: Text(
                        recipe.recorded ? '이 기록으로 수동 계획 만들기' : '레시피 편집',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
  );
}
