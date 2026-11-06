import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/name_dialog.dart';
import '../../data/app_services.dart';
import '../../domain/shopping.dart';
import '../../l10n/app_localizations.dart';
import 'shopping_providers.dart';

/// Réglages → Rayons : ajouter, renommer, réordonner (ordre du parcours dans
/// le magasin) et supprimer les rayons des listes de courses.
class AislesPage extends ConsumerWidget {
  const AislesPage({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final name = await askName(
      context,
      title: l10n.addAisle,
      label: l10n.aisleName,
    );
    if (name == null || name.trim().isEmpty) return;
    await ref.read(shoppingRepositoryProvider).createAisle(name);
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, Aisle aisle) async {
    final l10n = AppLocalizations.of(context);
    final name = await askName(
      context,
      title: l10n.renameAisle,
      initial: aisle.name,
      label: l10n.aisleName,
    );
    if (name == null || name.trim().isEmpty || name.trim() == aisle.name) {
      return;
    }
    await ref.read(shoppingRepositoryProvider).renameAisle(aisle, name);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Aisle aisle) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.deleteAisleConfirm(aisle.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const ValueKey('aisle-delete-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(shoppingRepositoryProvider).deleteAisle(aisle);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final aisles = ref.watch(aislesProvider).value ?? const <Aisle>[];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.aislesTitle)),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('aisle-add'),
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.addAisle),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(l10n.aislesHint),
          ),
          Expanded(
            child: ReorderableListView.builder(
              // Marge du bas : bouton flottant et barre de navigation Android.
              padding: EdgeInsets.only(
                bottom: 96 + MediaQuery.paddingOf(context).bottom,
              ),
              buildDefaultDragHandles: false,
              itemCount: aisles.length,
              onReorderItem: (from, to) {
                final ordered = [...aisles];
                ordered.insert(to, ordered.removeAt(from));
                ref.read(shoppingRepositoryProvider).reorderAisles(ordered);
              },
              itemBuilder: (context, index) {
                final aisle = aisles[index];
                return ListTile(
                  key: ValueKey(aisle.id),
                  dense: true,
                  leading: ReorderableDragStartListener(
                    index: index,
                    child: const Icon(Icons.drag_handle),
                  ),
                  title: Text(aisle.name),
                  onTap: () => _rename(context, ref, aisle),
                  trailing: IconButton(
                    key: ValueKey('aisle-delete-${aisle.id}'),
                    tooltip: l10n.delete,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(context, ref, aisle),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
