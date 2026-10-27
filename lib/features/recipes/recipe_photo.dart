import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_services.dart';

/// Photo d'une recette, ou une illustration neutre si elle n'en a pas.
///
/// [decodeWidth] limite la taille de décodage : les listes n'ont pas besoin
/// de l'image en pleine résolution.
class RecipePhoto extends ConsumerWidget {
  const RecipePhoto({
    super.key,
    required this.photo,
    this.decodeWidth,
    this.iconSize = 40,
  });

  final String? photo;
  final int? decodeWidth;
  final double iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: scheme.primaryContainer,
      child: Center(
        child: Icon(
          Icons.restaurant,
          size: iconSize,
          color: scheme.onPrimaryContainer.withValues(alpha: 0.7),
        ),
      ),
    );
    final name = photo;
    if (name == null) return placeholder;
    final file = ref.watch(photoStoreProvider).file(name);
    return Image.file(
      file,
      fit: BoxFit.cover,
      cacheWidth: decodeWidth,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }
}
