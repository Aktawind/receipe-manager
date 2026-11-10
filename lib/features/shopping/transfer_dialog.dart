import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_services.dart';
import '../../domain/shopping.dart';
import '../../l10n/app_localizations.dart';
import 'shopping_providers.dart';

/// « Transférer des produits » : cocher des produits encore à acheter de
/// [list], choisir une autre liste (ou une nouvelle), et les y déplacer.
Future<void> transferShoppingItems(
  BuildContext context,
  WidgetRef ref,
  ShoppingList list,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  final choice = await showDialog<({Set<String> ids, String? toId})>(
    context: context,
    builder: (context) => _TransferDialog(list: list),
  );
  if (choice == null || choice.ids.isEmpty) return;
  final target = await ref
      .read(shoppingRepositoryProvider)
      .transferItems(
        list,
        choice.ids,
        toId: choice.toId,
        newName: l10n.shoppingListDefaultName,
      );
  if (target == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        persist: false,
        content: Text(l10n.productsTransferred(choice.ids.length, target.name)),
        action: SnackBarAction(
          label: l10n.openShoppingList,
          onPressed: () => router.push('/courses/${target.id}'),
        ),
      ),
    );
}

class _TransferDialog extends ConsumerStatefulWidget {
  const _TransferDialog({required this.list});

  final ShoppingList list;

  @override
  ConsumerState<_TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends ConsumerState<_TransferDialog> {
  final _chosen = <String>{};

  /// La liste d'arrivée ; `null` = une nouvelle liste.
  String? _toId;
  var _targetChosen = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = [
      for (final i in widget.list.items)
        if (!i.checked) i,
    ];
    final others = [
      for (final l
          in ref.watch(shoppingListsProvider).value ?? const <ShoppingList>[])
        if (l.id != widget.list.id && !l.isDeleted) l,
    ];
    // Par défaut : l'autre liste la plus récemment modifiée.
    if (!_targetChosen && others.isNotEmpty) _toId = others.first.id;
    final all = items.isNotEmpty && _chosen.length == items.length;
    return AlertDialog(
      title: Text(l10n.transferProducts),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Recréé quand les listes arrivent (valeur de départ).
            KeyedSubtree(
              key: ValueKey(others.length),
              child: DropdownButtonFormField<String?>(
                key: const ValueKey('transfer-target'),
                initialValue: _toId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.transferTo,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final l in others)
                    DropdownMenuItem(value: l.id, child: Text(l.name)),
                  DropdownMenuItem(
                    child: Text(
                      l10n.newShoppingListNamed(l10n.shoppingListDefaultName),
                    ),
                  ),
                ],
                onChanged: (id) => setState(() {
                  _toId = id;
                  _targetChosen = true;
                }),
              ),
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(l10n.transferNothing),
              )
            else ...[
              CheckboxListTile(
                key: const ValueKey('transfer-all'),
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                value: all,
                title: Text(l10n.checkAll),
                onChanged: (on) => setState(() {
                  _chosen.clear();
                  if (on == true) _chosen.addAll([for (final i in items) i.id]);
                }),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final item in items)
                      CheckboxListTile(
                        key: ValueKey('transfer-item-${item.id}'),
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        value: _chosen.contains(item.id),
                        title: Text(
                          [
                            if (item.amount.isNotEmpty) item.amount,
                            item.name,
                          ].join(' '),
                        ),
                        onChanged: (on) => setState(
                          () => on == true
                              ? _chosen.add(item.id)
                              : _chosen.remove(item.id),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const ValueKey('transfer-confirm'),
          onPressed: _chosen.isEmpty
              ? null
              : () => Navigator.pop(context, (ids: {..._chosen}, toId: _toId)),
          child: Text(l10n.transferConfirm(_chosen.length)),
        ),
      ],
    );
  }
}
