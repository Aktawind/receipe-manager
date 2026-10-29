# Format des sauvegardes

Une sauvegarde est un fichier **ZIP** qui contient toutes les recettes, corbeille comprise, avec
leurs photos. C'est le même format qui servira à la synchronisation Google Drive (0.4).

```
recettes-2026-10-27-1430.zip
├── recettes.json        les données
└── photos/
    └── <nom>.jpg        une photo par fichier, nom référencé dans recettes.json
```

## Règles de compatibilité

- Le champ `version` indique la version du format (actuellement **7**).
- Toute version de l'application sait lire **toutes les versions précédentes** du format.
- Une sauvegarde d'une version **plus récente** que l'application est refusée, sans rien
  modifier (message : « Mets l'application à jour »).
- Un fichier invalide est refusé en entier : rien n'est importé partiellement.
- Toute évolution du format incrémente `version` et met à jour ce document.

## Historique des versions

| Version | Application | Changements |
|---|---|---|
| 1 | 0.1.0 | Première version : champs `notes` et `tips` (« Astuces ») |
| 2 | 0.1.0 (corrigée) | `tips` supprimé ; son contenu est fusionné dans `notes`. Titre optionnel `title` sur les étapes |
| 3 | 0.2.0 | Ajout de `favorite`, `rating`, `status`, `course`, `category`, `collections`, `extraPhotos`, `linkedRecipes` |
| 4 | 0.2.0 | Ajout de `servingsUnit` (« 12 blinis ») |
| 5 | 0.2.0 (test) | Ajout de `equipment` (noms), `videoLinks` et `ingredients[].substitutes` |
| 6 | 0.2.0 | Liste commune du matériel (`equipment` du document, `equipment` des recettes = identifiants) ; recettes liées dans les ingrédients (`ingredients[].linkedRecipe`), `linkedRecipes` disparaît |
| 7 | 0.3.0 | Classement commun : `labels` (document) et `labels` (recettes = identifiants) remplacent `course`, `category` et `collections` |

Lecture d'une version 6 (et 3 à 5) : `course`, `category` et `collections` en texte libre deviennent
le classement commun. Le type de plat devient la catégorie (« Plat » → « Plats »), la catégorie la
sous-catégorie ; les noms qui se ressemblent sont fusionnés (« Gâteau »/« Gâteaux », « Riz »/« Riz et
céréales ») ; les collections Printemps, Été, Automne, Hiver deviennent des saisons (les quatre
ensemble = « Toute saison ») ; toute autre collection reste une collection.

Lecture d'une version 5 (et 3, 4) : le matériel écrit en noms dans les recettes devient la liste
commune (un même nom, à la casse et aux accents près, donne un seul matériel, avec un identifiant
calculé à partir du nom) ; `linkedRecipes` devient des lignes d'ingrédients (une ligne qui porte
déjà le nom de la recette liée devient le lien, sinon une ligne est ajoutée à la fin).

Lecture d'une version 4 : `equipment`, `videoLinks` et `substitutes` sont vides.

Lecture d'une version 3 : `servingsUnit` est vide (des personnes).

Lecture d'une version 2 : les champs ajoutés par la version 3 prennent leur valeur neutre
(pas favori, pas de note, pas de statut, classement vide, aucune photo supplémentaire).

Lecture d'une version 1 : `notes` et `tips` sont fusionnés (séparés par une ligne vide) ; les
étapes n'ont pas de titre.

## `recettes.json` — version 7

```json
{
  "format": "recettes-backup",
  "version": 7,
  "exportedAt": "2026-10-27T14:30:00.000Z",
  "appVersion": "0.1.0",
  "equipment": [
    { "id": "…", "name": "Moule à tarte", "createdAt": "…", "updatedAt": "…", "deletedAt": null }
  ],
  "labels": [
    { "id": "…", "kind": "category", "name": "Viandes", "parentId": "<id de « Plats »>",
      "icon": "restaurant", "color": "caramel", "position": 0,
      "createdAt": "…", "updatedAt": "…", "deletedAt": null }
  ],
  "recipes": [
    {
      "id": "3f2c…",
      "title": "Quiche lorraine",
      "description": "",
      "source": "Livre de mamie, p. 12",
      "notes": "Précuire la pâte 10 min.",
      "servings": 6,
      "servingsUnit": "",
      "prepMinutes": 20,
      "cookMinutes": 35,
      "restMinutes": null,
      "timesCooked": 3,
      "mainPhoto": "8a1b….jpg",
      "extraPhotos": ["c04d….jpg"],
      "favorite": true,
      "rating": 4,
      "status": "validated",
      "equipment": ["<id de « Moule à tarte »>"],
      "labels": ["<id de « Viandes »>", "<id de « Hiver »>"],
      "videoLinks": ["https://youtu.be/…"],
      "createdAt": "2026-10-20T08:00:00.000Z",
      "updatedAt": "2026-10-27T12:00:00.000Z",
      "deletedAt": null,
      "ingredients": [
        { "id": "…", "section": true, "name": "Pour la pâte", "quantity": null,
          "unit": "", "note": "", "optional": false },
        { "id": "…", "section": false, "name": "farine", "quantity": 250,
          "unit": "g", "note": "", "optional": false },
        { "id": "…", "section": false, "name": "sel", "quantity": null,
          "unit": "", "note": "selon le goût", "optional": false }
      ],
      "steps": [
        { "id": "…", "title": "La pâte", "text": "Préparer la pâte." },
        { "id": "…", "title": "", "text": "Étaler et piquer le fond." }
      ]
    }
  ]
}
```

| Champ | Type | Remarque |
|---|---|---|
| `id` | texte | UUID, stable pour toujours (sert à fusionner et synchroniser) |
| `servings`, `*Minutes` | entier ou `null` | |
| `servingsUnit` | texte | ce que compte `servings` (« blinis », « ramequins »), vide = des personnes |
| `timesCooked` | entier | 0 par défaut |
| `mainPhoto` | texte ou `null` | nom d'un fichier de `photos/`, sans dossier |
| `createdAt`, `updatedAt`, `deletedAt` | date ISO 8601 UTC | `deletedAt` non nul = dans la corbeille |
| `extraPhotos` | liste de textes | photos après la principale, noms de fichiers de `photos/` |
| `favorite` | booléen | |
| `labels` (document) | liste d'objets | le classement commun : `kind` (`category`, `collection`, `tag`, `cuisine`, `meal`, `occasion`, `season`), `name`, `parentId` (sous-catégories), `icon`, `color` (clés du thème), `position`, dates ; `deletedAt` non nul = supprimé |
| `labels` (recette) | liste d'`id` | le classement de la recette |
| `rating` | entier 1 à 5 ou `null` | `null` = pas noté |
| `status` | `toTest`, `validated`, `toImprove` ou `null` | |
| `equipment` (document) | liste d'objets | la liste commune du matériel : `id`, `name`, dates ; `deletedAt` non nul = supprimé |
| `equipment` (recette) | liste d'`id` | matériel nécessaire, dans l'ordre d'affichage |
| `videoLinks` | liste de textes | liens vidéo |
| `ingredients[].linkedRecipe` | `id` ou `null` | l'ingrédient est une recette (pâte, sauce) ; `name` est alors son titre. Une recette supprimée depuis n'est simplement plus ouverte |
| `ingredients[].substitutes` | texte | remplaçants possibles (« huile de coco, margarine ») |
| `ingredients[].section` | booléen | vrai = titre de groupe (« Pour la pâte ») |
| `ingredients[].quantity` | nombre ou `null` | `null` = sans quantité précise |
| `steps[].text` | texte | `**gras**` et `*italique*` sont des marqueurs de mise en forme |
| `steps[].title` | texte | titre de la partie (« Biscuit »), vide le plus souvent ; porté par la première étape de la partie |
| `ingredients[].unit` | texte | forme canonique : `g`, `kg`, `ml`, `cl`, `L`, `c. à s.`, `c. à c.`, `pincée`… |

L'ordre des listes `ingredients` et `steps` est l'ordre d'affichage.

## Import

- **Fusionner** : les recettes absentes sont ajoutées ; une recette déjà présente n'est remplacée
  que si sa date `updatedAt` dans le fichier est plus récente. Rien n'est supprimé.
- **Remplacer tout** : toutes les recettes sont supprimées puis remplacées par celles du fichier.
- Dans les deux cas, une **sauvegarde automatique** est écrite juste avant dans le dossier
  interne de l'app (les 5 dernières sont gardées), et l'écriture se fait en une seule
  transaction.
- **Ajouter les absentes** (import Recipe Keeper) : seules les recettes dont l'`id` est inconnu
  sont ajoutées, celles qui existent déjà ne sont jamais modifiées.

## Import depuis Recipe Keeper

Réglages → Importer depuis Recipe Keeper, avec le ZIP produit par Recipe Keeper
(Paramètres → Exporter les recettes). Ce ZIP contient `recipes.html` et un dossier `images/`.

| Recipe Keeper | Recettes |
|---|---|
| `recipeId` | `id` (conservé : réimporter le même fichier n'ajoute rien) |
| nom, source, notes | `title`, `source`, `notes` |
| ingrédients (un paragraphe par ligne) | analysés par `IngredientText` ; un paragraphe en gras ou en majuscules est un titre de groupe |
| préparation | analysée par `StepText` |
| taille de portion | `servings` et `servingsUnit` : « 4 personnes » → 4 ; « 12 blinis » → 12 et « blinis ». Sans nombre (« Une dizaine »), le texte est ajouté en tête des notes (« Quantité : … ») |
| temps de préparation, de cuisson | `prepMinutes`, `cookMinutes` (0 = absent) |
| favori | `favorite` |
| note en étoiles | **non reprise** (choix de la personne qui utilise l'app) |
| catégorie `_A tester` | `status` = `toTest` (et pas une catégorie) |
| type de plat, catégorie, collections | catégorie, sous-catégorie, saisons et collections du classement commun (mêmes règles de fusion que la lecture d'une version 6) |
| photos | `mainPhoto` (la première) et `extraPhotos` |
| recettes liées | lignes d'ingrédients liées (`linkedRecipe`) : le renvoi `[recipe:Nom]` d'une ligne devient le lien, un lien absent du texte est ajouté à la fin de la liste ; dans les notes, le renvoi devient le simple nom |
| valeurs nutritionnelles | ajoutées en texte à la fin des notes |
