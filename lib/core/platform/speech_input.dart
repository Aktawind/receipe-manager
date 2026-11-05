import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// La dictée : l'écran de reconnaissance vocale d'Android (canal
/// `recettes/speech` de MainActivity). Remplacée dans les tests.
abstract class SpeechInput {
  /// Le texte compris ; `null` si on annule ou si rien n'a été compris.
  /// Lève [SpeechUnavailable] si l'appareil n'a pas de reconnaissance vocale.
  Future<String?> listen({String prompt = ''});
}

class SpeechUnavailable implements Exception {
  const SpeechUnavailable();
}

class AndroidSpeechInput implements SpeechInput {
  const AndroidSpeechInput();

  static const _channel = MethodChannel('recettes/speech');

  @override
  Future<String?> listen({String prompt = ''}) async {
    try {
      final text = await _channel.invokeMethod<String>('listen', {
        'prompt': prompt,
      });
      return text == null || text.trim().isEmpty ? null : text.trim();
    } on MissingPluginException {
      throw const SpeechUnavailable();
    } on PlatformException catch (error) {
      debugPrint('SpeechInput: $error');
      throw const SpeechUnavailable();
    }
  }
}

final speechInputProvider = Provider<SpeechInput>(
  (ref) => const AndroidSpeechInput(),
);
