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

/// Une recette à ajouter aux courses, avec son facteur de départ
/// (personnes voulues / personnes de la recette) et une précision (« lundi,
/// dîner ») ; une même recette peut venir plusieurs fois (planning).
typedef ShoppingEntry = ({Recipe recipe, double factor, String? label});

/// « Ajouter aux courses » : les ingrédients de [recipes] (une recette depuis
/// sa fiche, ou plusieurs depuis une liste), le nombre de personnes de
/// chacune, et la liste où les mettre ([listId] : déjà choisie). [factors] :
/// le facteur de départ de chaque recette (portions affichées sur la fiche).
/// [entries] remplace [recipes] quand une recette revient plusieurs fois ;
/// [notes] : des produits écrits tels quels (notes du planning).
Future<void> showAddToShoppingSheet(
  BuildContext context, {
  List<Recipe> recipes = const [],
  List<ShoppingEntry>? entries,
  List<String> notes = const [],
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
      entries:
          entries ??
          [
            for (final r in recipes)
              (recipe: r, factor: factors[r.id] ?? 1, label: null),
          ],
      notes: notes,
      listId: listId,
      controller: controller,
    ),
  ),
);

class _AddSheet extends ConsumerStatefulWidget {
  const _AddSheet({
    required this.entries,
    required this.notes,
    required this.listId,
    required this.controller,
  });

  final List<ShoppingEntry> entries;
  final List<String> notes;
  final String? listId;
  final ScrollController controller;

  @override
  ConsumerState<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends ConsumerState<_AddSheet> {
  /// Les recettes liées (pâtes, sauces), lues une fois, à toute profondeur.
  Map<String, Recipe>? _linked;

  /// Le facteur de chaque entrée (personnes voulues / personnes prévues).
  late final List<double> _factors = [for (final e in widget.entries) e.factor];

  /// Ce que l'on a décoché ou coché à la main : entrée → index → coché.
  final _choices = <int, Map<int, bool>>{};

  /// Les notes cochées (toutes au départ).
  late final List<bool> _notes = [for (final _ in widget.notes) true];

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
    final queue = [for (final e in widget.entries) ...e.recipe.linkedRecipeIds];
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

  List<ShoppingCandidate> _candidatesOf(int entry) =>
      ShoppingFromRecipes.candidates(
        widget.entries[entry].recipe,
        _factors[entry],
        linked: (id) => _linked?[id],
      );

  bool _isChecked(int entry, int index, ShoppingCandidate c) =>
      _choices[entry]?[index] ?? c.selected;

  int get _selectedCount {
    var count = 0;
    for (var e = 0; e < widget.entries.length; e++) {
      for (final (i, c) in _candidatesOf(e).indexed) {
        if (_isChecked(e, i, c)) count++;
      }
    }
    return count + _notes.where((on) => on).length;
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
    for (var e = 0; e < widget.entries.length; e++) {
      for (final (i, c) in _candidatesOf(e).indexed) {
        if (!_isChecked(e, i, c)) continue;
        items = ShoppingProducts.merge(items, c.item);
        added++;
      }
    }
    for (final (i, note) in widget.notes.indexed) {
      if (!_notes[i]) continue;
      items = ShoppingProducts.merge(items, ShoppingProducts.parse(note));
      added++;
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
                    for (var e = 0; e < widget.entries.length; e++)
                      ..._recipeRows(context, e),
                    if (widget.notes.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                        child: Text(
                          l10n.planningNotes,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      for (final (i, note) in widget.notes.indexed)
                        CheckboxListTile(
                          key: ValueKey('add-shopping-note-$i'),
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: _notes[i],
                          title: Text(note),
                          onChanged: (on) =>
                              setState(() => _notes[i] = on ?? false),
                        ),
                    ],
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

  List<Widget> _recipeRows(BuildContext context, int entry) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final recipe = widget.entries[entry].recipe;
    final label = widget.entries[entry].label;
    final candidates = _candidatesOf(entry);
    final servings = recipe.servings;
    final factor = _factors[entry];
    final count = servings == null ? null : (servings * factor).round();
    // Les clés gardent l'identifiant de la recette pour la première entrée.
    final key = entry == 0 ? recipe.id : '${recipe.id}-$entry';
    void setCount(int value) => setState(() {
      _factors[entry] = value / servings!;
    });
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  if (label != null)
                    Text(label, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            if (count != null) ...[
              IconButton(
                key: ValueKey('add-shopping-less-$key'),
                tooltip: l10n.fewerServings,
                onPressed: count > 1 ? () => setCount(count - 1) : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text(servingsText(l10n, recipe, count)),
              IconButton(
                key: ValueKey('add-shopping-more-$key'),
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
          key: ValueKey('add-shopping-$key-$i'),
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          value: _isChecked(entry, i, c),
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
            (_choices[entry] ??= {})[i] = on ?? false;
          }),
        ),
    ];
  }
}
