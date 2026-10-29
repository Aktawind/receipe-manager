import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/name_dialog.dart';
import '../../data/app_services.dart';
import '../../domain/label.dart';
import '../../l10n/app_localizations.dart';
import 'label_style.dart';
import 'labels_providers.dart';

/// Réglages → Classement : la liste des familles (catégories, collections…).
class ClassificationPage extends ConsumerWidget {
  const ClassificationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final labels = ref.watch(labelsProvider).value ?? const <Label>[];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.classificationTitle)),
      body: ListView(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        children: [
          for (final kind in LabelKind.values)
            ListTile(
              leading: Icon(kind.icon),
              title: Text(kind.title(l10n)),
              subtitle: Text(
                labels
                    .where((l) => l.kind == kind)
                    .map((l) => l.name)
                    .take(4)
                    .join(', '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/reglages/classement/${kind.code}'),
            ),
        ],
      ),
    );
  }
}

enum _Action { rename, style, addChild, merge, delete }

/// Gestion d'une famille : ajouter, renommer, choisir icône et couleur,
/// fusionner, supprimer.
class LabelsPage extends ConsumerWidget {
  const LabelsPage({super.key, required this.kind});

  final LabelKind kind;

  Future<void> _add(
    BuildContext context,
    WidgetRef ref, {
    Label? parent,
  }) async {
    final l10n = AppLocalizations.of(context);
    final name = await askName(
      context,
      title: parent == null ? l10n.addLabel : l10n.addSubcategory,
    );
    if (name == null || name.trim().isEmpty) return;
    await ref
        .read(labelRepositoryProvider)
        .findOrCreate(kind, name, parentId: parent?.id);
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, Label label) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final name = await askName(context, title: label.name, initial: label.name);
    if (name == null || name.trim().isEmpty || name.trim() == label.name) {
      return;
    }
    final done = await ref.read(labelRepositoryProvider).rename(label.id, name);
    if (!done) {
      messenger.showSnackBar(
        SnackBar(persist: false, content: Text(l10n.labelExists)),
      );
    }
  }

  Future<void> _style(BuildContext context, WidgetRef ref, Label label) async {
    final chosen = await showDialog<(String, String)>(
      context: context,
      builder: (context) => _StyleDialog(label: label),
    );
    if (chosen == null) return;
    await ref
        .read(labelRepositoryProvider)
        .setStyle(label.id, icon: chosen.$1, color: chosen.$2);
  }

  Future<void> _merge(
    BuildContext context,
    WidgetRef ref,
    Label label,
    List<Label> all,
  ) async {
    final l10n = AppLocalizations.of(context);
    final byId = {for (final l in all) l.id: l};
    final candidates = [
      for (final l in all)
        if (l.kind == kind && l.id != label.id && l.parentId != label.id) l,
    ];
    final target = await showDialog<Label>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.mergeWith(label.name)),
        content: SizedBox(
          width: 400,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final c in candidates)
                ListTile(
                  title: Text(labelPath(c, byId)),
                  onTap: () => Navigator.pop(context, c),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
    if (target == null) return;
    await ref.read(labelRepositoryProvider).merge(label.id, target.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(persist: false, content: Text(l10n.merged)));
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Label label,
    bool hasChildren,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(
          hasChildren
              ? l10n.deleteLabelWithChildren(label.name)
              : l10n.deleteLabelConfirm(label.name),
        ),
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
      await ref.read(labelRepositoryProvider).delete(label.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final all = ref.watch(labelsProvider).value ?? const <Label>[];
    final usage = ref.watch(labelUsageProvider).value ?? const {};
    final items = all.where((l) => l.kind == kind).toList();

    // Les catégories s'affichent en arbre : chaque parent suivi de ses enfants.
    final rows = <(Label, int)>[];
    for (final top in items.where((l) => l.parentId == null)) {
      rows.add((top, 0));
      for (final child in items.where((l) => l.parentId == top.id)) {
        rows.add((child, 1));
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(kind.title(l10n))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.addLabel),
      ),
      body: ListView.builder(
        padding: EdgeInsets.only(
          bottom: 96 + MediaQuery.paddingOf(context).bottom,
        ),
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final (label, depth) = rows[index];
          final hasChildren = items.any((l) => l.parentId == label.id);
          final color = labelColor(scheme, label.color);
          return ListTile(
            contentPadding: EdgeInsets.only(left: 16.0 + depth * 32, right: 4),
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: color ?? scheme.primary.withValues(alpha: 0.1),
              foregroundColor: color == null
                  ? scheme.primary
                  : (label.color == 'butter' || label.color == 'caramel'
                        ? scheme.onTertiary
                        : scheme.onPrimary),
              child: Icon(labelIconData(label.icon, kind.icon), size: 20),
            ),
            title: Text(label.name),
            subtitle: Text(l10n.labelUsed(usage[label.id] ?? 0)),
            onTap: () => _rename(context, ref, label),
            trailing: PopupMenuButton<_Action>(
              onSelected: (action) => switch (action) {
                _Action.rename => _rename(context, ref, label),
                _Action.style => _style(context, ref, label),
                _Action.addChild => _add(context, ref, parent: label),
                _Action.merge => _merge(context, ref, label, all),
                _Action.delete => _delete(context, ref, label, hasChildren),
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _Action.rename,
                  child: Text(l10n.renameEquipment),
                ),
                PopupMenuItem(
                  value: _Action.style,
                  child: Text(l10n.labelStyle),
                ),
                if (kind == LabelKind.category && label.parentId == null)
                  PopupMenuItem(
                    value: _Action.addChild,
                    child: Text(l10n.addSubcategory),
                  ),
                PopupMenuItem(
                  value: _Action.merge,
                  child: Text(l10n.mergeInto),
                ),
                PopupMenuItem(value: _Action.delete, child: Text(l10n.delete)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StyleDialog extends StatefulWidget {
  const _StyleDialog({required this.label});

  final Label label;

  @override
  State<_StyleDialog> createState() => _StyleDialogState();
}

class _StyleDialogState extends State<_StyleDialog> {
  late String _icon = widget.label.icon;
  late String _color = widget.label.color;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(l10n.labelStyle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.labelColor,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final key in ['', ...labelColorKeys])
                  Tooltip(
                    message: labelColorName(l10n, key),
                    child: InkResponse(
                      onTap: () => setState(() => _color = key),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor:
                            labelColor(scheme, key) ??
                            scheme.surfaceContainerHighest,
                        child: _color == key
                            ? Icon(
                                Icons.check,
                                size: 18,
                                color: key == 'butter' || key == 'caramel'
                                    ? scheme.onTertiary
                                    : (key.isEmpty
                                          ? scheme.onSurface
                                          : scheme.onPrimary),
                              )
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(l10n.labelIcon, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final entry in labelIcons.entries)
                  IconButton(
                    tooltip: entry.key,
                    isSelected: _icon == entry.key,
                    icon: Icon(entry.value),
                    onPressed: () => setState(
                      () => _icon = _icon == entry.key ? '' : entry.key,
                    ),
                  ),
              ],
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
          onPressed: () => Navigator.pop(context, (_icon, _color)),
          child: Text(l10n.validate),
        ),
      ],
    );
  }
}
