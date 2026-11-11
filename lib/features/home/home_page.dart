import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/app_services.dart';
import '../../domain/home_picks.dart';
import '../../domain/planning.dart';
import '../../domain/recipe.dart';
import '../../l10n/app_localizations.dart';
import '../planning/planning_providers.dart';
import '../recipes/list/recipe_views.dart';
import '../recipes/recipe_photo.dart';
import '../recipes/recipe_providers.dart';
import 'home_layout.dart';

/// Le nom d'une rubrique de l'accueil.
String homeSectionName(AppLocalizations l10n, HomeSection section) =>
    switch (section) {
      HomeSection.today => l10n.homeToday,
      HomeSection.shortcuts => l10n.homeShortcuts,
      HomeSection.favorites => l10n.homeFavorites,
      HomeSection.recent => l10n.homeRecent,
      HomeSection.seasonal => l10n.homeSeasonal,
      HomeSection.toTest => l10n.homeToTest,
    };

/// L'accueil : les repas du jour d'abord, puis des raccourcis et des
/// recettes (favoris, consultées, de saison, à tester), dans l'ordre choisi.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final layout = ref.watch(homeLayoutProvider);
    final recipes = ref.watch(recipesProvider).value ?? const <Recipe>[];
    final links = ref.watch(recipeLabelLinksProvider).value ?? const {};
    final today = PlannedMeal.dayOf(DateTime.now());

    Widget? section(HomeSection s) => switch (s) {
      HomeSection.today => const _Today(),
      HomeSection.shortcuts => const _Shortcuts(),
      HomeSection.favorites => _RecipeRow(
        section: s,
        recipes: HomePicks.favorites(recipes),
        empty: l10n.homeFavoritesEmpty,
      ),
      HomeSection.recent => _RecipeRow(
        section: s,
        recipes: HomePicks.recent(recipes),
        empty: l10n.homeRecentEmpty,
      ),
      HomeSection.seasonal => _RecipeRow(
        section: s,
        recipes: HomePicks.seasonal(recipes, {
          for (final e in links.entries) e.key: e.value.keys,
        }, day: today),
        empty: l10n.homeSeasonalEmpty,
      ),
      HomeSection.toTest => _RecipeRow(
        section: s,
        recipes: HomePicks.toTest(recipes),
        empty: null,
      ),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navHome),
        actions: [
          IconButton(
            key: const ValueKey('home-customize'),
            tooltip: l10n.homeCustomize,
            icon: const Icon(Icons.tune),
            onPressed: () => context.push('/accueil/personnaliser'),
          ),
        ],
      ),
      body: ListView(
        // Marge du bas : barre de navigation Android.
        padding: EdgeInsets.only(
          bottom: 16 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          for (final e in layout)
            if (e.shown) ?section(e.section),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text, {this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// Les repas du jour, créneau par créneau.
class _Today extends ConsumerWidget {
  const _Today();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final today = PlannedMeal.dayOf(DateTime.now());
    final slots = ref.watch(mealSlotsProvider).value ?? const <MealSlot>[];
    final meals = [
      for (final m
          in ref.watch(weekMealsProvider(PlannedMeal.weekStart(today))).value ??
              const <PlannedMeal>[])
        if (m.day == today) m,
    ];
    final recipes = {
      for (final r in ref.watch(recipesProvider).value ?? const <Recipe>[])
        r.id: r,
    };
    final order = {for (final (i, s) in slots.indexed) s.id: i};
    final names = {for (final s in slots) s.id: s.name};
    meals.sort((a, b) {
      final bySlot = (order[a.slotId] ?? 99).compareTo(order[b.slotId] ?? 99);
      return bySlot != 0 ? bySlot : a.position.compareTo(b.position);
    });

    void openPlanning() {
      ref.read(plannedWeekProvider.notifier).show(today);
      ref.read(plannedDayProvider.notifier).show(today);
      context.go('/planning');
    }

    return Column(
      key: const ValueKey('home-today'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          '${l10n.homeToday} · ${DateFormat.MMMMEEEEd(locale).format(today)}',
          action: TextButton(
            key: const ValueKey('home-open-planning'),
            onPressed: openPlanning,
            child: Text(l10n.homeOpenPlanning),
          ),
        ),
        if (meals.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.homeNothingToday,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey('home-plan'),
                  onPressed: () => context.push('/planning/planificateur'),
                  icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                  label: Text(l10n.plannerOpen),
                ),
              ],
            ),
          )
        else
          for (final meal in meals)
            ListTile(
              key: ValueKey('home-meal-${meal.id}'),
              leading: SizedBox.square(
                dimension: 48,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: meal.isRecipe
                      ? RecipePhoto(
                          photo: recipes[meal.recipeId]?.mainPhoto,
                          decodeWidth: 144,
                          iconSize: 22,
                        )
                      : ColoredBox(
                          color: theme.colorScheme.secondaryContainer,
                          child: Icon(
                            Icons.sticky_note_2_outlined,
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                ),
              ),
              title: Text(
                meal.isRecipe
                    ? (meal.recipeTitle.trim().isEmpty
                          ? l10n.untitledRecipe
                          : meal.recipeTitle)
                    : meal.note,
              ),
              subtitle: Text(
                [
                  names[meal.slotId] ?? '',
                  if (meal.isLeftovers) l10n.leftovers,
                ].join(' · '),
              ),
              onTap: meal.isRecipe && recipes.containsKey(meal.recipeId)
                  ? () => context.push('/recettes/${meal.recipeId}')
                  : openPlanning,
            ),
      ],
    );
  }
}

/// Les fonctions fréquentes, d'un geste.
class _Shortcuts extends ConsumerWidget {
  const _Shortcuts();

  Future<void> _newRecipe(BuildContext context, WidgetRef ref) async {
    final recipe = await ref.read(recipeRepositoryProvider).create();
    if (!context.mounted) return;
    await context.push('/recettes/${recipe.id}/modifier?nouvelle=1');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    Widget shortcut(String key, IconData icon, String label, VoidCallback on) =>
        ActionChip(
          key: ValueKey('home-shortcut-$key'),
          avatar: Icon(icon, size: 18),
          label: Text(label),
          onPressed: on,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(l10n.homeShortcuts),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              shortcut(
                'new',
                Icons.add,
                l10n.newRecipe,
                () => _newRecipe(context, ref),
              ),
              shortcut(
                'import',
                Icons.download_outlined,
                l10n.homeImport,
                () => context.push('/recettes/importer'),
              ),
              shortcut(
                'planner',
                Icons.auto_awesome_outlined,
                l10n.plannerOpen,
                () => context.push('/planning/planificateur'),
              ),
              shortcut(
                'shopping',
                Icons.shopping_basket_outlined,
                l10n.homeShoppingLists,
                () => context.go('/courses'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Une rangée de recettes qui défile de côté (photo carrée, titre).
class _RecipeRow extends StatelessWidget {
  const _RecipeRow({
    required this.section,
    required this.recipes,
    required this.empty,
  });

  final HomeSection section;
  final List<Recipe> recipes;

  /// Le texte affiché quand il n'y a rien ; `null` = rubrique cachée.
  final String? empty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    if (recipes.isEmpty && empty == null) return const SizedBox.shrink();
    return Column(
      key: ValueKey('home-${section.name}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(homeSectionName(l10n, section)),
        if (recipes.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              empty!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          SizedBox(
            height: 168,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: recipes.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final recipe = recipes[i];
                return SizedBox(
                  width: 120,
                  child: InkWell(
                    key: ValueKey('home-${section.name}-${recipe.id}'),
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => openRecipe(context, recipe),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox.square(
                            dimension: 120,
                            child: RecipePhoto(
                              photo: recipe.mainPhoto,
                              decodeWidth: 360,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          recipeTitle(l10n, recipe),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
