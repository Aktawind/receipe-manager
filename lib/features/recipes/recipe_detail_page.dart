import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_services.dart';
import '../../domain/recipe.dart';
import '../../l10n/app_localizations.dart';
import '../shopping/add_to_shopping_sheet.dart';
import 'detail/detail_header.dart';
import 'detail/detail_sections.dart';
import 'recipe_photo.dart';
import 'recipe_providers.dart';
import 'recipe_scale.dart';

/// Largeur à partir de laquelle la fiche passe sur deux colonnes (tablette).
const _wideBreakpoint = 840.0;

/// Largeur de la colonne de gauche (photo, infos, ingrédients) sur tablette.
const _widePaneWidth = 440.0;

class RecipeDetailPage extends ConsumerStatefulWidget {
  const RecipeDetailPage({super.key, required this.recipeId});

  final String recipeId;

  @override
  ConsumerState<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends ConsumerState<RecipeDetailPage> {
  String get recipeId => widget.recipeId;

  @override
  void initState() {
    super.initState();
    // La fiche ouverte compte dans « récemment consultées ».
    ref.read(recipeRepositoryProvider).markViewed(recipeId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final recipe = ref.watch(recipeProvider(recipeId));
    return recipe.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(body: Center(child: Text('$error'))),
      data: (recipe) => recipe == null || recipe.isDeleted
          ? Scaffold(
              appBar: AppBar(),
              body: Center(child: Text(l10n.recipeNotFound)),
            )
          : _RecipeDetail(recipe: recipe),
    );
  }
}

enum _MenuAction { duplicate, delete }

/// Marge du bas : de quoi faire défiler le contenu au-dessus du bouton du
/// mode cuisine.
const _bottomSpace = 104.0;

/// Hauteur de la barre système (navigation Android) à ne pas recouvrir.
double _bottomInset(BuildContext context) =>
    MediaQuery.paddingOf(context).bottom;

class _RecipeDetail extends ConsumerWidget {
  const _RecipeDetail({required this.recipe});

  final Recipe recipe;

  String _title(AppLocalizations l10n) =>
      recipe.title.trim().isEmpty ? l10n.untitledRecipe : recipe.title;

  Future<void> _onMenu(
    BuildContext context,
    WidgetRef ref,
    _MenuAction action,
  ) async {
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(recipeRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    switch (action) {
      case _MenuAction.duplicate:
        final copy = await repository.duplicate(
          recipe.id,
          titleSuffix: l10n.duplicateSuffix,
        );
        if (copy != null && context.mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.recipeDuplicated)),
          );
          context.pushReplacement('/recettes/${copy.id}');
        }
      case _MenuAction.delete:
        await repository.moveToTrash(recipe.id);
        if (!context.mounted) return;
        context.pop();
        messenger.showSnackBar(
          SnackBar(
            persist: false,
            content: Text(l10n.recipeMovedToTrash(_title(l10n))),
            action: SnackBarAction(
              label: l10n.undo,
              onPressed: () => repository.restore(recipe.id),
            ),
          ),
        );
    }
  }

  void _edit(BuildContext context) =>
      context.push('/recettes/${recipe.id}/modifier');

  Widget _topButtons(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DetailCircleButton(
          icon: recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
          tooltip: recipe.isFavorite
              ? l10n.removeFromFavorites
              : l10n.addToFavorites,
          onPressed: () => ref
              .read(recipeRepositoryProvider)
              .setFavorite(recipe.id, !recipe.isFavorite),
        ),
        const SizedBox(width: 8),
        DetailCircleButton(
          key: const ValueKey('recipe-add-to-shopping'),
          icon: Icons.add_shopping_cart,
          tooltip: l10n.addToShopping,
          onPressed: () => showAddToShoppingSheet(
            context,
            recipes: [recipe],
            factors: {recipe.id: ref.read(recipeScaleProvider(recipe.id))},
          ),
        ),
        const SizedBox(width: 8),
        DetailCircleButton(
          icon: Icons.edit_outlined,
          tooltip: l10n.edit,
          onPressed: () => _edit(context),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<_MenuAction>(
          tooltip: MaterialLocalizations.of(context).showMenuTooltip,
          onSelected: (action) => _onMenu(context, ref, action),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: _MenuAction.duplicate,
              child: ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: Text(l10n.duplicate),
              ),
            ),
            PopupMenuItem(
              value: _MenuAction.delete,
              child: ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(l10n.delete),
              ),
            ),
          ],
          child: const DetailCircleIcon(icon: Icons.more_vert),
        ),
      ],
    );
  }

  Widget _cookButton(BuildContext context) => FloatingActionButton.extended(
    key: const ValueKey('cooking-open'),
    heroTag: null,
    onPressed: () => context.push('/recettes/${recipe.id}/cuisine'),
    icon: const Icon(Icons.soup_kitchen_outlined),
    label: Text(AppLocalizations.of(context).cookingMode),
  );

  Widget _backButton(BuildContext context) => DetailCircleButton(
    icon: Icons.arrow_back,
    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
    onPressed: () => context.pop(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= _wideBreakpoint
        ? _buildWide(context, ref)
        : _buildNarrow(context, ref, width);
  }

  Widget _buildNarrow(BuildContext context, WidgetRef ref, double width) {
    final hasPhoto = recipe.mainPhoto != null;
    // Photo carrée sur toute la largeur ; sans photo, un bandeau plus bas.
    final heroHeight = hasPhoto ? width : 200.0;
    return Scaffold(
      floatingActionButton: _cookButton(context),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: Theme.of(context).colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            expandedHeight: heroHeight,
            leadingWidth: 64,
            leading: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Center(child: _backButton(context)),
            ),
            actions: [_topButtons(context, ref), const SizedBox(width: 12)],
            flexibleSpace: FlexibleSpaceBar(
              background: RecipePhoto(
                photo: recipe.mainPhoto,
                decodeWidth: 1440,
                iconSize: 64,
              ),
            ),
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(detailSheetRadius),
              child: DetailSheetTop(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                _bottomSpace + _bottomInset(context),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DetailHeader(
                    recipe: recipe,
                    onStatus: (status) => ref
                        .read(recipeRepositoryProvider)
                        .setStatus(recipe.id, status),
                    onRating: (rating) => ref
                        .read(recipeRepositoryProvider)
                        .setRating(recipe.id, rating),
                  ),
                  DetailIngredientsSection(recipe: recipe),
                  DetailEquipmentSection(recipe: recipe),
                  DetailStepsSection(recipe: recipe),
                  ..._secondarySections(context, ref),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWide(BuildContext context, WidgetRef ref) {
    return Scaffold(
      floatingActionButton: _cookButton(context),
      body: Row(
        children: [
          SizedBox(
            width: _widePaneWidth,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                SizedBox.square(
                  dimension: _widePaneWidth,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      RecipePhoto(
                        photo: recipe.mainPhoto,
                        decodeWidth: 1320,
                        iconSize: 64,
                      ),
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: _backButton(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    _bottomSpace + _bottomInset(context),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DetailHeader(
                        recipe: recipe,
                        onStatus: (status) => ref
                            .read(recipeRepositoryProvider)
                            .setStatus(recipe.id, status),
                        onRating: (rating) => ref
                            .read(recipeRepositoryProvider)
                            .setRating(recipe.id, rating),
                      ),
                      DetailIngredientsSection(recipe: recipe),
                      DetailEquipmentSection(recipe: recipe),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                32,
                12,
                32,
                _bottomSpace + _bottomInset(context),
              ),
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: SafeArea(child: _topButtons(context, ref)),
                ),
                DetailStepsSection(recipe: recipe),
                ..._secondarySections(context, ref),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _secondarySections(BuildContext context, WidgetRef ref) {
    return [
      DetailNotesSection(recipe: recipe, onEdit: () => _edit(context)),
      DetailAboutSection(recipe: recipe),
    ];
  }
}
