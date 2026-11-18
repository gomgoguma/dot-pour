import 'package:flutter/material.dart';
import '../l10n/language.dart';
import '../brew_controller.dart';
import '../recipe.dart';
import 'brew_chart.dart';
import 'recipe_editor.dart';
import 'save_recipe_dialog.dart';
import 'style.dart';

class RecipeLibrary extends StatelessWidget {
  final BrewController controller;
  final VoidCallback? onRecipeLoaded;
  const RecipeLibrary({
    super.key,
    required this.controller,
    this.onRecipeLoaded,
  });
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
            automaticallyImplyLeading: onRecipeLoaded == null,
            title: Text(context.l10n.myRecipes),
            actions: [
              IconButton(
                tooltip: context.l10n.createManualRecipe,
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
                              Text(
                                context.l10n.noRecipes,
                                style: TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                context.l10n.noRecipesHint,
                                style: TextStyle(color: muted, height: 1.7),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              FilledButton.icon(
                                onPressed: () => _edit(context),
                                icon: const Icon(Icons.add),
                                label: Text(context.l10n.createRecipe),
                              ),
                            ],
                          ),
                        ),
                      )
                      : ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          Text(
                            context.l10n.recipesCount(
                              controller.recipes.length,
                            ),
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
                                      if (onRecipeLoaded != null) {
                                        onRecipeLoaded!();
                                      } else {
                                        Navigator.pop(context);
                                      }
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
                                                  ? context.l10n.demoRecord
                                                  : recipe.recorded
                                                  ? context.l10n.brewRecord
                                                  : context.l10n.manualPlan,
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
                                                context.l10n.recipeSummary(
                                                  number(recipe.dose),
                                                  number(recipe.ratio),
                                                  recipe.steps.length,
                                                  clockText(recipe.duration),
                                                ),
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
            title: Text(context.l10n.recipesTab),
            actions: [
              IconButton(
                tooltip: context.l10n.deleteRecipe,
                icon: const Icon(Icons.delete_outline, size: 21),
                onPressed:
                    controller.libraryBusy
                        ? null
                        : () async {
                          final yes = await showDialog<bool>(
                            context: context,
                            builder:
                                (context) => AlertDialog(
                                  title: Text(
                                    context.l10n.deleteRecipeQuestion,
                                  ),
                                  content: Text(recipe.name),
                                  actions: [
                                    TextButton(
                                      onPressed:
                                          () => Navigator.pop(context, false),
                                      child: Text(context.l10n.cancel),
                                    ),
                                    TextButton(
                                      onPressed:
                                          () => Navigator.pop(context, true),
                                      child: Text(context.l10n.delete),
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
                                  SnackBar(
                                    content: Text(context.l10n.deleteError(e)),
                                  ),
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
                  controller.brew.active
                      ? context.l10n.finishActiveBrew
                      : context.l10n.brewThisRecipe,
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
                      context.l10n.recipeDetails(
                        number(recipe.dose),
                        number(recipe.ratio),
                        number(recipe.target),
                        clockText(recipe.duration),
                      ),
                      style: const TextStyle(color: muted),
                    ),
                    const SizedBox(height: 28),
                    if (!recipe.notes.isEmpty) ...[
                      RecipeNotesCard(notes: recipe.notes),
                      const SizedBox(height: 24),
                    ],
                    SectionLabel(context.l10n.brewCurve),
                    BrewChart(
                      points: recipe.recorded ? recipe.trace : const [],
                      reference: recipe.recorded ? null : recipe,
                      target: recipe.target,
                      seconds: recipe.duration,
                    ),
                    const SizedBox(height: 28),
                    SectionLabel(context.l10n.pourCount(recipe.steps.length)),
                    if (recipe.recorded)
                      Padding(
                        padding: EdgeInsets.only(bottom: 14),
                        child: Text(
                          context.l10n.recordedPourHint,
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
                                    context.l10n.pourAmount(
                                      number(recipe.gramsFor(step)),
                                      number(
                                        recipe.gramsFor(step) /
                                            recipe.target *
                                            100,
                                      ),
                                    ),
                                    style: const TextStyle(
                                      color: muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              context.l10n.pourCumulative(
                                number(recipe.cumulativeAt(index)),
                              ),
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
                        recipe.recorded
                            ? context.l10n.manualPlanFromBrew
                            : context.l10n.editRecipe,
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
