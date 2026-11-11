import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/data/database.dart';
import 'package:recettes/data/planning_repository.dart';

import 'generated_migrations/app/generated/schema.dart';
import 'generated_migrations/app/generated/schema_v12.dart' as v12;

/// Migration v12 → v13 : chaque créneau peut choisir ses types de plat ; les
/// créneaux existants (renommés, masqués) gardent tout et proposent tout.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('les créneaux sont intacts, sans type de plat', () async {
    final schema = await verifier.schemaAt(12);
    final oldDb = v12.DatabaseAtV12(schema.newConnection());
    await oldDb.batch((batch) {
      batch.insertAll(oldDb.mealSlots, const [
        v12.MealSlotsData(
          id: 'matin',
          name: 'Petit-déj du dimanche',
          position: 0,
          hidden: 0,
          createdAt: '2026-11-07T08:00:00.000Z',
          updatedAt: '2026-11-07T09:00:00.000Z',
        ),
        v12.MealSlotsData(
          id: 'gouter',
          name: 'Goûter',
          position: 1,
          hidden: 1,
          createdAt: '2026-11-07T08:00:00.000Z',
          updatedAt: '2026-11-07T08:00:00.000Z',
        ),
      ]);
    });
    await oldDb.close();

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 13);

    final planning = PlanningRepository(db);
    final slots = await planning.watchSlots().first;
    final matin = slots.firstWhere((s) => s.id == 'matin');
    expect(matin.name, 'Petit-déj du dimanche');
    expect(matin.categoryIds, isEmpty);
    expect(matin.updatedAt, DateTime.utc(2026, 11, 7, 9));
    expect(slots.firstWhere((s) => s.id == 'gouter').hidden, isTrue);

    await planning.updateSlot(
      matin.copyWith(categoryIds: {'petit-dejeuner', 'brunch'}),
    );
    final again = (await planning.watchSlots().first).firstWhere(
      (s) => s.id == 'matin',
    );
    expect(again.categoryIds, {'petit-dejeuner', 'brunch'});
    await db.close();
  });
}
