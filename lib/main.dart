import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/settings/theme_mode_controller.dart';
import 'core/startup/startup_error_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final prefs = await SharedPreferences.getInstance().timeout(
      const Duration(seconds: 10),
    );
    runApp(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const RecettesApp(),
      ),
    );
  } catch (error, stackTrace) {
    // Without this, a startup failure leaves the app stuck on the splash screen.
    runApp(StartupErrorApp(error: error, stackTrace: stackTrace));
  }
}
