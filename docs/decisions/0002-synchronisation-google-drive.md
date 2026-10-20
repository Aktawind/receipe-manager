# 0002 — Synchronisation via un dossier Google Drive

*Date : 2026-10-20 · Statut : acceptée (mise en œuvre en 0.4)*

## Contexte
Synchroniser le téléphone et la tablette, sans serveur à maintenir, dans un dossier Google Drive
dédié contenant les recettes et les photos. La synchro doit être très rapide.

## Décision

### Accès
- Connexion Google avec le droit **`drive.file`** : l'app ne voit **que** les fichiers qu'elle a
  créés. Ce droit n'est pas classé « sensible » par Google, donc pas d'audit de sécurité.
- L'écran de consentement OAuth devra être passé en mode « Production ». En mode « Test », Google
  déconnecte l'app tous les 7 jours.
- La variante de test (`.dev`) utilise un **autre dossier** (« Recettes (test) ») pour ne jamais
  mélanger les données de test avec les vraies.

### Organisation du dossier
```
Recettes/
  format.json                 version du format, informations générales
  recipes/<uuid>.json         une recette par fichier
  <type>/<uuid>.json          idem pour catégories, collections, listes, planning…
  media/<sha256>.jpg          photos, nommées par leur empreinte (jamais modifiées)
  media/thumbs/<sha256>.jpg   miniatures
```
Le contenu des fichiers JSON est **le même format que l'export ZIP** (`docs/FORMAT_EXPORT.md`) :
un seul format à maintenir, lisible par un humain.

### Pourquoi c'est rapide
- **Envoi** : seules les entités marquées « modifiées » localement partent, en parallèle. Les
  identifiants des fichiers Drive sont gardés en cache, donc pas de recherche avant l'envoi.
- **Réception** : l'API *Changes* de Drive renvoie uniquement ce qui a changé depuis le dernier
  jeton. Aucun parcours du dossier : une synchro sans changement = 1 requête.
- **Photos** : nommées par leur empreinte, donc envoyées une seule fois ; jamais renvoyées pour
  une simple modification de texte. Compressées avant l'envoi.
- Synchro déclenchée à l'ouverture, quelques secondes après une modification, et en arrière-plan
  (WorkManager).

### Conflits
- Chaque entité porte une horloge logique hybride (date + compteur + appareil) qui ordonne les
  modifications de façon fiable, même si les horloges des appareils sont décalées.
- Règle : la modification la plus récente l'emporte, entité par entité. La version écartée n'est
  jamais perdue : elle est conservée dans l'historique et signalée.
- Les suppressions sont propagées par des marqueurs (« pierres tombales ») conservés, pour qu'une
  recette supprimée ne réapparaisse pas depuis un appareil resté hors ligne.

## Alternatives écartées
- **Une seule grosse base envoyée sur Drive** : simple, mais lente et sans gestion fine des conflits.
- **Serveur dédié** (Firebase, Supabase) : vrai temps réel, mais un service tiers en plus de Drive,
  alors que la demande est un dossier Drive.
- **Dossier caché `appDataFolder`** : tes données ne seraient pas visibles dans ton Drive.
