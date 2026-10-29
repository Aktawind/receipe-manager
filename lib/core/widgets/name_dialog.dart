import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Demande un nom (ajout ou renommage). Renvoie `null` si on annule.
Future<String?> askName(
  BuildContext context, {
  required String title,
  String initial = '',
  String? label,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) =>
        _NameDialog(title: title, initial: initial, label: label),
  );
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, required this.initial, this.label});

  final String title;
  final String initial;
  final String? label;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: widget.label ?? l10n.labelName),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(l10n.validate),
        ),
      ],
    );
  }
}
