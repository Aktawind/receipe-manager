import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/data/import/web_recipe.dart';

final _source = Uri.parse('https://www.exemple.fr/recettes/quiche.html');

String page(String head, [String body = '']) =>
    '<!doctype html><html><head>$head</head><body>$body</body></html>';

String ldJson(String json) =>
    '<script type="application/ld+json">$json</script>';

void main() {
  test('JSON-LD simple (grand site de recettes)', () {
    final recipe = WebRecipeParser.parse(
      page(
        ldJson('''
{
  "@context": "https://schema.org",
  "@type": "Recipe",
  "name": "Quiche lorraine",
  "description": "La vraie, sans fromage.",
  "image": ["https://img.exemple.fr/quiche.jpg", "https://img.exemple.fr/q2.jpg"],
  "recipeYield": "6 personnes",
  "prepTime": "PT20M",
  "cookTime": "PT45M",
  "totalTime": "PT1H35M",
  "recipeIngredient": ["1 pâte brisée", "200 g de lardons", "3 &oelig;ufs", "20 cl de cr&egrave;me fra&icirc;che"],
  "recipeInstructions": [
    {"@type": "HowToStep", "text": "Préchauffer le four à 180 °C."},
    {"@type": "HowToStep", "text": "Faire revenir les lardons."},
    {"@type": "HowToStep", "text": "Battre les œufs et la crème, verser sur la pâte, cuire 45 min."}
  ]
}'''),
      ),
      _source,
    )!;
    expect(recipe.title, 'Quiche lorraine');
    expect(recipe.description, 'La vraie, sans fromage.');
    expect(recipe.imageUrl.toString(), 'https://img.exemple.fr/quiche.jpg');
    expect(recipe.servings, 6);
    expect(recipe.servingsUnit, '');
    expect(recipe.prepMinutes, 20);
    expect(recipe.cookMinutes, 45);
    expect(recipe.restMinutes, 30);
    expect(recipe.ingredients, [
      '1 pâte brisée',
      '200 g de lardons',
      '3 œufs',
      '20 cl de crème fraîche',
    ]);
    expect(recipe.steps, hasLength(3));
    expect(recipe.steps.last, contains('cuire 45 min'));
  });

  test('JSON-LD dans un @graph (blog WordPress), sections et image objet', () {
    final recipe = WebRecipeParser.parse(
      page(
        ldJson('''
{"@context":"https://schema.org","@graph":[
  {"@type":"WebPage","name":"Mon blog"},
  {"@type":["Recipe"],"name":"Bûche de Noël","recipeYield":["8","8 parts"],
   "image":{"@type":"ImageObject","url":"/wp-content/buche.jpg"},
   "recipeIngredient":["4 œufs","100 g de sucre"],
   "recipeInstructions":[
     {"@type":"HowToSection","name":"Biscuit","itemListElement":[
       {"@type":"HowToStep","text":"Monter les blancs."},
       {"@type":"HowToStep","text":"Cuire 10 min."}]},
     {"@type":"HowToSection","name":"Montage","itemListElement":[
       {"@type":"HowToStep","text":"Rouler le biscuit."}]}
   ],
   "cookTime":"PT10M"}
]}'''),
      ),
      _source,
    )!;
    expect(recipe.title, 'Bûche de Noël');
    expect(recipe.servings, 8);
    expect(
      recipe.imageUrl.toString(),
      'https://www.exemple.fr/wp-content/buche.jpg',
    );
    expect(recipe.steps, [
      'Biscuit :',
      'Monter les blancs.',
      'Cuire 10 min.',
      'Montage :',
      'Rouler le biscuit.',
    ]);
  });

  test('instructions en un seul texte, rendement en pièces', () {
    final recipe = WebRecipeParser.parse(
      page(
        ldJson(
          '''
[{"@type":"Recipe","name":"Blinis","recipeYield":"24 blinis",
  "recipeIngredient":"250 g de farine",
  "recipeInstructions":"<p>Mélanger la farine et le lait.</p><p>Cuire 1 minute de chaque côté.</p>"}]''',
        ),
      ),
      _source,
    )!;
    expect(recipe.servings, 24);
    expect(recipe.servingsUnit, 'blinis');
    expect(recipe.ingredients, ['250 g de farine']);
    expect(recipe.steps, [
      'Mélanger la farine et le lait.',
      'Cuire 1 minute de chaque côté.',
    ]);
  });

  test('un JSON-LD cassé ne bloque pas les suivants', () {
    final recipe = WebRecipeParser.parse(
      page(
        '${ldJson('{"@type": "Organization", oups')}'
        '${ldJson('{"@type": "Recipe", "name": "Crêpes", "recipeIngredient": ["lait"]}')}',
      ),
      _source,
    );
    expect(recipe?.title, 'Crêpes');
  });

  test('microdonnées', () {
    final recipe = WebRecipeParser.parse(
      page('', '''
<div itemscope itemtype="https://schema.org/Recipe">
  <h1 itemprop="name">Gratin dauphinois</h1>
  <img itemprop="image" src="/img/gratin.jpg">
  <meta itemprop="cookTime" content="PT1H">
  <span itemprop="recipeYield">4</span>
  <ul>
    <li itemprop="recipeIngredient">1 kg de pommes de terre</li>
    <li itemprop="recipeIngredient">50 cl de lait</li>
  </ul>
  <div itemprop="recipeInstructions"><ol><li>Éplucher.</li><li>Cuire 1 h.</li></ol></div>
</div>'''),
      _source,
    )!;
    expect(recipe.title, 'Gratin dauphinois');
    expect(recipe.imageUrl.toString(), 'https://www.exemple.fr/img/gratin.jpg');
    expect(recipe.cookMinutes, 60);
    expect(recipe.servings, 4);
    expect(recipe.ingredients, ['1 kg de pommes de terre', '50 cl de lait']);
    expect(recipe.steps, ['Éplucher.', 'Cuire 1 h.']);
  });

  test('page sans recette', () {
    expect(
      WebRecipeParser.parse(
        page('<title>Accueil</title>', '<p>Bonjour</p>'),
        _source,
      ),
      isNull,
    );
  });
}
