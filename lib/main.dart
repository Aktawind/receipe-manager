import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/logging/error_log.dart';
import 'core/settings/theme_mode_controller.dart';
import 'core/startup/startup_error_app.dart';
import 'data/app_services.dart';
import 'features/sync/sync_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final root = await getApplicationDocumentsDirectory();
    // Le journal des erreurs : tout ce qui échoue est noté sur l'appareil.
    ErrorLog.current = ErrorLog(File(p.join(root.path, ErrorLog.fileName)));
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      ErrorLog.current.add('Affichage', details.exception, details.stack);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      ErrorLog.current.add('Application', error, stack);
      return true;
    };
    final prefs = await SharedPreferences.getInstance().timeout(
      const Duration(seconds: 10),
    );
    final info = await PackageInfo.fromPlatform();
    final services = await AppServices.open(
      root: root,
      cache: await getTemporaryDirectory(),
      prefs: prefs,
      appVersion: info.version,
    );
    unawaited(services.purgeOldTrash());
    runApp(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appServicesProvider.overrideWithValue(services),
          syncFolderNameProvider.overrideWithValue(
            info.packageName.endsWith('.dev') ? 'Recettes (test)' : 'Recettes',
          ),
        ],
        child: const RecettesApp(),
      ),
    );
    _logAfterFirstFrame(startupOkMarker);
  } catch (error, stackTrace) {
    // Without this, a startup failure leaves the app stuck on the splash screen.
    ErrorLog.current.add('Démarrage', error, stackTrace);
    runApp(StartupErrorApp(error: error, stackTrace: stackTrace));
    _logAfterFirstFrame('$startupFailedMarker $error');
  }
}

/// Startup markers read from logcat by the CI smoke test (tools/smoke_test.sh).
const startupOkMarker = 'RECETTES_STARTUP_OK';
const startupFailedMarker = 'RECETTES_STARTUP_FAILED';

void _logAfterFirstFrame(String message) {
  WidgetsBinding.instance.addPostFrameCallback((_) => debugPrint(message));
}
