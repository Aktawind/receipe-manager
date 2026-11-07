import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/name_dialog.dart';
import '../../data/app_services.dart';
import '../../domain/planning.dart';
import '../../l10n/app_localizations.dart';
import 'planning_providers.dart';

/// Réglages → Créneaux : les créneaux de repas du planning (ajouter,
/// renommer, réordonner, afficher ou masquer, supprimer).
class MealSlotsPage extends ConsumerWidget {
  const MealSlotsPage({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final name = await askName(
      context,
      title: l10n.addMealSlot,
      label: l10n.mealSlotName,
    );
    if (name == null || name.trim().isEmpty) return;
    await ref.read(planningRepositoryProvider).createSlot(name);
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    MealSlot slot,
  ) async {
    final l10n = AppLocalizations.of(context);
    final name = await askName(
      context,
      title: l10n.renameMealSlot,
      initial: slot.name,
      label: l10n.mealSlotName,
    );
    if (name == null || name.trim().isEmpty || name.trim() == slot.name) return;
    await ref
        .read(planningRepositoryProvider)
        .updateSlot(slot.copyWith(name: name.trim()));
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    MealSlot slot,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.deleteMealSlotConfirm(slot.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const ValueKey('slot-delete-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(planningRepositoryProvider).deleteSlot(slot);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final slots = ref.watch(mealSlotsProvider).value ?? const <MealSlot>[];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.mealSlotsTitle)),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('slot-add'),
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.addMealSlot),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(l10n.mealSlotsHint),
          ),
          Expanded(
            child: ReorderableListView.builder(
              // Marge du bas : bouton flottant et barre de navigation Android.
              padding: EdgeInsets.only(
                bottom: 96 + MediaQuery.paddingOf(context).bottom,
              ),
              buildDefaultDragHandles: false,
              itemCount: slots.length,
              onReorderItem: (from, to) {
                final ordered = [...slots];
                ordered.insert(to, ordered.removeAt(from));
                ref.read(planningRepositoryProvider).reorderSlots(ordered);
              },
              itemBuilder: (context, index) {
                final slot = slots[index];
                return ListTile(
                  key: ValueKey(slot.id),
                  dense: true,
                  leading: ReorderableDragStartListener(
                    index: index,
                    child: const Icon(Icons.drag_handle),
                  ),
                  title: Text(slot.name),
                  onTap: () => _rename(context, ref, slot),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        key: ValueKey('slot-shown-${slot.id}'),
                        value: !slot.hidden,
                        onChanged: (shown) => ref
                            .read(planningRepositoryProvider)
                            .updateSlot(slot.copyWith(hidden: !shown)),
                      ),
                      IconButton(
                        key: ValueKey('slot-delete-${slot.id}'),
                        tooltip: l10n.delete,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(context, ref, slot),
                      ),
                    ],
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
