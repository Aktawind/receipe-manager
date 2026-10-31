import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

/// L'identifiant client « Application Web » du projet Google Cloud « Recettes ».
/// Il n'a rien de secret (il identifie l'application, comme son nom) ; Android
/// reconnaît l'application elle-même par son package et l'empreinte de sa clé.
const googleServerClientId =
    '789682729143-mica8b35574sbvkbnm0erfsvp2vlkp1h.apps.googleusercontent.com';

/// Le seul droit demandé : les fichiers que l'application crée elle-même.
const driveFileScope = 'https://www.googleapis.com/auth/drive.file';

/// La connexion à Google, séparée pour pouvoir être remplacée dans les tests.
abstract class DriveAuth {
  /// Ouvre la connexion Google (fenêtres du système) et renvoie l'adresse du
  /// compte. Lève une exception si l'utilisateur annule ou si ça échoue.
  Future<String> signIn();

  /// Les en-têtes d'autorisation, sans rien afficher. `null` si la connexion
  /// est à refaire.
  Future<Map<String, String>?> headers();

  Future<void> signOut();
}

class GoogleDriveAuth implements DriveAuth {
  Future<void>? _initialized;

  Future<void> _init() => _initialized ??= GoogleSignIn.instance.initialize(
    serverClientId: googleServerClientId,
  );

  /// On ne demande que l'autorisation d'accéder au dossier : pas de
  /// « connexion » séparée (Credential Manager), seulement le sélecteur de
  /// compte et l'écran de consentement de Google. L'adresse du compte est lue
  /// ensuite dans Drive.
  @override
  Future<String> signIn() async {
    await _init();
    final authorization = await GoogleSignIn.instance.authorizationClient
        .authorizeScopes(const [driveFileScope]);
    final response = await http.get(
      Uri.https('www.googleapis.com', '/drive/v3/about', {
        'fields': 'user(emailAddress)',
      }),
      headers: {'Authorization': 'Bearer ${authorization.accessToken}'},
    );
    if (response.statusCode != 200) {
      throw StateError('Drive a répondu ${response.statusCode}');
    }
    final user = (jsonDecode(response.body) as Map)['user'] as Map?;
    return (user?['emailAddress'] as String?) ?? '';
  }

  @override
  Future<Map<String, String>?> headers() async {
    await _init();
    return GoogleSignIn.instance.authorizationClient.authorizationHeaders(
      const [driveFileScope],
    );
  }

  @override
  Future<void> signOut() async {
    await _init();
    await GoogleSignIn.instance.signOut();
  }
}
