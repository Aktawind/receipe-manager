import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_app.dart';

void main() {
  testWidgets('affiche la barre du bas sur téléphone', (tester) async {
    usePhoneSize(tester);
    final app = await tester.runAsync(TestApp.create);
    await app!.pump(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Aucune recette pour l\'instant'), findsOneWidget);
  });

  testWidgets('affiche le rail latéral sur tablette', (tester) async {
    tester.view.physicalSize = const Size(2560, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final app = await tester.runAsync(TestApp.create);
    await app!.pump(tester);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('le choix du thème est enregistré', (tester) async {
    usePhoneSize(tester);
    final app = (await tester.runAsync(TestApp.create))!;
    await app.pump(tester);

    await tester.tap(find.text('Réglages').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Automatique'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sombre').last);
    await tester.pumpAndSettle();

    final material = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(material.themeMode, ThemeMode.dark);
    expect(app.prefs.getString('theme_mode'), 'dark');
  });

  testWidgets('le thème enregistré est relu au démarrage', (tester) async {
    final app = await tester.runAsync(
      () => TestApp.create(prefs: {'theme_mode': 'light'}),
    );
    await app!.pump(tester);

    final material = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(material.themeMode, ThemeMode.light);
  });

  testWidgets('l\'onglet sélectionné reste lisible en thème sombre', (
    tester,
  ) async {
    usePhoneSize(tester);
    final app = await tester.runAsync(
      () => TestApp.create(prefs: {'theme_mode': 'dark'}),
    );
    await app!.pump(tester);

    final context = tester.element(find.byType(NavigationBar));
    final theme = Theme.of(context);
    final iconTheme = theme.navigationBarTheme.iconTheme!.resolve({
      WidgetState.selected,
    })!;
    expect(iconTheme.color, theme.colorScheme.onTertiaryContainer);
  });
}
