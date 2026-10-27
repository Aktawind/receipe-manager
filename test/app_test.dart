import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/app.dart';
import 'package:recettes/core/settings/theme_mode_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPreferences> _prefs([Map<String, Object> values = const {}]) {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

Future<void> _pumpApp(WidgetTester tester, SharedPreferences prefs) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const RecettesApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('affiche la barre du bas sur téléphone', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpApp(tester, await _prefs());

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Aucune recette pour l\'instant'), findsOneWidget);
  });

  testWidgets('affiche le rail latéral sur tablette', (tester) async {
    tester.view.physicalSize = const Size(2560, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await _pumpApp(tester, await _prefs());

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('le choix du thème est enregistré', (tester) async {
    final prefs = await _prefs();
    await _pumpApp(tester, prefs);

    await tester.tap(find.text('Réglages').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Automatique'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sombre').last);
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(prefs.getString('theme_mode'), 'dark');
  });

  testWidgets('le thème enregistré est relu au démarrage', (tester) async {
    await _pumpApp(tester, await _prefs({'theme_mode': 'light'}));

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.light);
  });

  testWidgets('l\'onglet sélectionné reste lisible en thème sombre', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await _pumpApp(tester, await _prefs({'theme_mode': 'dark'}));

    final context = tester.element(find.byType(NavigationBar));
    final theme = Theme.of(context);
    final iconTheme = theme.navigationBarTheme.iconTheme!.resolve({
      WidgetState.selected,
    })!;
    expect(iconTheme.color, theme.colorScheme.onTertiaryContainer);
  });
}
