# 0001 — Flutter, Android, hors ligne d'abord

*Date : 2026-10-20 · Statut : acceptée*

## Contexte
Application personnelle de gestion de recettes, utilisée sur un téléphone et une tablette Android
(Android 15 et 16). Une version PC, iPad ou en anglais n'est pas exclue plus tard.

## Décision
- **Flutter** (un seul code, téléphone et tablette ; ordinateur et iOS possibles plus tard).
- **Android uniquement** pour l'instant. `minSdk` 24 (Android 7.0), soit ~97 % du parc.
- **Hors ligne d'abord** : la base locale est la source de vérité ; le réseau ne sert qu'à la
  synchronisation et aux imports web.
- Base locale **SQLite via Drift** (requêtes typées, migrations testables, recherche plein texte
  FTS5). Ajoutée en 0.1.
- État : **Riverpod**. Navigation : **go_router**. Traductions : **gen-l10n** (fichiers ARB).
- Organisation du code par fonctionnalité : `lib/features/<fonctionnalité>/`, le transversal
  dans `lib/core/`.

## Conséquences pour le modèle de données
Prévu dès la 0.1 pour la synchro (voir 0002) :
- identifiant UUID généré sur l'appareil, jamais réutilisé ;
- date de modification sur chaque entité ;
- suppression « douce » (marqueur `deletedAt`) au lieu d'effacer la ligne ;
- numéro de version du schéma et migrations testées automatiquement.
