# 0005 — Releases directes, sans version de test

*Date : 2026-11-18 · Statut : acceptée*

## Contexte
Depuis la 1.1, l'application est utilisée tous les jours. La variante « Recettes (test) »
(pré-version `develop-latest`) obligeait à installer une deuxième application pour vérifier
chaque correction.

## Décision
- Plus de version de test publiée : la CI ne met plus à jour `develop-latest` (la variante `dev`
  reste compilée et lancée sur émulateur pour la vérification).
- Chaque correction ou évolution validée part directement en release : branche → PR `develop`
  (CI verte) → PR `develop` → `main` → workflow « Release » avec un nouveau numéro
  (correctif : `1.1.1`, `1.1.2`… ; nouvelle version de la roadmap : `1.2.0`).
- Chaque release a ses notes dans `docs/releases/vX.Y.Z.md`, avec la checklist de test : on teste
  sur l'application principale.

## Conséquences
- Une erreur se corrige par une nouvelle release (numéro suivant) ; les données restent protégées
  par les migrations testées et les sauvegardes Drive.
- La pré-version `develop-latest` déjà publiée n'est plus mise à jour.
