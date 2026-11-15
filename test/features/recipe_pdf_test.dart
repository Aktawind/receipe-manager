import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/features/recipes/recipe_pdf.dart';

void main() {
  test(
    'le PDF d’une recette, même longue, avec des caractères spéciaux',
    () async {
      final bytes = await RecipePdf.build(
        title: 'Bœuf bourguignon de l’été 🍷',
        info: ['6 pers.', 'Cuisson 3 h'],
        description: 'Un classique « mijoté ».',
        ingredients: [
          (section: true, text: 'Viande'),
          for (var i = 0; i < 60; i++)
            (section: false, text: '1 kg de bœuf $i'),
        ],
        steps: [
          for (var i = 0; i < 30; i++)
            (
              title: i == 0 ? 'La veille' : '',
              text: 'Étape longue numéro $i. ' * 8,
            ),
        ],
        notes: 'Encore meilleur réchauffé…',
        source: 'Grand-mère',
        words: (
          ingredients: 'Ingrédients',
          steps: 'Préparation',
          notes: 'Notes',
          source: 'Source',
          or: 'ou',
        ),
        // Une « photo » illisible : le PDF se fait sans elle.
        photo: Uint8List.fromList(utf8.encode('pas une image')),
      );
      expect(utf8.decode(bytes.sublist(0, 5)), '%PDF-');
      // Plusieurs pages (le contenu ne tient pas sur une seule).
      expect(
        RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(bytes)).length,
        greaterThan(1),
      );
    },
  );
}
