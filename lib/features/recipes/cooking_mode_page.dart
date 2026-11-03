import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/screen_awake.dart';
import '../../core/widgets/formatted_text.dart';
import '../../domain/ingredient_scaling.dart';
import '../../domain/ingredient_text.dart';
import '../../domain/recipe.dart';
import '../../domain/step_durations.dart';
import '../../l10n/app_localizations.dart';
import 'cooking_timers.dart';
import 'recipe_providers.dart';
import 'recipe_scale.dart';

/// Largeur à partir de laquelle ingrédients et préparation sont côte à côte.
const _wideBreakpoint = 840.0;

/// Mode cuisine : l'écran reste allumé, ingrédients et préparation en grand,
/// pour les nombres de personnes choisis sur la fiche.
class CookingModePage extends ConsumerStatefulWidget {
  const CookingModePage({super.key, required this.recipeId});

  final String recipeId;

  @override
  ConsumerState<CookingModePage> createState() => _CookingModePageState();
}

class _CookingModePageState extends ConsumerState<CookingModePage> {
  @override
  void initState() {
    super.initState();
    ScreenAwake.keepOn(true);
  }

  @override
  void dispose() {
    ScreenAwake.keepOn(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final recipe = ref.watch(recipeProvider(widget.recipeId)).value;
    if (recipe == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final factor = ref.watch(recipeScaleProvider(recipe.id));
    final wanted = scaledServings(recipe, factor);
    final title = recipe.title.trim().isEmpty
        ? l10n.untitledRecipe
        : recipe.title.trim();
    final ingredients = _Ingredients(recipe: recipe, factor: factor);
    final steps = _Steps(recipe: recipe, title: title);
    final wide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;

    final appBar = AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, overflow: TextOverflow.ellipsis),
          if (wanted != null)
            Text(
              servingsText(l10n, recipe, wanted),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
        ],
      ),
      actions: [
        IconButton(
          key: const ValueKey('timer-new'),
          tooltip: l10n.timerNew,
          icon: const Icon(Icons.timer_outlined),
          onPressed: () async {
            final duration = await showCustomTimerDialog(context);
            if (duration == null || !context.mounted) return;
            startCookingTimer(
              ref,
              l10n,
              l10n.timerLabelCustom(title, formatTimerDuration(l10n, duration)),
              duration,
            );
          },
        ),
      ],
      leading: IconButton(
        key: const ValueKey('cooking-close'),
        icon: const Icon(Icons.close),
        tooltip: l10n.cookingClose,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      bottom: wide
          ? null
          : TabBar(
              tabs: [
                Tab(text: l10n.ingredients),
                Tab(text: l10n.fieldSteps),
              ],
            ),
    );

    if (wide) {
      return Scaffold(
        appBar: appBar,
        bottomNavigationBar: const CookingTimersPanel(),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: ingredients),
            const VerticalDivider(width: 1),
            Expanded(flex: 3, child: steps),
          ],
        ),
      );
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: appBar,
        bottomNavigationBar: const CookingTimersPanel(),
        body: TabBarView(children: [ingredients, steps]),
      ),
    );
  }
}

EdgeInsets _listPadding(BuildContext context) =>
    EdgeInsets.fromLTRB(24, 16, 24, 32 + MediaQuery.paddingOf(context).bottom);

/// Le texte du mode cuisine : nettement plus grand que sur la fiche.
TextStyle? _bigText(BuildContext context) =>
    Theme.of(context).textTheme.headlineSmall
        ?.copyWith(fontSize: 24, height: 1.4);

class _Ingredients extends StatelessWidget {
  const _Ingredients({required this.recipe, required this.factor});

  final Recipe recipe;
  final double factor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final style = _bigText(context);
    final muted = TextStyle(color: theme.colorScheme.onSurfaceVariant);
    final lines = recipe.ingredients.where((l) => !l.isBlank).toList();
    if (lines.isEmpty) {
      return Center(child: Text(l10n.cookingNoIngredients));
    }
    final scaled = IngredientScaling.scale(lines, factor);
    return ListView(
      key: const ValueKey('cooking-ingredients'),
      padding: _listPadding(context),
      children: [
        for (final (index, item) in scaled.indexed)
          if (item.line.isSection)
            Padding(
              padding: EdgeInsets.only(top: index == 0 ? 0 : 24, bottom: 8),
              child: Text(
                item.line.name,
                style: style?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text.rich(
                _ingredientSpan(item, muted, l10n),
                style: style,
              ),
            ),
      ],
    );
  }

  TextSpan _ingredientSpan(
    ScaledIngredient item,
    TextStyle muted,
    AppLocalizations l10n,
  ) {
    final line = item.line;
    final amount = IngredientText.formatAmount(item.scaledLine);
    final name = line.name.trim();
    final connector = line.unit.isNotEmpty && name.isNotEmpty
        ? IngredientText.partitive(name)
        : '';
    return TextSpan(
      children: [
        if (amount.isNotEmpty)
          TextSpan(
            text: '$amount ',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        if (amount.isNotEmpty) TextSpan(text: connector),
        TextSpan(text: name),
        if (line.note.isNotEmpty)
          TextSpan(text: ', ${line.note}', style: muted),
        if (line.optional)
          TextSpan(
            text: ' · ${l10n.optionalIngredient}',
            style: muted.copyWith(fontStyle: FontStyle.italic),
          ),
      ],
    );
  }
}

class _Steps extends ConsumerWidget {
  const _Steps({required this.recipe, required this.title});

  final Recipe recipe;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final style = _bigText(context);
    final steps = recipe.steps.where((s) => s.text.trim().isNotEmpty).toList();
    if (steps.isEmpty) return Center(child: Text(l10n.cookingNoSteps));
    return ListView(
      key: const ValueKey('cooking-steps'),
      padding: _listPadding(context),
      children: [
        for (final (index, step) in steps.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  child: Text(
                    '${index + 1}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (step.title.trim().isNotEmpty)
                        Text(
                          step.title.trim().toUpperCase(),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      FormattedText(step.text, style: style),
                      for (final durations in [StepDurations.find(step.text)])
                        if (durations.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final d in durations)
                                  ActionChip(
                                    key: ValueKey(
                                      'timer-step-${index + 1}-${d.inSeconds}',
                                    ),
                                    avatar: const Icon(Icons.timer_outlined),
                                    tooltip: l10n.timerLaunch(
                                      formatTimerDuration(l10n, d),
                                    ),
                                    label: Text(
                                      formatTimerDuration(l10n, d),
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    onPressed: () => startCookingTimer(
                                      ref,
                                      l10n,
                                      l10n.timerLabelStep(title, index + 1),
                                      d,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Lance un minuteur avec les textes de la notification.
void startCookingTimer(
  WidgetRef ref,
  AppLocalizations l10n,
  String label,
  Duration duration,
) {
  ref
      .read(cookingTimersProvider.notifier)
      .start(
        label,
        duration,
        alarmTitle: l10n.timerAlarmTitle,
        channelName: l10n.timerChannel,
      );
}
