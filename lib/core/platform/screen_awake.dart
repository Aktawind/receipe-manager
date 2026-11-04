import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Garde l'écran allumé (mode cuisine). Sans effet là où le canal Android
/// n'existe pas (tests, autres plateformes) : ce n'est qu'un confort.
abstract final class ScreenAwake {
  static const _channel = MethodChannel('recettes/screen');

  static Future<void> keepOn(bool on) async {
    try {
      await _channel.invokeMethod<void>('keepOn', on);
    } on MissingPluginException {
      // Pas d'Android : rien à faire.
    } on PlatformException catch (error) {
      debugPrint('ScreenAwake: $error');
    }
  }
}
