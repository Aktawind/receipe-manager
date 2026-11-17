import 'dart:math';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/data/database.dart';
import 'package:recettes/data/planning_repository.dart';
import 'package:recettes/data/recipe_repository.dart';
import 'package:recettes/domain/ingredient_text.dart';
import 'package:recettes/domain/meal_planner.dart';
import 'package:recettes/domain/planning.dart';
import 'package:recettes/domain/recipe.dart';
import 'package:recettes/domain/recipe_search.dart';
import 'package:recettes/domain/recipe_stats.dart';
import 'package:recettes/domain/step_text.dart';

/// Une grosse bibliothèque (500 recettes, plus que ce que tu auras) : ce que
/// l'app fait le plus souvent reste rapide. Les limites sont larges (machine
/// de CI plus lente qu'un téléphone récent sur ces calculs simples).
void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  test(
    '500 recettes : lire, chercher, filtrer, statistiques, planifier',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = RecipeRepository(db);
      final planning = PlanningRepository(db);
      const words = [
        'poulet',
        'courgette',
        'tomate',
        'riz',
        'crème',
        'citron',
        'farine',
        'beurre',
        'oignon',
        'ail',
        'lardons',
        'chocolat',
      ];
      final random = Random(1);
      final created = <Recipe>[];
      await db.transaction(() async {
        for (var i = 0; i < 500; i++) {
          final r = await repo.create();
          final pick = [
            for (var k = 0; k < 8; k++) words[random.nextInt(words.length)],
          ];
          final recipe = r.copyWith(
            title: 'Recette $i ${pick.first}',
            servings: () => 4,
            prepMinutes: () => 10 + i % 60,
            ingredients: IngredientText.parseList(
              [for (final w in pick) '${random.nextInt(300) + 1} g de $w']
                  .join('\n'),
            ),
            steps: StepText.parse(
              List.filled(
                6,
                'Mélanger et cuire doucement pendant 10 minutes.',
              ).join('\n\n'),
            ),
          );
          await repo.save(recipe);
          created.add(recipe);
          if (i % 3 == 0) {
            await planning.add(
              day: DateTime(2026, 11, 1 + i % 28),
              slotId: DefaultMealSlots.idFor('Dîner'),
              recipeId: r.id,
              recipeTitle: recipe.title,
            );
          }
        }
      });

      Future<T> timed<T>(
        String what,
        int maxMs,
        Future<T> Function() run,
      ) async {
        final watch = Stopwatch()..start();
        final result = await run();
        watch.stop();
        expect(
          watch.elapsedMilliseconds,
          lessThan(maxMs),
          reason: '$what : ${watch.elapsedMilliseconds} ms',
        );
        return result;
      }

      final list = await timed('liste', 1500, () => repo.watchRecipes().first);
      expect(list, hasLength(500));
      final all = await timed('détails', 4000, repo.getAllWithDetails);
      final index = await timed(
        'index',
        1500,
        () async => RecipeSearchIndex(all),
      );
      final hits = await timed(
        'recherche',
        300,
        () async => index.search('poulet citron'),
      );
      expect(hits, isNotEmpty);
      final meals = await planning.getAllMeals();
      final stats = await timed(
        'statistiques',
        500,
        () async => RecipeStats.compute(
          recipes: all,
          labels: const [],
          links: const {},
          meals: meals,
          now: DateTime(2026, 11, 29),
        ),
      );
      expect(stats.total, 500);
      expect(stats.ingredients, isNotEmpty);
      final slots = [
        for (var w = 0; w < 4; w++)
          for (var d = 1; d <= 7; d++)
            PlannerSlot(weekday: d, slotId: DefaultMealSlots.idFor('Dîner')),
      ];
      final picks = await timed(
        'planificateur (4 semaines)',
        500,
        () async => MealPlanner.propose(
          all,
          slots,
          season: Season.autumn,
          useUp: const ['courgette', 'crème'],
          random: Random(2),
        ),
      );
      expect(picks.whereType<Recipe>(), hasLength(slots.length));
      await db.close();
    },
  );
}
