import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/settings/theme_mode_controller.dart';
import 'core/startup/startup_error_app.dart';
import 'data/app_services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final prefs = await SharedPreferences.getInstance().timeout(
      const Duration(seconds: 10),
    );
    final info = await PackageInfo.fromPlatform();
    final services = await AppServices.open(
      root: await getApplicationDocumentsDirectory(),
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
        ],
        child: const RecettesApp(),
      ),
    );
    _logAfterFirstFrame(startupOkMarker);
  } catch (error, stackTrace) {
    // Without this, a startup failure leaves the app stuck on the splash screen.
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
