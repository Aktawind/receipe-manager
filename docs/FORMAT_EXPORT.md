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

- Le champ `version` indique la version du format (actuellement **2**).
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

Lecture d'une version 1 : `notes` et `tips` sont fusionnés (séparés par une ligne vide) ; les
étapes n'ont pas de titre.

## `recettes.json` — version 2

```json
{
  "format": "recettes-backup",
  "version": 2,
  "exportedAt": "2026-10-27T14:30:00.000Z",
  "appVersion": "0.1.0",
  "recipes": [
    {
      "id": "3f2c…",
      "title": "Quiche lorraine",
      "description": "",
      "source": "Livre de mamie, p. 12",
      "notes": "Précuire la pâte 10 min.",
      "servings": 6,
      "prepMinutes": 20,
      "cookMinutes": 35,
      "restMinutes": null,
      "timesCooked": 3,
      "mainPhoto": "8a1b….jpg",
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
| `timesCooked` | entier | 0 par défaut |
| `mainPhoto` | texte ou `null` | nom d'un fichier de `photos/`, sans dossier |
| `createdAt`, `updatedAt`, `deletedAt` | date ISO 8601 UTC | `deletedAt` non nul = dans la corbeille |
| `ingredients[].section` | booléen | vrai = titre de groupe (« Pour la pâte ») |
| `ingredients[].quantity` | nombre ou `null` | `null` = sans quantité précise |
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
