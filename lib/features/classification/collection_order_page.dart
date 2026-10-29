import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_services.dart';
import '../../domain/label.dart';
import '../../domain/recipe.dart';
import '../../l10n/app_localizations.dart';
import '../recipes/recipe_photo.dart';
import '../recipes/recipe_providers.dart';
import 'labels_providers.dart';

/// L'ordre des recettes d'une collection : on glisse une recette par sa
/// poignée pour la déplacer. La liste des recettes suit cet ordre quand cette
/// collection est la seule filtrée.
class CollectionOrderPage extends ConsumerWidget {
  const CollectionOrderPage({super.key, required this.labelId});

  final String labelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final label = (ref.watch(labelsProvider).value ?? const <Label>[])
        .where((l) => l.id == labelId)
        .firstOrNull;
    final recipes = ref.watch(recipesProvider).value ?? const <Recipe>[];
    final links = ref.watch(recipeLabelLinksProvider).value ?? const {};

    final inCollection =
        [
          for (final r in recipes)
            if (links[r.id]?.containsKey(labelId) ?? false) r,
        ]..sort((a, b) {
          final byRank = links[a.id]![labelId]!.compareTo(
            links[b.id]![labelId]!,
          );
          return byRank != 0 ? byRank : a.title.compareTo(b.title);
        });

    return Scaffold(
      appBar: AppBar(title: Text(label?.name ?? l10n.orderRecipes)),
      body: inCollection.isEmpty
          ? Center(child: Text(l10n.orderEmpty))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l10n.orderRecipesHint),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: EdgeInsets.only(
                      bottom: 24 + MediaQuery.paddingOf(context).bottom,
                    ),
                    buildDefaultDragHandles: false,
                    itemCount: inCollection.length,
                    onReorderItem: (oldIndex, newIndex) {
                      final ids = [for (final r in inCollection) r.id];
                      ids.insert(newIndex, ids.removeAt(oldIndex));
                      ref.read(labelRepositoryProvider).setOrder(labelId, ids);
                    },
                    itemBuilder: (context, index) {
                      final recipe = inCollection[index];
                      return ListTile(
                        key: ValueKey(recipe.id),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox.square(
                            dimension: 48,
                            child: RecipePhoto(
                              photo: recipe.mainPhoto,
                              decodeWidth: 144,
                              iconSize: 20,
                            ),
                          ),
                        ),
                        title: Text(
                          recipe.title.isEmpty
                              ? l10n.untitledRecipe
                              : recipe.title,
                        ),
                        trailing: ReorderableDragStartListener(
                          index: index,
                          child: Tooltip(
                            message: l10n.dragHandle,
                            child: const Padding(
                              padding: EdgeInsets.all(12),
                              child: Icon(Icons.drag_handle),
                            ),
                          ),
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
