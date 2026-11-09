import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/name_dialog.dart';
import '../../data/app_services.dart';
import '../../domain/label.dart';
import '../../domain/planning.dart';
import '../../l10n/app_localizations.dart';
import '../classification/labels_providers.dart';
import 'planning_providers.dart';

/// Les catégories (types de plat), chacune suivie de ses sous-catégories.
List<(Label, int)> _categoryTree(List<Label> labels) {
  final categories = [
    for (final l in labels)
      if (l.kind == LabelKind.category && !l.isDeleted) l,
  ]..sort((a, b) => a.position.compareTo(b.position));
  final ids = {for (final c in categories) c.id};
  final result = <(Label, int)>[];
  void add(String? parentId, int depth) {
    for (final c in categories) {
      final isRoot = c.parentId == null || !ids.contains(c.parentId);
      if (parentId == null ? isRoot : c.parentId == parentId) {
        result.add((c, depth));
        add(c.id, depth + 1);
      }
    }
  }

  add(null, 0);
  return result;
}

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

  Future<void> _categories(
    BuildContext context,
    WidgetRef ref,
    MealSlot slot,
    List<Label> labels,
  ) async {
    final chosen = await showDialog<Set<String>>(
      context: context,
      builder: (context) =>
          _CategoriesDialog(slot: slot, tree: _categoryTree(labels)),
    );
    if (chosen == null) return;
    await ref
        .read(planningRepositoryProvider)
        .updateSlot(slot.copyWith(categoryIds: chosen));
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
    final labels = ref.watch(labelsProvider).value ?? const <Label>[];
    final names = {for (final l in labels) l.id: l.name};
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
                  subtitle: Text(
                    slot.categoryIds.isEmpty
                        ? l10n.mealSlotAllCategories
                        : [for (final id in slot.categoryIds) ?names[id]]
                              .join(', '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _rename(context, ref, slot),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: ValueKey('slot-categories-${slot.id}'),
                        tooltip: l10n.mealSlotCategories,
                        icon: const Icon(Icons.restaurant_menu),
                        onPressed: () =>
                            _categories(context, ref, slot, labels),
                      ),
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

/// Les types de plat qu'un créneau propose ; rien de coché = tous.
class _CategoriesDialog extends StatefulWidget {
  const _CategoriesDialog({required this.slot, required this.tree});

  final MealSlot slot;
  final List<(Label, int)> tree;

  @override
  State<_CategoriesDialog> createState() => _CategoriesDialogState();
}

class _CategoriesDialogState extends State<_CategoriesDialog> {
  late final _chosen = {...widget.slot.categoryIds};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text('${l10n.mealSlotCategories} · ${widget.slot.name}'),
      content: SizedBox(
        width: 360,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(l10n.mealSlotCategoriesHint, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            for (final (label, depth) in widget.tree)
              CheckboxListTile(
                key: ValueKey('slot-category-${label.id}'),
                dense: true,
                contentPadding: EdgeInsets.only(left: 16.0 * depth),
                controlAffinity: ListTileControlAffinity.leading,
                value: _chosen.contains(label.id),
                title: Text(label.name),
                onChanged: (on) => setState(
                  () => on == true
                      ? _chosen.add(label.id)
                      : _chosen.remove(label.id),
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
          key: const ValueKey('slot-categories-ok'),
          onPressed: () => Navigator.pop(context, {..._chosen}),
          child: Text(l10n.validate),
        ),
      ],
    );
  }
}
