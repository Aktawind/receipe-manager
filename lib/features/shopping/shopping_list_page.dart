import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/text_search.dart';
import '../../core/platform/speech_input.dart';
import '../../data/app_services.dart';
import '../../domain/shopping.dart';
import '../../l10n/app_localizations.dart';
import 'shopping_item_sheet.dart';
import 'shopping_page.dart';
import 'shopping_providers.dart';

/// Une liste de courses : les produits à acheter, dans l'ordre choisi, puis
/// ceux du panier (cochés), et la saisie d'un produit en bas.
class ShoppingListPage extends ConsumerWidget {
  const ShoppingListPage({super.key, required this.listId});

  final String listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(shoppingListProvider(listId));
    final list = async.value;
    if (list == null) {
      return Scaffold(appBar: AppBar());
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(list.name),
        actions: [
          PopupMenuButton<String>(
            key: const ValueKey('shopping-list-menu'),
            onSelected: (action) async {
              if (action == 'delete') Navigator.of(context).pop();
              await runShoppingListAction(context, ref, list, action);
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'rename',
                child: Text(l10n.renameShoppingList),
              ),
              PopupMenuItem(
                value: 'reuse',
                child: Text(l10n.reuseShoppingList),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text(l10n.deleteShoppingList),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _Items(list: list)),
          _AddBar(list: list),
        ],
      ),
    );
  }
}

/// Enregistre les produits de [list].
Future<void> _saveItems(
  WidgetRef ref,
  ShoppingList list,
  List<ShoppingItem> items,
) => ref.read(shoppingRepositoryProvider).save(list.copyWith(items: items));

class _Items extends ConsumerWidget {
  const _Items({required this.list});

  final ShoppingList list;

  void _toggle(WidgetRef ref, ShoppingItem item) {
    _saveItems(ref, list, [
      for (final i in list.items)
        if (i.id == item.id) i.copyWith(checked: !i.checked) else i,
    ]);
  }

  void _remove(BuildContext context, WidgetRef ref, ShoppingItem item) {
    final l10n = AppLocalizations.of(context);
    final before = list.items;
    _saveItems(ref, list, [
      for (final i in before)
        if (i.id != item.id) i,
    ]);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          persist: false,
          content: Text(l10n.productRemoved(item.name)),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () => _saveItems(ref, list, before),
          ),
        ),
      );
  }

  void _removeChecked(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final before = list.items;
    final removed = list.inCart.length;
    _saveItems(ref, list, list.toBuy);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          persist: false,
          content: Text(l10n.checkedRemoved(removed)),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () => _saveItems(ref, list, before),
          ),
        ),
      );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    ShoppingItem item,
  ) async {
    final result = await showShoppingItemSheet(context, item);
    if (result == null) return;
    if (!context.mounted) return;
    if (result.removed) {
      _remove(context, ref, item);
      return;
    }
    await _saveItems(ref, list, [
      for (final i in list.items)
        if (i.id == item.id) result.item! else i,
    ]);
  }

  void _reorder(WidgetRef ref, int from, int to) {
    final toBuy = [...list.toBuy];
    final moved = toBuy.removeAt(from);
    toBuy.insert(to, moved);
    _saveItems(ref, list, [...toBuy, ...list.inCart]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    if (list.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_shopping_cart,
                size: 64,
                color: theme.colorScheme.secondary,
              ),
              const SizedBox(height: 16),
              Text(l10n.shoppingListEmpty, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(l10n.shoppingListEmptyHint, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
    final toBuy = list.toBuy;
    final inCart = list.inCart;
    Widget row(ShoppingItem item, {int? index}) => Dismissible(
      key: ValueKey('dismiss-${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        color: theme.colorScheme.errorContainer,
        child: Icon(
          Icons.delete_outline,
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
      onDismissed: (_) => _remove(context, ref, item),
      child: _ItemTile(
        item: item,
        index: index,
        onToggle: () => _toggle(ref, item),
        onEdit: () => _edit(context, ref, item),
      ),
    );

    return CustomScrollView(
      slivers: [
        SliverReorderableList(
          itemCount: toBuy.length,
          onReorderItem: (from, to) => _reorder(ref, from, to),
          itemBuilder: (context, index) => Material(
            key: ValueKey(toBuy[index].id),
            child: row(toBuy[index], index: index),
          ),
        ),
        if (inCart.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.inCartSection(inCart.length),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    key: const ValueKey('shopping-remove-checked'),
                    onPressed: () => _removeChecked(context, ref),
                    icon: const Icon(Icons.remove_done),
                    label: Text(l10n.removeChecked),
                  ),
                ],
              ),
            ),
          ),
        SliverList.list(children: [for (final item in inCart) row(item)]),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    required this.onToggle,
    required this.onEdit,
    this.index,
  });

  final ShoppingItem item;

  /// Sa place parmi les produits à acheter (poignée de déplacement) ;
  /// `null` dans le panier.
  final int? index;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final checked = item.checked;
    final details = [
      if (item.toBuy.isNotEmpty) l10n.productToBuyLine(item.toBuy),
      if (item.format.isNotEmpty) item.format,
      if (item.note.isNotEmpty) item.note,
    ];
    final recipes = {
      for (final s in item.sources)
        if (s.recipeTitle.isNotEmpty) s.recipeTitle,
    };
    final small = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return ListTile(
      key: ValueKey('shopping-item-${item.id}'),
      contentPadding: const EdgeInsets.only(left: 4, right: 4),
      leading: Checkbox(value: checked, onChanged: (_) => onToggle()),
      title: Text.rich(
        TextSpan(
          children: [
            if (item.amount.isNotEmpty)
              TextSpan(
                text: '${item.amount} ',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            TextSpan(text: item.name),
          ],
        ),
        style: checked
            ? TextStyle(
                decoration: TextDecoration.lineThrough,
                color: scheme.onSurfaceVariant,
              )
            : null,
      ),
      subtitle: details.isEmpty && recipes.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (details.isNotEmpty) Text(details.join(' · '), style: small),
                if (recipes.isNotEmpty)
                  Text(
                    l10n.productForRecipes(recipes.join(', ')),
                    style: small?.copyWith(fontStyle: FontStyle.italic),
                  ),
              ],
            ),
      onTap: onEdit,
      trailing: index == null
          ? null
          : ReorderableDragStartListener(
              index: index!,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.drag_handle, semanticLabel: l10n.moveProduct),
              ),
            ),
    );
  }
}

/// La saisie en bas de la liste : une ligne (« 2 kg de pommes de terre »),
/// avec les produits déjà achetés en suggestion, et le micro.
class _AddBar extends ConsumerStatefulWidget {
  const _AddBar({required this.list});

  final ShoppingList list;

  @override
  ConsumerState<_AddBar> createState() => _AddBarState();
}

class _AddBarState extends ConsumerState<_AddBar> {
  TextEditingController? _controller;
  FocusNode? _focus;

  /// Le micro est ouvert (dictée continue).
  var _listening = false;

  /// Ce que la dictée entend en ce moment, puis le dernier produit ajouté.
  var _heard = '';
  var _lastAdded = '';

  /// Ajoute les produits de [lines] à la liste telle qu'elle est en base
  /// (deux phrases dictées coup sur coup ne s'écrasent pas). Renvoie le
  /// nombre de produits ajoutés.
  Future<int> _add(List<String> lines) async {
    final repository = ref.read(shoppingRepositoryProvider);
    final list = await repository.getList(widget.list.id) ?? widget.list;
    var items = list.items;
    var added = 0;
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      items = ShoppingProducts.merge(items, ShoppingProducts.parse(line));
      added++;
    }
    if (added == 0) return 0;
    await _saveItems(ref, list, items);
    return added;
  }

  Future<void> _addTyped(String text) async {
    final added = await _add([text]);
    if (added > 0) _controller?.clear();
  }

  Future<void> _toggleDictation() async {
    final speech = ref.read(speechInputProvider);
    if (_listening) {
      await speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _listening = true;
      _heard = '';
      _lastAdded = '';
    });
    await speech.start(
      onPartial: (text) {
        if (mounted) setState(() => _heard = text);
      },
      onResult: (text) async {
        // Une phrase = un produit ; « et » et les virgules séparent encore.
        final added = await _add(ShoppingProducts.splitDictation(text));
        if (mounted && added > 0) {
          setState(() {
            _heard = '';
            _lastAdded = text;
          });
        }
      },
      onStop: (reason) {
        if (!mounted) return;
        setState(() => _listening = false);
        final message = switch (reason) {
          SpeechStop.user => null,
          SpeechStop.unavailable => l10n.speechUnavailable,
          SpeechStop.permission => l10n.speechPermission,
          SpeechStop.error => l10n.speechError,
        };
        if (message != null) {
          messenger.showSnackBar(
            SnackBar(persist: false, content: Text(message)),
          );
        }
      },
    );
  }

  @override
  void dispose() {
    if (_listening) ref.read(speechInputProvider).stop();
    super.dispose();
  }

  Widget _listeningBanner(AppLocalizations l10n, ColorScheme scheme) {
    final text = _heard.isNotEmpty
        ? '« $_heard »'
        : _lastAdded.isNotEmpty
        ? l10n.dictationAdded(_lastAdded)
        : l10n.dictationHint;
    return Container(
      key: const ValueKey('shopping-listening'),
      color: scheme.primaryContainer,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Icon(Icons.mic, color: scheme.onPrimaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.dictationListening,
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: scheme.onPrimaryContainer),
                ),
              ],
            ),
          ),
          FilledButton.tonalIcon(
            key: const ValueKey('shopping-dictation-stop'),
            onPressed: _toggleDictation,
            icon: const Icon(Icons.stop),
            label: Text(l10n.dictationStop),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final known = ref.watch(knownProductsProvider).value ?? const <String>[];
    final scheme = Theme.of(context).colorScheme;
    final bar = Material(
      color: scheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            children: [
              Expanded(
                child: Autocomplete<String>(
                  optionsViewOpenDirection: OptionsViewOpenDirection.up,
                  optionsBuilder: (value) {
                    final typed = normalizeForSearch(value.text.trim());
                    // Pas de suggestion dès qu'une quantité est tapée.
                    if (typed.length < 2 || RegExp(r'\d').hasMatch(typed)) {
                      return const [];
                    }
                    return known
                        .where(
                          (name) =>
                              normalizeForSearch(name).startsWith(typed) &&
                              normalizeForSearch(name) != typed,
                        )
                        .take(5);
                  },
                  onSelected: _addTyped,
                  fieldViewBuilder: (context, controller, focus, submit) {
                    _controller = controller;
                    _focus = focus;
                    return TextField(
                      key: const ValueKey('shopping-add-field'),
                      controller: controller,
                      focusNode: focus,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        hintText: l10n.addProductHint,
                        labelText: l10n.addProduct,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (text) async {
                        await _addTyped(text);
                        _focus?.requestFocus();
                      },
                    );
                  },
                ),
              ),
              IconButton(
                key: const ValueKey('shopping-dictate'),
                tooltip: _listening ? l10n.dictationStop : l10n.dictateProducts,
                isSelected: _listening,
                icon: const Icon(Icons.mic_none),
                selectedIcon: const Icon(Icons.mic),
                onPressed: _toggleDictation,
              ),
              IconButton(
                key: const ValueKey('shopping-add'),
                tooltip: l10n.addProduct,
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => _addTyped(_controller?.text ?? ''),
              ),
            ],
          ),
        ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [if (_listening) _listeningBanner(l10n, scheme), bar],
    );
  }
}
