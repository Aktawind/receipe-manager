# CLAUDE.md

Application Android (Flutter) de gestion de recettes de cuisine, pour un usage personnel sur
téléphone et tablette. Nom provisoire : « Recettes ».

## À lire avant de travailler
- `docs/ROADMAP.md` : versions, contenu, statut. Mettre le statut à jour à chaque étape.
- `docs/decisions/` : décisions déjà prises. Ne pas les remettre en cause sans le demander.
- `docs/fonctionnalites.md` : la liste de fonctionnalités d'origine.

## Façon de travailler
- On parle **français** avec la personne qui porte le projet et dans la doc, les messages de commit, les PR
  et l'interface. Le code (identifiants) et ses commentaires techniques sont en anglais, sauf
  docstrings existantes en français : suivre le style du fichier.
- Une version de la roadmap à la fois. On ne commence la suivante qu'après validation.
- Retours de test : GitHub Issues (modèles Bug / Amélioration / Idée).
- Branches : travail sur une branche de fonctionnalité → PR vers `develop` (CI verte obligatoire)
  → à la validation, PR `develop` → `main` puis tag `vX.Y.Z` (voir `docs/decisions/0003-…`).
- Chaque version livrée a ses notes dans `docs/releases/vX.Y.Z.md` (obligatoire pour la release),
  avec une **checklist de test** concrète.
- Pas d'IA dans l'app (`docs/decisions/0004-sans-ia.md`).

## Règles non négociables
- **Ne jamais perdre de données** : toute modification du schéma passe par une migration Drift
  testée ; l'import/export doit rester compatible avec les anciennes versions du format.
- Modèle de données prêt pour la synchro : UUID, date de modification, suppression douce.
- Toute chaîne visible passe par `lib/l10n/app_fr.arb` (jamais de texte en dur dans les widgets).
- Couleurs via `Theme.of(context).colorScheme` uniquement (`docs/design/palette.md`).
- Ne jamais committer de clé de signature (`*.jks`, `key.properties`).
- Ne pas changer `applicationId` (sinon ce n'est plus la même application).
- `android.builtInKotlin=true` (Kotlin intégré d'AGP 9) : après l'ajout d'un plugin, vérifier
  qu'il n'applique pas lui-même `kotlin-android`. La CI vérifie que chaque plugin enregistré est
  présent dans l'APK (`tools/check_apk_plugins.sh`).
- Rien d'asynchrone qui puisse échouer avant `runApp` sans être rattrapé : une erreur à ce
  moment-là laisse l'app figée sur l'écran de lancement (voir `lib/main.dart`).

## Commandes
```bash
flutter pub get            # génère aussi lib/l10n/app_localizations*.dart (non versionnés)
dart format lib test       # la CI refuse le code non formaté
flutter analyze
flutter test
flutter build apk --release --flavor dev --target-platform android-arm64 --split-per-abi
```
Les variantes `dev` et `prod` sont obligatoires pour `flutter build/run` (`--flavor dev`).

## Environnement cloud
- `tools/cloud_setup.sh` installe Flutter (version de `pubspec.yaml`) et le SDK Android ; il est
  lancé par le hook SessionStart de `.claude/settings.json`.
- La compilation APK locale peut échouer à cause des limites de débit de Maven Central (erreur
  429) dans l'environnement cloud : la CI GitHub est alors la référence pour la compilation
  Android. Analyse et tests fonctionnent en local.

## Structure
```
lib/
  main.dart, app.dart
  core/        thème, routage, réglages, widgets communs
  features/    un dossier par fonctionnalité (recipes, planning, shopping, settings…)
  l10n/        traductions (app_fr.arb = modèle)
test/          tests (mêmes dossiers que lib/)
docs/          roadmap, décisions, notes de version, design
.github/       CI (ci.yml), release (release.yml), modèles d'issues et de PR
```
