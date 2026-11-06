import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/domain/step_durations.dart';

List<int> minutes(String text) => [
  for (final d in StepDurations.find(text)) d.inSeconds ~/ 60,
];

void main() {
  test('minutes, sous toutes leurs formes', () {
    expect(minutes('Cuire 20 minutes à 180 °C.'), [20]);
    expect(minutes('Laisser reposer 10 min, puis enfourner 25 mn.'), [10, 25]);
    expect(minutes('Faire revenir 5min.'), [5]);
    expect(minutes('Cuire 1 minute de chaque côté'), [1]);
  });

  test('heures et minutes', () {
    expect(minutes('Mijoter 1 h 30 à feu doux.'), [90]);
    expect(minutes('Mijoter 1h30.'), [90]);
    expect(minutes('Laisser lever 2 heures.'), [120]);
    expect(minutes('Cuire 1 heure 15 min.'), [75]);
    expect(minutes('Réfrigérer 1,5 h.'), [90]);
    expect(minutes('Cuire 2 heures et demie'), [150]);
  });

  test('en toutes lettres', () {
    expect(minutes('Laisser reposer une demi-heure.'), [30]);
    expect(minutes('Cuire un quart d’heure.'), [15]);
    expect(minutes('Cuire une heure et demie.'), [90]);
    expect(minutes('Laisser mariner une heure au frais.'), [60]);
  });

  test('fourchette : la plus courte', () {
    expect(minutes('Cuire 10 à 15 minutes.'), [10]);
    expect(minutes('Cuire 8-10 min.'), [8]);
  });

  test('secondes', () {
    final found = StepDurations.find('Mixer 30 secondes, puis 45 s.');
    expect(found, [const Duration(seconds: 30), const Duration(seconds: 45)]);
  });

  test('pas de faux minuteur', () {
    expect(
      StepDurations.find('Ajouter 3 sachets de levure et 200 g de sucre.'),
      isEmpty,
    );
    expect(StepDurations.find('Préchauffer le four à 180 °C, th. 6.'), isEmpty);
    expect(StepDurations.find('Servir avec 2 c. à soupe de crème.'), isEmpty);
    expect(StepDurations.find('Couper en 4 morceaux.'), isEmpty);
  });

  test('une même durée n’apparaît qu’une fois', () {
    expect(minutes('Cuire 5 min, retourner, puis encore 5 min.'), [5]);
  });
}
