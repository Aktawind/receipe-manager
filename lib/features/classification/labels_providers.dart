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
    LabelKind.season => l10n.kindSeason,
    LabelKind.collection => l10n.kindCollection,
    LabelKind.cuisine => l10n.kindCuisine,
  };

  String singular(AppLocalizations l10n) => switch (this) {
    LabelKind.category => l10n.kindCategorySingular,
    LabelKind.season => l10n.kindSeasonSingular,
    LabelKind.collection => l10n.kindCollectionSingular,
    LabelKind.cuisine => l10n.kindCuisineSingular,
  };

  IconData get icon => switch (this) {
    LabelKind.category => Icons.category_outlined,
    LabelKind.season => Icons.wb_sunny_outlined,
    LabelKind.collection => Icons.collections_bookmark_outlined,
    LabelKind.cuisine => Icons.public,
  };
}

/// Chemin d'un élément : « Plats › Viandes » pour une sous-catégorie.
String labelPath(Label label, Map<String, Label> byId) {
  final parent = label.parentId == null ? null : byId[label.parentId];
  return parent == null ? label.name : '${parent.name} › ${label.name}';
}
