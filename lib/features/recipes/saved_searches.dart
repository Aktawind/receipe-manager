import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/theme_mode_controller.dart';
import '../../core/widgets/name_dialog.dart';
import '../../domain/recipe.dart';
import '../../l10n/app_localizations.dart';
import 'recipe_providers.dart';

/// Une recherche enregistrée : un nom, le texte cherché, les filtres et le tri.
class SavedSearch {
  const SavedSearch({
    required this.name,
    this.query = '',
    this.filter = const RecipeFilter(),
  });

  final String name;
  final String query;
  final RecipeFilter filter;

  Map<String, Object?> toJson() {
    final f = filter;
    return {
      'name': name,
      'query': query,
      'favorites': f.quick == QuickFilter.favorites,
      'labels': f.labelIds.toList(),
      'statuses': [for (final s in f.statuses) s.code],
      'total': f.times.total,
      'prep': f.times.prep,
      'cook': f.times.cook,
      'equipment': f.equipmentIds.toList(),
      'all': f.ingredients.all,
      'any': f.ingredients.any,
      'none': f.ingredients.none,
      'sort': f.sort.name,
    };
  }

  /// Lu avec indulgence : un champ inconnu ou absent prend sa valeur neutre.
  static SavedSearch? fromJson(Object? json) {
    if (json is! Map) return null;
    final name = json['name'];
    if (name is! String || name.trim().isEmpty) return null;
    List<String> strings(String key) => [
      for (final v in (json[key] is List ? json[key] as List : const []))
        if (v is String) v,
    ];
    int? number(String key) => json[key] is int ? json[key] as int : null;
    final sort = RecipeSort.values.asNameMap()[json['sort']];
    return SavedSearch(
      name: name,
      query: json['query'] is String ? json['query'] as String : '',
      filter: RecipeFilter(
        quick: json['favorites'] == true
            ? QuickFilter.favorites
            : QuickFilter.all,
        labelIds: strings('labels').toSet(),
        statuses: {
          for (final code in strings('statuses')) ?RecipeStatus.fromCode(code),
        },
        times: TimeLimits(
          total: number('total'),
          prep: number('prep'),
          cook: number('cook'),
        ),
        equipmentIds: strings('equipment').toSet(),
        ingredients: IngredientCriteria(
          all: strings('all'),
          any: strings('any'),
          none: strings('none'),
        ),
        sort: sort == null || sort == RecipeSort.manual
            ? RecipeSort.title
            : sort,
      ),
    );
  }
}

/// Les recherches enregistrées, gardées sur l'appareil.
final savedSearchesProvider =
    NotifierProvider<SavedSearches, List<SavedSearch>>(SavedSearches.new);

class SavedSearches extends Notifier<List<SavedSearch>> {
  static const _key = 'saved_searches';

  @override
  List<SavedSearch> build() {
    final stored = ref.watch(sharedPreferencesProvider).getStringList(_key);
    return [for (final raw in stored ?? const <String>[]) ?_decode(raw)];
  }

  static SavedSearch? _decode(String raw) {
    try {
      return SavedSearch.fromJson(jsonDecode(raw));
    } on FormatException {
      return null;
    }
  }

  /// Enregistre (ou remplace, à nom égal) une recherche.
  Future<void> save(SavedSearch search) => _save([
    for (final old in state)
      if (old.name.toLowerCase() != search.name.toLowerCase()) old,
    search,
  ]);

  Future<void> remove(String name) => _save([
    for (final old in state)
      if (old.name != name) old,
  ]);

  Future<void> _save(List<SavedSearch> next) async {
    state = next;
    await ref.read(sharedPreferencesProvider).setStringList(_key, [
      for (final s in next) jsonEncode(s.toJson()),
    ]);
  }
}

/// En haut du filtre : les recherches enregistrées (un appui les applique) et
/// de quoi enregistrer la recherche en cours.
class SavedSearchesSection extends ConsumerWidget {
  const SavedSearchesSection({super.key});

  Future<void> _saveCurrent(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final name = await askName(
      context,
      title: l10n.savedSearchSaveTitle,
      label: l10n.savedSearchName,
    );
    if (name == null || name.trim().isEmpty) return;
    await ref
        .read(savedSearchesProvider.notifier)
        .save(
          SavedSearch(
            name: name.trim(),
            query: ref.read(recipeSearchProvider).trim(),
            filter: ref.read(recipeFilterProvider),
          ),
        );
  }

  void _apply(BuildContext context, WidgetRef ref, SavedSearch search) {
    ref.read(recipeFilterProvider.notifier).apply(search.filter);
    ref.read(recipeSearchProvider.notifier).set(search.query);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final saved = ref.watch(savedSearchesProvider);
    final canSave =
        ref.watch(recipeFilterProvider).isActive ||
        ref.watch(recipeSearchProvider).trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.savedSearches,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              TextButton.icon(
                key: const ValueKey('saved-search-save'),
                onPressed: canSave ? () => _saveCurrent(context, ref) : null,
                icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                label: Text(l10n.savedSearchSave),
              ),
            ],
          ),
          if (saved.isEmpty)
            Text(l10n.savedSearchHelp, style: theme.textTheme.bodySmall)
          else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final search in saved)
                  InputChip(
                    avatar: const Icon(Icons.bookmark_outline, size: 18),
                    label: Text(search.name),
                    onPressed: () => _apply(context, ref, search),
                    deleteButtonTooltipMessage: l10n.savedSearchDelete,
                    onDeleted: () => ref
                        .read(savedSearchesProvider.notifier)
                        .remove(search.name),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
