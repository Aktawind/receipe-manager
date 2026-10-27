import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_services.dart';
import '../../domain/recipe.dart';
import '../../l10n/app_localizations.dart';
import '../recipes/recipe_photo.dart';
import '../recipes/recipe_providers.dart';

class TrashPage extends ConsumerWidget {
  const TrashPage({super.key});

  Future<bool> _confirm(BuildContext context, String message) async {
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.deleteForever),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _deleteForever(
    BuildContext context,
    WidgetRef ref,
    List<Recipe> recipes,
    String message,
  ) async {
    if (!await _confirm(context, message)) return;
    final services = ref.read(appServicesProvider);
    final unused = await services.recipes.deletePermanently(
      recipes.map((r) => r.id),
    );
    await services.photos.deleteAll(unused);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final trash = ref.watch(trashProvider).value ?? const [];

    String title(Recipe r) =>
        r.title.trim().isEmpty ? l10n.untitledRecipe : r.title;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.trash),
        actions: [
          if (trash.isNotEmpty)
            TextButton(
              onPressed: () => _deleteForever(
                context,
                ref,
                trash,
                l10n.emptyTrashConfirm(trash.length),
              ),
              child: Text(l10n.emptyTrash),
            ),
        ],
      ),
      body: trash.isEmpty
          ? Center(
              child: Text(l10n.trashEmpty, style: theme.textTheme.titleMedium),
            )
          : ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l10n.trashInfo, style: theme.textTheme.bodySmall),
                ),
                for (final recipe in trash)
                  ListTile(
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
                    title: Text(title(recipe)),
                    subtitle: Text(
                      l10n.deletedOn(
                        MaterialLocalizations.of(context)
                            .formatMediumDate(recipe.deletedAt!),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: l10n.restore,
                          icon: const Icon(Icons.restore),
                          onPressed: () async {
                            await ref
                                .read(recipeRepositoryProvider)
                                .restore(recipe.id);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  l10n.recipeRestored(title(recipe)),
                                ),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          tooltip: l10n.deleteForever,
                          icon: const Icon(Icons.delete_forever_outlined),
                          onPressed: () => _deleteForever(context, ref, [
                            recipe,
                          ], l10n.deleteForeverConfirm(title(recipe))),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
