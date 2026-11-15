import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/durations.dart';
import '../../data/app_services.dart';
import '../../domain/planning.dart';
import '../../domain/recipe.dart';
import '../../domain/recipe_stats.dart';
import '../../l10n/app_localizations.dart';
import '../classification/labels_providers.dart';
import '../recipes/list/recipe_views.dart';
import '../recipes/recipe_providers.dart';

/// Tout le planning (pour compter les recettes planifiées).
final _allMealsProvider = FutureProvider.autoDispose<List<PlannedMeal>>(
  (ref) => ref.watch(planningRepositoryProvider).getAllMeals(),
);

/// Les statistiques : chiffres clés, puis des barres (une seule teinte) par
/// catégorie, saison, statut, les plus planifiées, les mieux notées et les
/// ingrédients les plus utilisés.
class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final recipes = ref.watch(recipeDetailsProvider).value;
    final labels = ref.watch(labelsProvider).value;
    final links = ref.watch(recipeLabelLinksProvider).value;
    final meals = ref.watch(_allMealsProvider).value;
    if (recipes == null || labels == null || links == null || meals == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.statsTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final stats = RecipeStats.compute(
      recipes: recipes,
      labels: labels,
      links: {for (final e in links.entries) e.key: e.value.keys},
      meals: meals,
      now: DateTime.now(),
    );
    String statusName(RecipeStatus? s) => switch (s) {
      RecipeStatus.toTest => l10n.statusToTest,
      RecipeStatus.toRetest => l10n.statusToRetest,
      RecipeStatus.toImprove => l10n.statusToImprove,
      RecipeStatus.validated => l10n.statusValidated,
      null => l10n.statusNone,
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.statsTitle)),
      body: stats.total == 0
          ? Center(child: Text(l10n.statsEmpty))
          : ListView(
              // Marge du bas : barre de navigation Android.
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                // Trois chiffres par ligne (plus sur tablette), tous de la même
                // taille.
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 600 ? 5 : 3;
                    final width =
                        (constraints.maxWidth - 8 * (columns - 1)) / columns;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Tile(
                          width: width,
                          key: const ValueKey('stats-total'),
                          value: '${stats.total}',
                          label: l10n.statsRecipes,
                        ),
                        _Tile(
                          width: width,
                          value: '${stats.favorites}',
                          label: l10n.homeFavorites,
                        ),
                        if (stats.averageMinutes case final m?)
                          _Tile(
                            width: width,
                            value: formatMinutes(l10n, m),
                            label: l10n.statsAverageTime,
                          ),
                        _Tile(
                          width: width,
                          key: const ValueKey('stats-planned'),
                          value: '${stats.plannedLast30}',
                          label: l10n.statsPlannedLast30,
                        ),
                        _Tile(
                          width: width,
                          value: '${stats.neverPlanned}',
                          label: l10n.statsNeverPlanned,
                        ),
                      ],
                    );
                  },
                ),
                if (stats.mostPlanned.isNotEmpty)
                  _Bars(
                    key: const ValueKey('stats-most-planned'),
                    title: l10n.statsMostPlanned,
                    rows: [
                      for (final e in stats.mostPlanned)
                        (
                          name: recipeTitle(l10n, e.recipe),
                          count: e.count,
                          onTap: () => openRecipe(context, e.recipe),
                        ),
                    ],
                  ),
                if (stats.categories.isNotEmpty)
                  _Bars(
                    key: const ValueKey('stats-categories'),
                    title: l10n.statsByCategory,
                    rows: [
                      for (final e in stats.categories)
                        (
                          name: e.name ?? l10n.statsNoCategory,
                          count: e.count,
                          onTap: null,
                        ),
                    ],
                  ),
                if (stats.seasons.isNotEmpty)
                  _Bars(
                    title: l10n.statsBySeason,
                    rows: [
                      for (final e in stats.seasons)
                        (
                          name: e.name ?? l10n.statsNoSeason,
                          count: e.count,
                          onTap: null,
                        ),
                    ],
                  ),
                _Bars(
                  title: l10n.statsByStatus,
                  rows: [
                    for (final e in stats.statuses)
                      (name: statusName(e.status), count: e.count, onTap: null),
                  ],
                ),
                if (stats.ingredients.isNotEmpty)
                  _Bars(
                    key: const ValueKey('stats-ingredients'),
                    title: l10n.statsIngredients,
                    unit: l10n.statsInRecipes,
                    rows: [
                      for (final e in stats.ingredients)
                        (name: e.name, count: e.count, onTap: null),
                    ],
                  ),
                if (stats.bestRated.isNotEmpty) ...[
                  _Title(l10n.statsBestRated),
                  for (final r in stats.bestRated)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(recipeTitle(l10n, r)),
                      trailing: Text(
                        '★' * (r.rating ?? 0),
                        semanticsLabel: l10n.statsRating(r.rating ?? 0),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      onTap: () => openRecipe(context, r),
                    ),
                ],
              ],
            ),
    );
  }
}

/// Un chiffre clé : la valeur en grand, ce qu'elle compte en dessous.
class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.width,
    required this.value,
    required this.label,
  });

  final double width;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      height: 112,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Le chiffre sur une ligne, réduit s'il le faut (« 1 h 30 »).
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: theme.textTheme.headlineSmall),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        text,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

/// Des barres horizontales, une seule teinte, la plus longue = le plus grand
/// nombre ; le nom à gauche, le nombre écrit à droite.
class _Bars extends StatelessWidget {
  const _Bars({super.key, required this.title, required this.rows, this.unit});

  final String title;
  final List<({String name, int count, VoidCallback? onTap})> rows;

  /// Ce que compte le nombre, écrit sous le titre (« dans N recettes »).
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final max = rows.fold(0, (m, r) => r.count > m ? r.count : m);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Title(title),
        if (unit != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              unit!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        for (final row in rows)
          InkWell(
            onTap: row.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      row.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 5,
                    child: LayoutBuilder(
                      builder: (context, constraints) => Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          height: 10,
                          width: max == 0
                              ? 0
                              : (constraints.maxWidth * row.count / max).clamp(
                                  4.0,
                                  constraints.maxWidth,
                                ),
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${row.count}',
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
