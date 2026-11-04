import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Le texte partagé vers l'app depuis une autre (« Partager » → Recettes) :
/// en pratique l'adresse d'une page de recette.
abstract final class SharedText {
  static const _channel = MethodChannel('recettes/share');

  /// Le texte qui a ouvert l'app, une seule fois ; `null` sinon.
  static Future<String?> takeInitial() async {
    try {
      return await _channel.invokeMethod<String>('takeShared');
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      debugPrint('SharedText: $error');
      return null;
    }
  }

  /// Appelé pour chaque partage reçu pendant que l'app est ouverte.
  static void listen(void Function(String text) onShared) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'shared' && call.arguments is String) {
        onShared(call.arguments as String);
      }
    });
  }
}
