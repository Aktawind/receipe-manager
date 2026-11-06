import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pourquoi la dictée s'est arrêtée.
enum SpeechStop {
  /// Arrêtée à la main (ou l'app a quitté l'écran).
  user,

  /// Pas de reconnaissance vocale sur l'appareil.
  unavailable,

  /// Le micro a été refusé.
  permission,

  /// Une autre erreur (réseau…).
  error,
}

/// La dictée continue : le micro reste ouvert, chaque phrase comprise arrive
/// dans `onResult`, jusqu'à [stop]. Reconnaissance vocale d'Android (canal
/// `recettes/speech`, `SpeechListener.kt`). Remplacée dans les tests.
abstract class SpeechInput {
  Future<void> start({
    required void Function(String text) onResult,
    void Function(String text)? onPartial,
    void Function()? onListening,
    required void Function(SpeechStop reason) onStop,
  });

  Future<void> stop();
}

class AndroidSpeechInput implements SpeechInput {
  AndroidSpeechInput();

  static const _channel = MethodChannel('recettes/speech');

  @override
  Future<void> start({
    required void Function(String text) onResult,
    void Function(String text)? onPartial,
    void Function()? onListening,
    required void Function(SpeechStop reason) onStop,
  }) async {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'listening':
          onListening?.call();
        case 'partial':
          if (call.arguments case final String text) onPartial?.call(text);
        case 'result':
          if (call.arguments case final String text) onResult(text);
        case 'stopped':
          final reason = call.arguments is String
              ? call.arguments as String
              : '';
          onStop(switch (reason) {
            'user' => SpeechStop.user,
            'unavailable' => SpeechStop.unavailable,
            'permission' => SpeechStop.permission,
            _ => SpeechStop.error,
          });
      }
    });
    try {
      await _channel.invokeMethod<void>('start');
    } on MissingPluginException {
      onStop(SpeechStop.unavailable);
    } on PlatformException catch (error) {
      debugPrint('SpeechInput: $error');
      onStop(SpeechStop.error);
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } on MissingPluginException {
      // Pas d'Android : rien à arrêter.
    } on PlatformException catch (error) {
      debugPrint('SpeechInput: $error');
    }
  }
}

final speechInputProvider = Provider<SpeechInput>(
  (ref) => AndroidSpeechInput(),
);
