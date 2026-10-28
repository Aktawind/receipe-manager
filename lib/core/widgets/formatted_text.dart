import 'package:flutter/material.dart';

import '../../domain/inline_format.dart';

/// Un texte dont `**gras**` et `*italique*` sont mis en forme.
class FormattedText extends StatelessWidget {
  const FormattedText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          for (final span in InlineFormat.parse(text))
            TextSpan(
              text: span.text,
              style: TextStyle(
                fontWeight: span.bold ? FontWeight.w800 : null,
                fontStyle: span.italic ? FontStyle.italic : null,
              ),
            ),
        ],
      ),
      style: style,
    );
  }
}
