import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/data/database.dart';
import 'package:recettes/data/shopping_repository.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late ShoppingRepository shopping;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    shopping = ShoppingRepository(db);
  });
  tearDown(() => db.close());

  test('réordonner les rayons, retenir le rayon d’un produit', () async {
    final aisles = await shopping.watchAisles().first;
    await shopping.reorderAisles([...aisles.reversed]);
    final reordered = await shopping.watchAisles().first;
    expect(reordered.first.name, 'Autres');
    expect(reordered.last.name, 'Fruits et légumes');

    await shopping.rememberAisle('Sauces soja', reordered[3].id);
    final memory = await shopping.watchProductAisles().first;
    expect(memory, {'sauce soja': reordered[3].id});

    final bio = await shopping.createAisle('Bio');
    expect(bio.position, aisles.length);
    await shopping.deleteAisle(bio);
    expect(
      (await shopping.watchAisles().first).map((a) => a.name),
      isNot(contains('Bio')),
    );
  });
}
