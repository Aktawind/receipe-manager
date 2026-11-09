import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/domain/meal_planner.dart';
import 'package:recettes/domain/side_emoji.dart';

void main() {
  test('un emoji d’après le nom, sinon celui de la sorte', () {
    String of(String name, [SideKind kind = SideKind.vegetable]) =>
        SideEmoji.forName(name, kind);
    expect(of('Pommes de terre', SideKind.starch), '🥔');
    expect(of('Patate douce', SideKind.starch), '🍠');
    expect(of('Pâtes', SideKind.starch), '🍝');
    expect(of('Riz basmati', SideKind.starch), '🍚');
    expect(of('Bœuf haché', SideKind.protein), '🥩');
    expect(of('Œufs', SideKind.protein), '🥚');
    expect(of('Saumon', SideKind.protein), '🐟');
    expect(of('Carottes'), '🥕');
    expect(of('Chou-fleur'), '🥦');
    expect(of('Courgettes'), '🥒');
    // Inconnus : selon la sorte.
    expect(of('Quinoa', SideKind.starch), '🌾');
    expect(of('Tofu', SideKind.protein), '🍖');
    expect(of('Poireaux'), '🥬');
    // Tous les accompagnements fournis ont un emoji.
    for (final side in DefaultSideDishes.build(DateTime(2026))) {
      expect(SideEmoji.of(side), isNotEmpty);
    }
  });
}
