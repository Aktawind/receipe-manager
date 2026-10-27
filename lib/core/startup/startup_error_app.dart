import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

/// Écran affiché quand l'application ne parvient pas à démarrer, avec le
/// détail technique à copier dans un ticket.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.error, this.stackTrace});

  final Object error;
  final StackTrace? stackTrace;

  String get details => '$error\n\n${stackTrace ?? ''}'.trim();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          final theme = Theme.of(context);
          return Scaffold(
            appBar: AppBar(title: Text(l10n.startupErrorTitle)),
            body: ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                Text(
                  l10n.startupErrorMessage,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: details));
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(l10n.copied)));
                  },
                  icon: const Icon(Icons.copy),
                  label: Text(l10n.copyDetails),
                ),
                const SizedBox(height: 16),
                SelectableText(details, style: theme.textTheme.bodySmall),
              ],
            ),
          );
        },
      ),
    );
  }
}
