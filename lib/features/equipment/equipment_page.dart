import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_services.dart';
import '../../domain/equipment.dart';
import '../../l10n/app_localizations.dart';
import 'equipment_providers.dart';

/// Réglages → Matériel : la liste commune à toutes les recettes. Les recettes
/// n'y font que cocher, ce qui garantit un seul nom par matériel.
class EquipmentPage extends ConsumerWidget {
  const EquipmentPage({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final name = await _askName(context, title: null, initial: '');
    if (name == null || name.trim().isEmpty) return;
    await ref.read(equipmentRepositoryProvider).findOrCreate(name);
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    EquipmentItem item,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final name = await _askName(
      context,
      title: l10n.renameEquipment,
      initial: item.name,
    );
    if (name == null || name.trim().isEmpty || name.trim() == item.name) return;
    final done = await ref
        .read(equipmentRepositoryProvider)
        .rename(item.id, name);
    if (!done) {
      messenger.showSnackBar(
        SnackBar(persist: false, content: Text(l10n.equipmentExists)),
      );
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    EquipmentItem item,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.deleteEquipmentConfirm(item.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(equipmentRepositoryProvider).delete(item.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final items = ref.watch(equipmentProvider).value ?? const [];
    final usage = ref.watch(equipmentUsageProvider).value ?? const {};

    return Scaffold(
      appBar: AppBar(title: Text(l10n.equipmentTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.addEquipment),
      ),
      body: items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.kitchen_outlined,
                      size: 72,
                      color: theme.colorScheme.secondary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.equipmentEmpty,
                      style: theme.textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(l10n.equipmentEmptyHint, textAlign: TextAlign.center),
                  ],
                ),
              ),
            )
          : ListView.builder(
              // Marge du bas : bouton flottant et barre de navigation Android.
              padding: EdgeInsets.only(
                bottom: 96 + MediaQuery.paddingOf(context).bottom,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  leading: const Icon(Icons.kitchen_outlined),
                  title: Text(item.name),
                  subtitle: Text(l10n.equipmentUsed(usage[item.id] ?? 0)),
                  onTap: () => _rename(context, ref, item),
                  trailing: IconButton(
                    tooltip: l10n.delete,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(context, ref, item),
                  ),
                );
              },
            ),
    );
  }
}

Future<String?> _askName(
  BuildContext context, {
  required String? title,
  required String initial,
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      return AlertDialog(
        title: Text(title ?? l10n.addEquipment),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: l10n.equipmentName),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(l10n.validate),
          ),
        ],
      );
    },
  ).whenComplete(controller.dispose);
}

/// Choix multiple du matériel d'une recette : on coche dans la liste commune,
/// ou on ajoute un matériel qui n'existe pas encore. Renvoie les identifiants
/// cochés, ou `null` si on annule.
Future<List<String>?> pickEquipment(
  BuildContext context, {
  required List<String> selected,
}) {
  return showDialog<List<String>>(
    context: context,
    builder: (context) => _EquipmentPickerDialog(selected: selected),
  );
}

class _EquipmentPickerDialog extends ConsumerStatefulWidget {
  const _EquipmentPickerDialog({required this.selected});

  final List<String> selected;

  @override
  ConsumerState<_EquipmentPickerDialog> createState() =>
      _EquipmentPickerDialogState();
}

class _EquipmentPickerDialogState
    extends ConsumerState<_EquipmentPickerDialog> {
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
    final item = await ref.read(equipmentRepositoryProvider).findOrCreate(name);
    if (!mounted) return;
    setState(() {
      _query = '';
      if (!_selected.contains(item.id)) _selected.add(item.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final all = ref.watch(equipmentProvider).value ?? const <EquipmentItem>[];
    final key = EquipmentItem.keyOf(_query);
    final shown = [
      for (final item in all)
        if (key.isEmpty || EquipmentItem.keyOf(item.name).contains(key)) item,
    ];
    final canCreate =
        key.isNotEmpty && !all.any((e) => EquipmentItem.keyOf(e.name) == key);

    return AlertDialog(
      title: Text(l10n.chooseEquipment),
      content: SizedBox(
        width: 400,
        height: 440,
        child: Column(
          children: [
            TextField(
              key: const ValueKey('equipment-search'),
              decoration: InputDecoration(
                hintText: l10n.searchOrAddEquipment,
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
                  for (final item in shown)
                    CheckboxListTile(
                      value: _selected.contains(item.id),
                      title: Text(item.name),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (on) => _toggle(item.id, on ?? false),
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
