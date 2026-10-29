import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_services.dart';
import '../../domain/label.dart';
import '../../l10n/app_localizations.dart';

/// Le classement commun (catégories, étiquettes, saisons…), dans l'ordre.
final labelsProvider = StreamProvider<List<Label>>(
  (ref) => ref.watch(labelRepositoryProvider).watchAll(),
);

/// Nombre de recettes rattachées à chaque élément.
final labelUsageProvider = StreamProvider<Map<String, int>>(
  (ref) => ref.watch(labelRepositoryProvider).watchUsage(),
);

extension LabelKindText on LabelKind {
  String title(AppLocalizations l10n) => switch (this) {
    LabelKind.category => l10n.kindCategory,
    LabelKind.collection => l10n.kindCollection,
    LabelKind.tag => l10n.kindTag,
    LabelKind.cuisine => l10n.kindCuisine,
    LabelKind.meal => l10n.kindMeal,
    LabelKind.occasion => l10n.kindOccasion,
    LabelKind.season => l10n.kindSeason,
  };

  String singular(AppLocalizations l10n) => switch (this) {
    LabelKind.category => l10n.kindCategorySingular,
    LabelKind.collection => l10n.kindCollectionSingular,
    LabelKind.tag => l10n.kindTagSingular,
    LabelKind.cuisine => l10n.kindCuisineSingular,
    LabelKind.meal => l10n.kindMealSingular,
    LabelKind.occasion => l10n.kindOccasionSingular,
    LabelKind.season => l10n.kindSeasonSingular,
  };

  IconData get icon => switch (this) {
    LabelKind.category => Icons.category_outlined,
    LabelKind.collection => Icons.collections_bookmark_outlined,
    LabelKind.tag => Icons.sell_outlined,
    LabelKind.cuisine => Icons.public,
    LabelKind.meal => Icons.schedule,
    LabelKind.occasion => Icons.celebration_outlined,
    LabelKind.season => Icons.wb_sunny_outlined,
  };
}

/// Chemin d'un élément : « Plats › Viandes » pour une sous-catégorie.
String labelPath(Label label, Map<String, Label> byId) {
  final parent = label.parentId == null ? null : byId[label.parentId];
  return parent == null ? label.name : '${parent.name} › ${label.name}';
}
