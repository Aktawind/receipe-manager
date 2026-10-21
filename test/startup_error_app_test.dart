import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/core/startup/startup_error_app.dart';

void main() {
  testWidgets('affiche le détail de l\'erreur de démarrage', (tester) async {
    await tester.pumpWidget(
      StartupErrorApp(error: StateError('canal indisponible')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Démarrage impossible'), findsOneWidget);
    expect(find.textContaining('canal indisponible'), findsOneWidget);
    expect(find.byIcon(Icons.copy), findsOneWidget);
  });
}
