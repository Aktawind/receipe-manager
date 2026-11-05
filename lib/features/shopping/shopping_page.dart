import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/name_dialog.dart';
import '../../data/app_services.dart';
import '../../domain/shopping.dart';
import '../../l10n/app_localizations.dart';
import 'shopping_providers.dart';

/// Courses : les listes (semaine, repas, événement…).
class ShoppingPage extends ConsumerWidget {
  const ShoppingPage({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final router = GoRouter.of(context);
    final name = await askName(
      context,
      title: l10n.newShoppingList,
      initial: l10n.shoppingListDefaultName,
      label: l10n.shoppingListName,
    );
    if (name == null || name.trim().isEmpty) return;
    final list = await ref.read(shoppingRepositoryProvider).createList(name);
    await router.push('/courses/${list.id}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final lists = ref.watch(shoppingListsProvider).value;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navShopping)),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('shopping-new-list'),
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.newShoppingList),
      ),
      body: lists == null
          ? const SizedBox.shrink()
          : lists.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shopping_basket_outlined,
                      size: 72,
                      color: theme.colorScheme.secondary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.shoppingListsEmpty,
                      style: theme.textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.shoppingListsEmptyHint,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              // Marge du bas : bouton flottant et barre de navigation Android.
              padding: EdgeInsets.only(
                top: 8,
                bottom: 96 + MediaQuery.paddingOf(context).bottom,
              ),
              itemCount: lists.length,
              itemBuilder: (context, index) => _ListTile(list: lists[index]),
            ),
    );
  }
}

enum _ListAction { rename, reuse, delete }

class _ListTile extends ConsumerWidget {
  const _ListTile({required this.list});

  final ShoppingList list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: const Icon(Icons.checklist),
      title: Text(list.name),
      subtitle: Text(
        l10n.shoppingListSummary(list.toBuy.length, list.inCart.length),
      ),
      onTap: () => context.push('/courses/${list.id}'),
      trailing: PopupMenuButton<_ListAction>(
        onSelected: (action) =>
            runShoppingListAction(context, ref, list, action.name),
        itemBuilder: (context) => [
          PopupMenuItem(
            value: _ListAction.rename,
            child: Text(l10n.renameShoppingList),
          ),
          PopupMenuItem(
            value: _ListAction.reuse,
            child: Text(l10n.reuseShoppingList),
          ),
          PopupMenuItem(
            value: _ListAction.delete,
            child: Text(l10n.deleteShoppingList),
          ),
        ],
      ),
    );
  }
}

/// Renommer, réutiliser ou supprimer une liste ([action] : `rename`,
/// `reuse`, `delete`), depuis les listes ou depuis la liste ouverte.
Future<void> runShoppingListAction(
  BuildContext context,
  WidgetRef ref,
  ShoppingList list,
  String action,
) async {
  final l10n = AppLocalizations.of(context);
  final repository = ref.read(shoppingRepositoryProvider);
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  switch (action) {
    case 'rename':
      final name = await askName(
        context,
        title: l10n.renameShoppingList,
        initial: list.name,
        label: l10n.shoppingListName,
      );
      if (name == null || name.trim().isEmpty) return;
      await repository.rename(list, name);
    case 'reuse':
      final copy = await repository.duplicateList(
        list,
        l10n.reusedListName(list.name),
      );
      await router.push('/courses/${copy.id}');
    case 'delete':
      await repository.delete(list);
      messenger.showSnackBar(
        SnackBar(
          persist: false,
          content: Text(l10n.shoppingListDeleted(list.name)),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () => repository.restore(list),
          ),
        ),
      );
  }
}
