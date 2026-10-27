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
  → à la validation, PR `develop` → `main` puis workflow « Release » lancé sur `main` avec le
  numéro (il pose le tag `vX.Y.Z`, voir `docs/decisions/0003-…`). La session cloud ne peut pas
  pousser de tag : passer par ce workflow.
- Chaque version livrée a ses notes dans `docs/releases/vX.Y.Z.md` (obligatoire pour la release),
  avec une **checklist de test** concrète.
- Pas d'IA dans l'app (`docs/decisions/0004-sans-ia.md`).

## Règles non négociables
- **Ne jamais perdre de données** : toute modification du schéma passe par une migration Drift
  testée ; l'import/export doit rester compatible avec les anciennes versions du format
  (`docs/FORMAT_EXPORT.md`).
- Schéma Drift (`lib/data/database.dart`) : après modification, incrémenter
  `latestSchemaVersion`, écrire la migration, puis `dart run build_runner build` et
  `dart run drift_dev make-migrations` (instantané dans `drift_schemas/`, tests générés dans
  `test/data/generated_migrations/`). Le code généré (`*.g.dart`, `database.steps.dart`) est
  versionné. Chaque migration a un test avec de vraies données (modèle : `test/data/migration_v2_test.dart`)
  et une évolution du format de sauvegarde (`BackupFormat.currentVersion`) en garde la lecture de l'ancien.
- Les listes d'ingrédients et la préparation se saisissent en un seul champ de texte, analysé par
  `IngredientText` et `StepText` (`lib/domain/`). Toute évolution des règles de lecture s'accompagne
  de tests (`test/domain/`) avec des textes réalistes (sites de cuisine, sorties d'IA).
- Modèle de données prêt pour la synchro : UUID, date de modification, suppression douce.
- Toute chaîne visible passe par `lib/l10n/app_fr.arb` (jamais de texte en dur dans les widgets).
- Les photos de recette s'affichent toujours en carré (`BoxFit.cover`, centré).
- Couleurs via `Theme.of(context).colorScheme` uniquement (`docs/design/palette.md`).
- Ne jamais committer de clé de signature (`*.jks`, `key.properties`).
- Ne pas changer `applicationId` (sinon ce n'est plus la même application).
- `android.builtInKotlin=true` (Kotlin intégré d'AGP 9) : après l'ajout d'un plugin, vérifier
  qu'il n'applique pas lui-même `kotlin-android`. La CI vérifie que chaque plugin enregistré est
  présent dans l'APK (`tools/check_apk_plugins.sh`).
- Rien d'asynchrone qui puisse échouer avant `runApp` sans être rattrapé : une erreur à ce
  moment-là laisse l'app figée sur l'écran de lancement (voir `lib/main.dart`).
- R8 (mode complet, AGP 9) supprime les méthodes appelées seulement par JNI (plugins à bindings
  jnigen, ex. `shared_preferences_android`) : ajouter les règles `-keep` nécessaires dans
  `android/app/proguard-rules.pro` quand on ajoute un tel plugin. Pour trouver les classes
  chargées par nom : `grep -rhoE "'(kotlin|androidx|io/flutter)/[A-Za-z0-9_/$]+'" <plugin>/lib`.
- La CI lance chaque APK sur un émulateur (`tools/smoke_test.sh`) : un APK qui ne démarre pas
  n'est jamais publié. Les tests unitaires ne voient pas ces problèmes (pas de R8 en test).

## Commandes
```bash
flutter pub get            # génère aussi lib/l10n/app_localizations*.dart (non versionnés)
dart run build_runner build   # après une modification de lib/data/database.dart
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

## Tests
- Tests de widgets : `test/helpers/test_app.dart` fournit une app complète sur une base en
  mémoire. Tout appel direct à la base depuis un test de widget passe par `tester.runAsync`
  (sinon le test bloque), et `settle()` remplace `pumpAndSettle()` (qui rend la main avant la fin
  des requêtes). Les listes ne construisent que ce qui est visible : `scrollTo()`.
- Un `SnackBar` avec action reste affiché indéfiniment par défaut : toujours `persist: false`.

## Structure
```
lib/
  main.dart, app.dart
  core/        thème, routage, réglages, formats, widgets communs
  domain/      modèle métier (Recipe, analyse des lignes d'ingrédients)
  data/        base Drift, dépôt, photos, sauvegardes (backup/)
  features/    un dossier par fonctionnalité (recipes, planning, shopping, settings…)
  l10n/        traductions (app_fr.arb = modèle)
test/          tests (mêmes dossiers que lib/)
docs/          roadmap, décisions, notes de version, design
.github/       CI (ci.yml), release (release.yml), modèles d'issues et de PR
```
