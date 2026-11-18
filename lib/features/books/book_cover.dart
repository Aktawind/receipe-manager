import 'package:flutter/material.dart';

import '../recipes/recipe_photo.dart';

/// La couverture d'un livre, en portrait (2:3) ; un livre dessiné sans photo.
class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    required this.cover,
    required this.width,
    this.radius = 6,
  });

  final String? cover;
  final double width;
  final double radius;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: SizedBox(
      width: width,
      height: width * 1.5,
      child: RecipePhoto(
        photo: cover,
        decodeWidth: (width * 3).round(),
        iconSize: width * 0.4,
        icon: Icons.menu_book_outlined,
      ),
    ),
  );
}
