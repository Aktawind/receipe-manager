import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/data/recipe_repository.dart';
import 'package:recettes/domain/recipe.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('mode cuisine : écran allumé, ingrédients recalculés, étapes', (
    tester,
  ) async {
    usePhoneSize(tester);
    final calls = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('recettes/screen'),
      (call) async {
        calls.add(call.arguments);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('recettes/screen'),
        null,
      ),
    );

    final app = (await tester.runAsync(TestApp.create))!;
    await tester.runAsync(() async {
      final repo = app.services.recipes;
      final created = await repo.create();
      await repo.save(
        created.copyWith(
          title: 'Crêpes',
          servings: () => 4,
          ingredients: [
            IngredientLine(
              id: RecipeRepository.newId(),
              name: 'farine',
              quantity: 250,
              unit: 'g',
            ),
          ],
          steps: [
            RecipeStep(
              id: RecipeRepository.newId(),
              text: 'Mélanger la farine et le lait.',
            ),
          ],
        ),
      );
    });
    await app.pump(tester);
    await tester.tap(find.text('Crêpes'));
    await settle(tester);

    // 6 personnes sur la fiche : le mode cuisine reprend ces quantités.
    await tester.tap(find.byKey(const ValueKey('servings-more')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('servings-more')));
    await settle(tester);

    await tester.tap(find.byKey(const ValueKey('cooking-open')));
    await settle(tester);
    expect(calls, [true]);
    expect(find.text('6 pers.'), findsOneWidget);
    expect(find.text('375 g de farine'), findsOneWidget);

    await tester.tap(find.text('Préparation'));
    await settle(tester);
    expect(find.text('Mélanger la farine et le lait.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('cooking-close')));
    await settle(tester);
    expect(calls, [true, false]);
    expect(find.byKey(const ValueKey('cooking-open')), findsOneWidget);
  });

  testWidgets('taille du texte réglable', (tester) async {
    usePhoneSize(tester);
    final app = (await tester.runAsync(
      () => TestApp.create(prefs: {'cooking_text_size': 'large'}),
    ))!;
    await tester.runAsync(() async {
      final repo = app.services.recipes;
      final created = await repo.create();
      await repo.save(
        created.copyWith(
          title: 'Crêpes',
          ingredients: [
            IngredientLine(id: RecipeRepository.newId(), name: 'farine'),
          ],
        ),
      );
    });
    await app.pump(tester);
    await tester.tap(find.text('Crêpes'));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('cooking-open')));
    await settle(tester);
    final text = tester.widget<Text>(find.text('farine'));
    expect(text.style?.fontSize, 23);
  });
}
