import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../domain/ingredient_text.dart';
import '../../domain/recipe.dart';
import '../../domain/step_text.dart';
import '../photo_store.dart';
import 'web_recipe.dart';

/// Pourquoi une page n'a pas pu être importée.
enum WebImportError {
  /// Adresse invalide (pas http ou https).
  invalidUrl,

  /// Pas de réseau, délai dépassé, site injoignable.
  network,

  /// Le site a répondu par une erreur (404, 403…).
  http,

  /// La page ne contient pas de recette lisible.
  noRecipe,
}

class WebImportException implements Exception {
  const WebImportException(this.error, [this.detail = '']);

  final WebImportError error;
  final String detail;

  @override
  String toString() => 'WebImportException($error, $detail)';
}

/// La première adresse web d'un texte partagé (« Regarde : https://… »).
Uri? findUrl(String text) {
  final match = RegExp(r'https?://[^\s<>"]+').firstMatch(text);
  if (match == null) return null;
  final raw = match.group(0)!.replaceFirst(RegExp(r'[).,;!?»]+$'), '');
  final uri = Uri.tryParse(raw);
  return uri != null && uri.host.isNotEmpty ? uri : null;
}

/// Plusieurs lignes et assez de texte : la recette elle-même, pas une simple
/// adresse.
bool looksLikeRecipeText(String text) =>
    '\n'.allMatches(text.trim()).length >= 3 && text.trim().length >= 80;

/// Télécharge une page de recette et la convertit en [Recipe].
class WebImporter {
  WebImporter({http.Client? client, this.timeout = const Duration(seconds: 20)})
    : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  // Certains sites refusent les clients sans navigateur connu.
  static const _headers = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/130.0 Mobile Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml',
    'Accept-Language': 'fr-FR,fr;q=0.9,en;q=0.5',
  };

  Future<WebRecipe> fetch(Uri url) async {
    if (url.scheme != 'http' && url.scheme != 'https') {
      throw const WebImportException(WebImportError.invalidUrl);
    }
    final http.Response response;
    try {
      response = await _client.get(url, headers: _headers).timeout(timeout);
    } on TimeoutException {
      throw const WebImportException(WebImportError.network, 'timeout');
    } on SocketException catch (e) {
      throw WebImportException(WebImportError.network, e.message);
    } on http.ClientException catch (e) {
      throw WebImportException(WebImportError.network, e.message);
    }
    if (response.statusCode >= 400) {
      throw WebImportException(WebImportError.http, '${response.statusCode}');
    }
    final recipe = WebRecipeParser.parse(_decode(response), url);
    if (recipe == null) {
      throw const WebImportException(WebImportError.noRecipe);
    }
    return recipe;
  }

  /// La page en texte : l'encodage annoncé par le site, sinon UTF-8.
  static String _decode(http.Response response) {
    final type = response.headers['content-type'] ?? '';
    if (RegExp(
      r'charset=(iso-8859-1|latin-?1|windows-1252)',
      caseSensitive: false,
    ).hasMatch(type)) {
      return latin1.decode(response.bodyBytes);
    }
    return utf8.decode(response.bodyBytes, allowMalformed: true);
  }

  /// La photo principale, enregistrée dans [photos] ; `null` si elle ne se
  /// télécharge pas (la recette est importée sans).
  Future<String?> downloadPhoto(Uri? url, PhotoStore photos) async {
    if (url == null) return null;
    try {
      final response = await _client
          .get(url, headers: {'User-Agent': _headers['User-Agent']!})
          .timeout(timeout);
      final type = response.headers['content-type'] ?? '';
      if (response.statusCode >= 400 ||
          response.bodyBytes.isEmpty ||
          (type.isNotEmpty && !type.startsWith('image/'))) {
        return null;
      }
      final extension = switch (type.split(';').first.trim()) {
        'image/png' => '.png',
        'image/webp' => '.webp',
        'image/gif' => '.gif',
        'image/jpeg' => '.jpg',
        _ => _extensionOf(url),
      };
      final name = '${const Uuid().v4()}$extension';
      await photos.write(name, response.bodyBytes);
      return name;
    } on Object {
      return null;
    }
  }

  static String _extensionOf(Uri url) {
    final ext = p.extension(url.path).toLowerCase();
    return const {'.jpg', '.jpeg', '.png', '.webp', '.gif'}.contains(ext)
        ? ext
        : '.jpg';
  }

  void close() => _client.close();
}

/// Les champs d'une [Recipe] remplis depuis une recette du web : la
/// recette [base] (créée par le dépôt) reçoit titre, ingrédients, étapes,
/// temps, portions et source.
Recipe applyWebRecipe(Recipe base, WebRecipe web, {String? photo}) {
  final notes = [if (web.notes.isNotEmpty) web.notes].join('\n\n');
  return base.copyWith(
    title: web.title,
    description: web.description,
    source: web.source?.toString() ?? '',
    notes: notes,
    servings: () => web.servings,
    servingsUnit: web.servingsUnit,
    prepMinutes: () => web.prepMinutes,
    cookMinutes: () => web.cookMinutes,
    restMinutes: () => web.restMinutes,
    mainPhoto: () => photo,
    ingredients: IngredientText.parseList(web.ingredients.join('\n')),
    steps: StepText.parse(web.steps.join('\n')),
  );
}
