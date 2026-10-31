import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/routing/app_router.dart';
import 'core/settings/theme_mode_controller.dart';
import 'core/theme/app_theme.dart';
import 'features/sync/sync_providers.dart';
import 'l10n/app_localizations.dart';

class RecettesApp extends ConsumerStatefulWidget {
  const RecettesApp({super.key});

  @override
  ConsumerState<RecettesApp> createState() => _RecettesAppState();
}

class _RecettesAppState extends ConsumerState<RecettesApp>
    with WidgetsBindingObserver {
  late final GoRouter _router = buildRouter();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Démarre la synchronisation si elle est activée.
    ref.read(syncControllerProvider);
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
