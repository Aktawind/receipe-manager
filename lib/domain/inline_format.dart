/// Un morceau de texte avec sa mise en forme.
class FormattedSpan {
  const FormattedSpan(this.text, {this.bold = false, this.italic = false});

  final String text;
  final bool bold;
  final bool italic;

  @override
  bool operator ==(Object other) =>
      other is FormattedSpan &&
      other.text == text &&
      other.bold == bold &&
      other.italic == italic;

  @override
  int get hashCode => Object.hash(text, bold, italic);

  @override
  String toString() => 'FormattedSpan($text, bold: $bold, italic: $italic)';
}

/// Mise en forme du texte des étapes : `**gras**` et `*italique*`.
///
/// Un marqueur sans fermeture reste du texte (« 2 * 3 », « **oubli »), pour
/// qu'une faute de frappe ne fasse jamais disparaître un morceau de la
/// recette.
abstract final class InlineFormat {
  static final _token = RegExp(
    r'\*\*(?=\S)(.+?)(?<=\S)\*\*(?!\*)|\*(?=\S)([^*]+?)(?<=\S)\*',
  );

  static List<FormattedSpan> parse(String text) {
    final spans = <FormattedSpan>[];
    var position = 0;
    for (final match in _token.allMatches(text)) {
      if (match.start > position) {
        spans.add(FormattedSpan(text.substring(position, match.start)));
      }
      final bold = match.group(1);
      if (bold != null) {
        // Du gras peut contenir de l'italique : **très *fin* **.
        for (final inner in parse(bold)) {
          spans.add(
            FormattedSpan(inner.text, bold: true, italic: inner.italic),
          );
        }
      } else {
        spans.add(FormattedSpan(match.group(2)!, italic: true));
      }
      position = match.end;
    }
    if (position < text.length) {
      spans.add(FormattedSpan(text.substring(position)));
    }
    return spans;
  }

  /// Le texte sans ses marqueurs (recherche, accessibilité).
  static String plain(String text) => parse(text).map((s) => s.text).join();
}
