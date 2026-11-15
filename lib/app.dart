import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/platform/shared_text.dart';
import 'core/routing/app_router.dart';
import 'core/settings/theme_mode_controller.dart';
import 'core/theme/app_theme.dart';
import 'data/import/web_import.dart';
import 'features/sync/sync_providers.dart';
import 'l10n/app_localizations.dart';

class RecettesApp extends ConsumerStatefulWidget {
  const RecettesApp({super.key, this.initialLocation = '/accueil'});

  /// Le premier écran (l'accueil ; les tests partent des recettes).
  final String initialLocation;

  @override
  ConsumerState<RecettesApp> createState() => _RecettesAppState();
}

class _RecettesAppState extends ConsumerState<RecettesApp>
    with WidgetsBindingObserver {
  late final GoRouter _router = buildRouter(
    initialLocation: widget.initialLocation,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Démarre la synchronisation si elle est activée.
    ref.read(syncControllerProvider);
    // Une page partagée depuis le navigateur ouvre l'import.
    SharedText.listen(_openShared);
    SharedText.takeInitial().then((text) {
      if (text != null) _openShared(text);
    });
  }

  void _openShared(String text) {
    // Une recette entière (réponse d'une IA partagée) : import du texte.
    if (looksLikeRecipeText(text)) {
      _router.push('/recettes/importer', extra: text);
      return;
    }
    final url = findUrl(text);
    if (url == null) return;
    _router.push(
      Uri(
        path: '/recettes/importer',
        queryParameters: {'url': url.toString()},
      ).toString(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(syncControllerProvider.notifier).onResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: _router,
    );
  }
}
