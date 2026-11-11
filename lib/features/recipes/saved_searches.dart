import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/name_dialog.dart';
import '../../data/app_services.dart';
import '../../domain/saved_search.dart';
import '../../l10n/app_localizations.dart';
import 'recipe_providers.dart';

/// Les recherches enregistrées, synchronisées entre les appareils.
final savedSearchesProvider = StreamProvider<List<SavedSearch>>(
  (ref) => ref.watch(recipeRepositoryProvider).watchSavedSearches(),
);

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
        .read(recipeRepositoryProvider)
        .saveSearch(
          name: name.trim(),
          query: ref.read(recipeSearchProvider).trim(),
          filter: ref.read(recipeFilterProvider),
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
    final saved = ref.watch(savedSearchesProvider).value ?? const [];
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
                        .read(recipeRepositoryProvider)
                        .deleteSavedSearch(search),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
