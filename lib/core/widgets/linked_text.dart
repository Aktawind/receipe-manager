import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';

final _linkPattern = RegExp(
  r'(?:https?://|www\.)[^\s<>"]+',
  caseSensitive: false,
);

/// Les adresses web trouvées dans [text] (sans ponctuation finale).
List<Uri> findLinks(String text) {
  return [
    for (final match in _linkPattern.allMatches(text))
      ?_toUri(_trimTrailing(match.group(0)!)),
  ];
}

String _trimTrailing(String url) =>
    url.replaceFirst(RegExp(r'[.,;:!?)\]]+$'), '');

Uri? _toUri(String url) {
  final withScheme = url.toLowerCase().startsWith('www.')
      ? 'https://$url'
      : url;
  final uri = Uri.tryParse(withScheme);
  return uri != null && uri.host.isNotEmpty ? uri : null;
}

/// Ouvre [uri] dans le navigateur ; affiche un message si c'est impossible.
Future<void> openLink(BuildContext context, Uri uri) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on Object {
    opened = false;
  }
  if (!opened) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.linkOpenFailed)));
  }
}

/// Un texte dont les adresses web sont cliquables.
class LinkedText extends StatefulWidget {
  const LinkedText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  State<LinkedText> createState() => _LinkedTextState();
}

class _LinkedTextState extends State<LinkedText> {
  final _recognizers = <TapGestureRecognizer>[];

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final theme = Theme.of(context);
    final base = widget.style ?? theme.textTheme.bodyLarge;
    final linkStyle = base?.copyWith(
      color: theme.colorScheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: theme.colorScheme.primary,
    );

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in _linkPattern.allMatches(widget.text)) {
      final raw = _trimTrailing(match.group(0)!);
      final uri = _toUri(raw);
      if (uri == null) continue;
      if (match.start > cursor) {
        spans.add(TextSpan(text: widget.text.substring(cursor, match.start)));
      }
      final recognizer = TapGestureRecognizer()
        ..onTap = () => openLink(context, uri);
      _recognizers.add(recognizer);
      spans.add(TextSpan(text: raw, style: linkStyle, recognizer: recognizer));
      cursor = match.start + raw.length;
    }
    if (cursor < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(cursor)));
    }
    return Text.rich(TextSpan(children: spans), style: base);
  }
}
