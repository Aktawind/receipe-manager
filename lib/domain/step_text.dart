import 'package:uuid/uuid.dart';

import 'recipe.dart';

/// Conversion entre le texte de préparation (collé ou saisi en une fois) et
/// les [RecipeStep] structurées.
///
/// Règles de lecture :
/// - si des lignes sont numérotées (« 1. », « 2) », « Étape 3 »), chaque
///   numéro commence une étape, et les lignes qui suivent la prolongent ;
/// - sinon, chaque ligne est une étape ;
/// - une ligne qui finit par « : » (« Biscuit : »), un titre en gras ou en
///   « ## », ou un mot en MAJUSCULES est un titre de partie : il s'affiche
///   au-dessus de l'étape suivante.
abstract final class StepText {
  static final _numbered = RegExp(
    r'^(?:(?:étape|etape|step)\s*\d{1,2}\s*[:.)\-–—]?|\d{1,2}\s*[.)](?=\s|$))\s*(.*)$',
    caseSensitive: false,
  );
  static final _bullet = RegExp(r'^(?:[-*•–—·▪◦►▶]+)\s+');

  static List<RecipeStep> parse(
    String text, {
    List<String> previousIds = const [],
  }) {
    final lines = <String>[];
    for (final raw in text.split(RegExp(r'\r?\n'))) {
      final line = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(line)) {
        lines.add(line);
      }
    }
    final numberedMode = lines.any((l) => _numbered.hasMatch(l));

    final steps = <RecipeStep>[];
    String? currentTitle;
    final current = <String>[];
    String? currentStepTitle;

    String idFor(int index) =>
        index < previousIds.length ? previousIds[index] : const Uuid().v4();

    void flush() {
      if (current.isEmpty) return;
      steps.add(
        RecipeStep(
          id: idFor(steps.length),
          title: currentStepTitle ?? '',
          text: current.join(' ').trim(),
        ),
      );
      current.clear();
      currentStepTitle = null;
    }

    void start(String firstLine) {
      flush();
      currentStepTitle = currentTitle;
      currentTitle = null;
      if (firstLine.isNotEmpty) current.add(firstLine);
    }

    for (var line in lines) {
      final heading = _heading(line);
      if (heading != null) {
        flush();
        currentTitle = heading;
        continue;
      }
      final number = _numbered.firstMatch(line);
      if (number != null) {
        start(_stripBullet(number.group(1)!.trim()));
        continue;
      }
      line = _stripBullet(line);
      if (numberedMode && (current.isNotEmpty || currentStepTitle != null)) {
        current.add(line);
      } else {
        start(line);
        if (!numberedMode) flush();
      }
    }
    flush();
    return steps;
  }

  /// Texte d'édition : une étape par ligne, séparées par une ligne vide, avec
  /// son titre « Biscuit : » au-dessus quand elle en a un.
  static String format(List<RecipeStep> steps) {
    return steps
        .map((s) {
          final text = s.text.replaceAll(RegExp(r'\s*\n\s*'), ' ').trim();
          return s.title.trim().isEmpty ? text : '${s.title.trim()} :\n$text';
        })
        .join('\n\n');
  }

  static String _stripBullet(String line) => line.replaceFirst(_bullet, '');

  /// Le titre de partie contenu dans [line], ou `null` si ce n'est pas un titre.
  static String? _heading(String line) {
    if (_numbered.hasMatch(line)) return null;
    final hashes = RegExp(r'^#{1,6}\s+(.*)$').firstMatch(line);
    if (hashes != null) return _tidy(hashes.group(1)!);
    final bold = RegExp(r'^(?:\*\*|__)(.+?)(?:\*\*|__)\s*:?$').firstMatch(line);
    if (bold != null) return _tidy(bold.group(1)!);

    final words = line.split(' ').length;
    if (line.endsWith(':') && words <= 6 && line.length <= 50) {
      return _tidy(line);
    }
    final isCapitals =
        line == line.toUpperCase() &&
        RegExp(r'\p{L}', unicode: true).hasMatch(line) &&
        !RegExp(r'\d|[.!?]$').hasMatch(line) &&
        words <= 5 &&
        line.length <= 40;
    return isCapitals ? _tidy(line) : null;
  }

  /// « BISCUIT : » -> « Biscuit ».
  static String _tidy(String raw) {
    var title = raw.replaceAll('**', '').replaceAll('__', '');
    title = title.replaceFirst(RegExp(r'\s*:$'), '').trim();
    if (title == title.toUpperCase() && title.length > 1) {
      title = title[0] + title.substring(1).toLowerCase();
    }
    return title;
  }
}
