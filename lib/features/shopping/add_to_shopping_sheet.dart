import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_services.dart';
import '../../domain/recipe.dart';
import '../../domain/shopping.dart';
import '../../domain/shopping_from_recipes.dart';
import '../../l10n/app_localizations.dart';
import '../recipes/recipe_scale.dart';
import 'shopping_providers.dart';

/// « Ajouter aux courses » : les ingrédients de [recipes] (une recette depuis
/// sa fiche, ou plusieurs depuis une liste), le nombre de personnes de
/// chacune, et la liste où les mettre ([listId] : déjà choisie). [factors] :
/// le facteur de départ de chaque recette (portions affichées sur la fiche).
Future<void> showAddToShoppingSheet(
  BuildContext context, {
  required List<Recipe> recipes,
  String? listId,
  Map<String, double> factors = const {},
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.85,
    minChildSize: 0.5,
    maxChildSize: 0.95,
    builder: (context, controller) => _AddSheet(
      recipes: recipes,
      listId: listId,
      factors: factors,
      controller: controller,
    ),
  ),
);

class _AddSheet extends ConsumerStatefulWidget {
  const _AddSheet({
    required this.recipes,
    required this.listId,
    required this.factors,
    required this.controller,
  });

  final List<Recipe> recipes;
  final String? listId;
  final Map<String, double> factors;
  final ScrollController controller;

  @override
  ConsumerState<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends ConsumerState<_AddSheet> {
  /// Les recettes liées (pâtes, sauces), lues une fois, à toute profondeur.
  Map<String, Recipe>? _linked;

  /// Le facteur de chaque recette (personnes voulues / personnes prévues).
  late final Map<String, double> _factors = {
    for (final r in widget.recipes) r.id: widget.factors[r.id] ?? 1,
  };

  /// Ce que l'on a décoché ou coché à la main : recette → index → coché.
  final _choices = <String, Map<int, bool>>{};

  /// La liste choisie ; `null` = une nouvelle liste.
  String? _listId;
  var _listChosen = false;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _listId = widget.listId;
    _listChosen = widget.listId != null;
    _loadLinked();
  }

  Future<void> _loadLinked() async {
    final repository = ref.read(recipeRepositoryProvider);
    final found = <String, Recipe>{};
    final queue = [for (final r in widget.recipes) ...r.linkedRecipeIds];
    while (queue.isNotEmpty) {
      final id = queue.removeLast();
      if (found.containsKey(id)) continue;
      final recipe = await repository.getRecipe(id);
      if (recipe == null || recipe.isDeleted) continue;
      found[id] = recipe;
      queue.addAll(recipe.linkedRecipeIds);
    }
    if (mounted) setState(() => _linked = found);
  }

  List<ShoppingCandidate> _candidatesOf(Recipe recipe) =>
      ShoppingFromRecipes.candidates(
        recipe,
        _factors[recipe.id]!,
        linked: (id) => _linked?[id],
      );

  bool _isChecked(Recipe recipe, int index, ShoppingCandidate c) =>
      _choices[recipe.id]?[index] ?? c.selected;

  int get _selectedCount {
    var count = 0;
    for (final recipe in widget.recipes) {
      for (final (i, c) in _candidatesOf(recipe).indexed) {
        if (_isChecked(recipe, i, c)) count++;
      }
    }
    return count;
  }

  Future<void> _add() async {
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(shoppingRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    final target = _listId == null
        ? await repository.createList(l10n.shoppingListDefaultName)
        : await repository.getList(_listId!);
    if (target == null) {
      setState(() => _saving = false);
      return;
    }
    var items = target.items;
    var added = 0;
    for (final recipe in widget.recipes) {
      for (final (i, c) in _candidatesOf(recipe).indexed) {
        if (!_isChecked(recipe, i, c)) continue;
        items = ShoppingProducts.merge(items, c.item);
        added++;
      }
    }
    await repository.save(target.copyWith(items: items));
    navigator.pop();
    final openList = widget.listId == null;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          persist: false,
          content: Text(l10n.addedToShoppingList(added, target.name)),
          action: openList
              ? SnackBarAction(
                  label: l10n.openShoppingList,
                  onPressed: () => router.go('/courses/${target.id}'),
                )
              : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final lists = ref.watch(shoppingListsProvider).value ?? const [];
    // Par défaut : la liste la plus récemment modifiée.
    if (!_listChosen && lists.isNotEmpty) {
      _listId = lists.first.id;
    }
    final linked = _linked;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.addToShopping, style: theme.textTheme.titleLarge),
              if (widget.listId == null) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  key: const ValueKey('add-shopping-list'),
                  initialValue: _listId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.shoppingListChoice,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final list in lists)
                      DropdownMenuItem(value: list.id, child: Text(list.name)),
                    DropdownMenuItem(
                      child: Text(
                        l10n.newShoppingListNamed(l10n.shoppingListDefaultName),
                      ),
                    ),
                  ],
                  onChanged: (id) => setState(() {
                    _listId = id;
                    _listChosen = true;
                  }),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: linked == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  controller: widget.controller,
                  children: [
                    for (final recipe in widget.recipes)
                      ..._recipeRows(context, recipe),
                  ],
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton.icon(
              key: const ValueKey('add-shopping-confirm'),
              onPressed: linked == null || _saving || _selectedCount == 0
                  ? null
                  : _add,
              icon: const Icon(Icons.add_shopping_cart),
              label: Text(
                linked == null
                    ? l10n.addToShopping
                    : l10n.addProductsCount(_selectedCount),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _recipeRows(BuildContext context, Recipe recipe) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final candidates = _candidatesOf(recipe);
    final servings = recipe.servings;
    final factor = _factors[recipe.id]!;
    final count = servings == null ? null : (servings * factor).round();
    void setCount(int value) => setState(() {
      _factors[recipe.id] = value / servings!;
    });
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                recipe.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            if (count != null) ...[
              IconButton(
                key: ValueKey('add-shopping-less-${recipe.id}'),
                tooltip: l10n.fewerServings,
                onPressed: count > 1 ? () => setCount(count - 1) : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text(servingsText(l10n, recipe, count)),
              IconButton(
                key: ValueKey('add-shopping-more-${recipe.id}'),
                tooltip: l10n.moreServings,
                onPressed: () => setCount(count + 1),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ],
        ),
      ),
      for (final (i, c) in candidates.indexed)
        CheckboxListTile(
          key: ValueKey('add-shopping-${recipe.id}-$i'),
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          value: _isChecked(recipe, i, c),
          title: Text(
            [
              if (c.item.amount.isNotEmpty) c.item.amount,
              c.item.name,
            ].join(' '),
          ),
          subtitle: c.viaRecipe == null
              ? null
              : Text(l10n.fromLinkedRecipe(c.viaRecipe!)),
          onChanged: (on) => setState(() {
            (_choices[recipe.id] ??= {})[i] = on ?? false;
          }),
        ),
    ];
  }
}
