import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/domain/recipe.dart';
import 'package:recettes/domain/step_text.dart';

void main() {
  List<String> texts(List<RecipeStep> steps) =>
      steps.map((s) => s.text).toList();

  test('une étape par ligne quand il n’y a pas de numéros', () {
    final steps = StepText.parse('''
Préchauffer le four à 180 °C.
Mélanger la farine et les œufs.

Cuire 30 minutes.
''');
    expect(texts(steps), [
      'Préchauffer le four à 180 °C.',
      'Mélanger la farine et les œufs.',
      'Cuire 30 minutes.',
    ]);
  });

  test('numéros : « 1. », « 2) », « Étape 3 : »', () {
    final steps = StepText.parse('''
1. Préchauffer le four.
2) Mélanger les ingrédients.
Étape 3 : Cuire 20 minutes.
''');
    expect(texts(steps), [
      'Préchauffer le four.',
      'Mélanger les ingrédients.',
      'Cuire 20 minutes.',
    ]);
  });

  test('avec des numéros, les lignes suivantes prolongent l’étape', () {
    final steps = StepText.parse('''
1. Mélanger la farine avec
le sucre et le sel.
2. Ajouter les œufs.
''');
    expect(texts(steps), [
      'Mélanger la farine avec le sucre et le sel.',
      'Ajouter les œufs.',
    ]);
  });

  test('« Étape 1 » seul sur sa ligne : le texte est sur la suivante', () {
    final steps = StepText.parse('Étape 1\nMélanger.\nÉtape 2\nCuire.');
    expect(texts(steps), ['Mélanger.', 'Cuire.']);
  });

  test('une température en début de ligne n’est pas un numéro d’étape', () {
    final steps = StepText.parse(
      '180 °C pendant 20 minutes.\nLaisser refroidir.',
    );
    expect(texts(steps), ['180 °C pendant 20 minutes.', 'Laisser refroidir.']);
  });

  test('titres de parties', () {
    final steps = StepText.parse('''
Biscuit :
Monter les blancs en neige.
Incorporer la poudre de noisettes.

**Insert**
Préparer un caramel à sec.

MONTAGE
Couler la mousse dans le cercle.
''');
    // Le titre n'est porté que par la première étape de la partie.
    expect(steps.map((s) => s.title), ['Biscuit', '', 'Insert', 'Montage']);
    expect(texts(steps), [
      'Monter les blancs en neige.',
      'Incorporer la poudre de noisettes.',
      'Préparer un caramel à sec.',
      'Couler la mousse dans le cercle.',
    ]);
  });

  test('un titre ne vaut que pour l’étape qui le suit', () {
    final steps = StepText.parse('Biscuit :\nÉtape A.\nÉtape B.');
    expect(steps.map((s) => s.title), ['Biscuit', '']);
  });

  test('puces et gras markdown', () {
    final steps = StepText.parse('- Mélanger.\n* Cuire.\n• Servir.');
    expect(texts(steps), ['Mélanger.', 'Cuire.', 'Servir.']);
  });

  test('texte vide ou sans lettres', () {
    expect(StepText.parse(''), isEmpty);
    expect(StepText.parse('\n  \n---\n'), isEmpty);
  });

  test('aller-retour édition', () {
    const steps = [
      RecipeStep(id: 'a', title: 'Biscuit', text: 'Monter les blancs.'),
      RecipeStep(id: 'b', text: 'Ajouter la poudre.'),
      RecipeStep(id: 'c', text: 'Cuire 25 minutes à 160 °C.'),
    ];
    final back = StepText.parse(
      StepText.format(steps),
      previousIds: ['a', 'b', 'c'],
    );
    expect(back.map((s) => s.text), steps.map((s) => s.text));
    expect(back.map((s) => s.id), ['a', 'b', 'c']);
    expect(back[0].title, 'Biscuit');
    expect(back[2].title, '');
  });

  test('une étape sur plusieurs lignes devient une étape d’une ligne', () {
    const steps = [RecipeStep(id: 'a', text: 'Mélanger.\nPuis cuire.')];
    expect(StepText.format(steps), 'Mélanger. Puis cuire.');
  });
}
