import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// L'étoile n° [star] (1 à 5) pour la note [rating] : pleine, à moitié
/// (4,5 → la 5ᵉ est à moitié) ou vide.
IconData starIcon(int star, double? rating) {
  final value = rating ?? 0;
  if (star <= value) return Icons.star;
  if (star - 0.5 <= value) return Icons.star_half;
  return Icons.star_border;
}

/// « 4 », « 4,5 » : la note écrite à la française.
String formatRating(double rating) => rating == rating.roundToDouble()
    ? '${rating.round()}'
    : rating.toStringAsFixed(1).replaceAll('.', ',');

/// Les cinq étoiles d'une note, demi-étoiles comprises (affichage seul).
class RatingStars extends StatelessWidget {
  const RatingStars({super.key, required this.rating, this.size = 16});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.tertiary;
    return Semantics(
      label: AppLocalizations.of(context).ratingValue(formatRating(rating)),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            Icon(starIcon(i, rating), size: size, color: color),
        ],
      ),
    );
  }
}
