import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/data/recipe_repository.dart';
import 'package:recettes/domain/recipe.dart';
import 'package:recettes/features/recipes/cooking_timers.dart';

import '../helpers/test_app.dart';

class FakeAlarms implements TimerAlarmScheduler {
  final scheduled = <int, DateTime>{};
  final calls = <String>[];

  @override
  Future<void> requestPermission() async => calls.add('permission');

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String channelName,
  }) async {
    calls.add('schedule $title | $body');
    scheduled[id] = at;
  }

  @override
  Future<void> cancel(int id) async {
    calls.add('cancel');
    scheduled.remove(id);
  }
}

void main() {
  testWidgets('minuteurs : lancés depuis une étape, pause, arrêt', (
    tester,
  ) async {
    usePhoneSize(tester);
    final alarms = FakeAlarms();
    final app = (await tester.runAsync(
      () => TestApp.create(
        overrides: [timerAlarmSchedulerProvider.overrideWithValue(alarms)],
      ),
    ))!;
    await tester.runAsync(() async {
      final repo = app.services.recipes;
      final created = await repo.create();
      await repo.save(
        created.copyWith(
          title: 'Crêpes',
          steps: [
            RecipeStep(
              id: RecipeRepository.newId(),
              text: 'Laisser reposer la pâte 1 h.',
            ),
            RecipeStep(
              id: RecipeRepository.newId(),
              text: 'Cuire 2 minutes de chaque côté.',
            ),
          ],
        ),
      );
    });
    await app.pump(tester);
    await tester.tap(find.text('Crêpes'));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('cooking-open')));
    await settle(tester);
    await tester.tap(find.text('Préparation'));
    await settle(tester);

    // Les durées des étapes deviennent des boutons.
    expect(find.byKey(const ValueKey('timer-step-1-3600')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('timer-step-2-120')));
    await tester.pump();
    expect(alarms.calls, [
      'permission',
      'schedule Minuteur terminé | Crêpes · étape 2',
    ]);
    expect(find.text('2:00'), findsOneWidget);

    await tester.pump(const Duration(seconds: 30));
    expect(find.text('1:30'), findsOneWidget);

    // Pause : l'alarme est annulée, le temps ne bouge plus.
    final id = alarms.scheduled.keys.single;
    await tester.tap(find.byKey(ValueKey('timer-pause-$id')));
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('1:30'), findsOneWidget);
    expect(alarms.scheduled, isEmpty);

    // Reprise, puis la fin : « Terminé ! ».
    await tester.tap(find.byKey(ValueKey('timer-pause-$id')));
    await tester.pump();
    expect(alarms.scheduled, hasLength(1));
    await tester.pump(const Duration(seconds: 91));
    expect(find.text('Terminé !'), findsOneWidget);

    // Arrêter : retiré, sonnerie coupée.
    await tester.tap(find.byKey(ValueKey('timer-stop-$id')));
    await tester.pump();
    expect(find.text('Terminé !'), findsNothing);
    expect(alarms.calls.last, 'cancel');
  });

  testWidgets('minuteur libre et plusieurs à la fois', (tester) async {
    usePhoneSize(tester);
    final alarms = FakeAlarms();
    final app = (await tester.runAsync(
      () => TestApp.create(
        overrides: [timerAlarmSchedulerProvider.overrideWithValue(alarms)],
      ),
    ))!;
    await tester.runAsync(() async {
      final repo = app.services.recipes;
      final created = await repo.create();
      await repo.save(created.copyWith(title: 'Crêpes'));
    });
    await app.pump(tester);
    await tester.tap(find.text('Crêpes'));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('cooking-open')));
    await settle(tester);

    await tester.tap(find.byKey(const ValueKey('timer-new')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('timer-quick-5')));
    await settle(tester);

    await tester.tap(find.byKey(const ValueKey('timer-new')));
    await settle(tester);
    await tester.enterText(find.byKey(const ValueKey('timer-minutes')), '12');
    await tester.tap(find.byKey(const ValueKey('timer-start')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Crêpes · 5 min'), findsOneWidget);
    expect(find.text('Crêpes · 12 min'), findsOneWidget);
    expect(alarms.scheduled, hasLength(2));

    // Une minute de plus : l'alarme est reprogrammée une minute plus tard.
    final id = alarms.scheduled.keys.first;
    final before = alarms.scheduled[id]!;
    await tester.tap(find.byKey(ValueKey('timer-plus-$id')));
    await tester.pump();
    expect(
      alarms.scheduled[id]!.difference(before).inSeconds,
      inInclusiveRange(59, 61),
    );
  });

  test('affichage des durées', () {
    expect(formatCountdown(const Duration(minutes: 4, seconds: 5)), '4:05');
    expect(
      formatCountdown(const Duration(hours: 1, minutes: 2, seconds: 30)),
      '1:02:30',
    );
  });
}
