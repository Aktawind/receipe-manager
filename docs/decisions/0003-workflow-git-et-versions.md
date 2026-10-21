# 0003 — Workflow Git, versions, signature et variantes

*Date : 2026-10-20 · Statut : acceptée*

## Branches
- `main` : uniquement les versions validées, chacune taguée `vX.Y.Z`.
- `develop` : intégration ; chaque envoi produit l'APK de test.
- `claude/…` ou `feature/…` : travail en cours, fusionné dans `develop` par une PR dont la CI est verte.
- Quand une version est validée : PR `develop` → `main`, puis tag sur `main`.

## Numéros de version
- Versions de la roadmap : `0.1` → tag `v0.1.0` ; corrections : `v0.1.1`… La 0.0 est taguée `v0.0.1`.
- Le `versionCode` Android est calculé par la CI à partir du tag :
  `majeur × 1 000 000 + mineur × 1 000 + correctif` (toujours croissant, donc mise à jour possible).
- Versions de test : `versionCode` = numéro de la compilation CI.

## Variantes
| Variante | Identifiant | Nom affiché | Usage |
|---|---|---|---|
| `prod` | `io.github.aktawind.recettes` | Recettes | Releases, usage quotidien |
| `dev` | `io.github.aktawind.recettes.dev` | Recettes (test) | Versions de test (develop, PR) |

Les deux s'installent côte à côte : une version de test ne peut jamais abîmer les vraies données.

## Signature
- Une seule clé de publication, stockée dans les secrets GitHub :
  `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`.
- Une copie de secours est conservée en dehors de GitHub (gestionnaire de mots de passe). **Perdre cette clé = ne plus pouvoir
  mettre à jour l'application installée.**
- Sans secrets, la CI signe les APK de test avec une clé de debug (avertissement). Une release
  sans secrets échoue.

## Rapidité de la CI
- Analyse + tests et compilation de l'APK en parallèle.
- Caches Flutter, pub et Gradle (cache Gradle écrit depuis `develop`/`main`, lu par les PR).
- APK de test compilé pour arm64 uniquement (tous les appareils récents) ; APK universel pour les
  releases.
- Les modifications de documentation seule ne déclenchent pas de compilation.
- Une nouvelle compilation annule la précédente sur la même branche.

## Test de démarrage
Chaque APK (test et release) est installé et lancé sur un émulateur Android (API 35) avant
publication : l'app doit afficher son premier écran sans erreur. Cela ajoute quelques minutes à la
CI, mais évite de publier un APK qui ne démarre pas (les erreurs liées à R8 n'existent qu'en
release et échappent aux tests unitaires).
