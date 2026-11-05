import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/text_search.dart';
import '../../domain/recipe.dart';
import '../../l10n/app_localizations.dart';
import '../recipes/recipe_providers.dart';

/// Choix de plusieurs recettes (pour les courses) ; renvoie leurs
/// identifiants dans l'ordre coché, `null` si on annule.
Future<List<String>?> pickRecipes(BuildContext context) =>
    showDialog<List<String>>(
      context: context,
      builder: (context) => const _RecipePicker(),
    );

class _RecipePicker extends ConsumerStatefulWidget {
  const _RecipePicker();

  @override
  ConsumerState<_RecipePicker> createState() => _RecipePickerState();
}

class _RecipePickerState extends ConsumerState<_RecipePicker> {
  final _selected = <String>[];
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final all = ref.watch(recipesProvider).value ?? const <Recipe>[];
    final key = normalizeForSearch(_query.trim());
    final shown = [
      for (final r in all)
        if (key.isEmpty || normalizeForSearch(r.title).contains(key)) r,
    ];
    return AlertDialog(
      title: Text(l10n.chooseRecipes),
      content: SizedBox(
        width: 400,
        height: 460,
        child: Column(
          children: [
            TextField(
              key: const ValueKey('recipe-picker-search'),
              decoration: InputDecoration(
                hintText: l10n.searchRecipes,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  for (final recipe in shown)
                    CheckboxListTile(
                      key: ValueKey('recipe-picker-${recipe.id}'),
                      value: _selected.contains(recipe.id),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        recipe.title.trim().isEmpty
                            ? l10n.untitledRecipe
                            : recipe.title,
                      ),
                      onChanged: (on) => setState(() {
                        on == true
                            ? _selected.add(recipe.id)
                            : _selected.remove(recipe.id);
                      }),
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
          key: const ValueKey('recipe-picker-ok'),
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.pop(context, _selected),
          child: Text(l10n.validate),
        ),
      ],
    );
  }
}
