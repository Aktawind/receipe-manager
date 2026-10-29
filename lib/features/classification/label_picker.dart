import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_services.dart';
import '../../domain/label.dart';
import '../../l10n/app_localizations.dart';
import 'label_style.dart';
import 'labels_providers.dart';

/// Choix multiple dans une famille (catégories, étiquettes, saisons…). Renvoie
/// les identifiants cochés, ou `null` si on annule. On peut ajouter ce qui
/// n'existe pas encore.
Future<List<String>?> pickLabels(
  BuildContext context, {
  required LabelKind kind,
  required List<String> selected,
  bool allowCreate = true,
  Set<String>? visibleIds,
}) {
  return showDialog<List<String>>(
    context: context,
    builder: (context) => _LabelPickerDialog(
      kind: kind,
      selected: selected,
      allowCreate: allowCreate,
      visibleIds: visibleIds,
    ),
  );
}

class _LabelPickerDialog extends ConsumerStatefulWidget {
  const _LabelPickerDialog({
    required this.kind,
    required this.selected,
    required this.allowCreate,
    required this.visibleIds,
  });

  final LabelKind kind;
  final List<String> selected;

  /// Proposer d'ajouter ce qui n'existe pas (désactivé pour filtrer).
  final bool allowCreate;

  /// Si renseigné, seuls ces éléments sont proposés (filtrer : ceux qui servent).
  final Set<String>? visibleIds;

  @override
  ConsumerState<_LabelPickerDialog> createState() => _LabelPickerDialogState();
}

class _LabelPickerDialogState extends ConsumerState<_LabelPickerDialog> {
  late final List<String> _selected = [...widget.selected];
  var _query = '';

  void _toggle(String id, bool on) {
    setState(() {
      if (on) {
        if (!_selected.contains(id)) _selected.add(id);
      } else {
        _selected.remove(id);
      }
    });
  }

  Future<void> _create(String name) async {
    final label = await ref
        .read(labelRepositoryProvider)
        .findOrCreate(widget.kind, name);
    if (!mounted) return;
    setState(() {
      _query = '';
      if (!_selected.contains(label.id)) _selected.add(label.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final all = (ref.watch(labelsProvider).value ?? const <Label>[])
        .where(
          (l) =>
              l.kind == widget.kind &&
              (widget.visibleIds?.contains(l.id) ?? true),
        )
        .toList();
    final key = Label.keyOf(_query);

    // Un parent est montré s'il correspond à la recherche ou si l'un de ses
    // enfants y correspond.
    bool matches(Label l) => key.isEmpty || Label.keyOf(l.name).contains(key);
    final rows = <(Label, int)>[];
    for (final top in all.where((l) => l.parentId == null)) {
      final children = all.where((l) => l.parentId == top.id).toList();
      final shownChildren = children.where(matches).toList();
      if (matches(top) || shownChildren.isNotEmpty) {
        rows.add((top, 0));
        for (final child
            in (matches(top) && key.isEmpty ? children : shownChildren)) {
          rows.add((child, 1));
        }
      }
    }
    final canCreate =
        widget.allowCreate &&
        key.isNotEmpty &&
        !all.any((l) => l.parentId == null && Label.keyOf(l.name) == key);

    return AlertDialog(
      title: Text(widget.kind.title(l10n)),
      content: SizedBox(
        width: 400,
        height: 440,
        child: Column(
          children: [
            TextField(
              key: const ValueKey('label-search'),
              decoration: InputDecoration(
                hintText: widget.allowCreate
                    ? l10n.searchOrAddLabel
                    : l10n.search,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  if (canCreate)
                    ListTile(
                      leading: const Icon(Icons.add),
                      title: Text(l10n.addEquipmentNamed(_query.trim())),
                      onTap: () => _create(_query),
                    ),
                  if (rows.isEmpty && !canCreate)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(child: Text(l10n.classificationEmpty)),
                    ),
                  for (final (label, depth) in rows)
                    Padding(
                      padding: EdgeInsets.only(left: depth * 28.0),
                      child: CheckboxListTile(
                        value: _selected.contains(label.id),
                        controlAffinity: ListTileControlAffinity.leading,
                        secondary: label.icon.isEmpty
                            ? null
                            : Icon(
                                labelIconData(label.icon, widget.kind.icon),
                                color: labelColor(scheme, label.color),
                              ),
                        title: Text(
                          label.name,
                          style: depth == 0
                              ? const TextStyle(fontWeight: FontWeight.w600)
                              : null,
                        ),
                        onChanged: (on) => _toggle(label.id, on ?? false),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: Text(l10n.validate),
        ),
      ],
    );
  }
}
