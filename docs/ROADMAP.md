# Roadmap

Toutes les fonctionnalités de [fonctionnalites.md](fonctionnalites.md), réparties en versions
que tu peux installer et tester toi-même. On ne passe à la version suivante qu'après ta validation.

**Légende** : ⬜ à faire · 🟨 en cours · 🟦 à tester par toi · ✅ validée (mergée sur `main` et taguée)

| Version | Thème | Statut |
|---|---|---|
| [0.0](#00--fondations) | Fondations | ✅ |
| [0.1](#01--saisir-ses-recettes-et-les-sauvegarder) | Saisir ses recettes et les sauvegarder | ✅ |
| [0.2](#02--import-recipe-keeper-et-recette-complète) | Import Recipe Keeper et recette complète | 🟦 |
| [0.3](#03--organisation-et-classement) | Organisation et classement | ⬜ |
| [0.4](#04--synchronisation-google-drive) | Synchronisation Google Drive | ⬜ |
| [0.5](#05--recherche-et-filtres) | Recherche et filtres | ⬜ |
| [0.6](#06--portions-quantités-et-conversions) | Portions, quantités et conversions | ⬜ |
| [0.7](#07--mode-cuisine-et-suivi-des-recettes) | Mode cuisine et suivi des recettes | ⬜ |
| [0.8](#08--import-depuis-internet-et-depuis-du-texte) | Import depuis Internet et depuis du texte | ⬜ |
| [0.9](#09--import-depuis-photos-et-documents) | Import depuis photos et documents | ⬜ |
| [0.10](#010--listes-de-courses) | Listes de courses | ⬜ |
| [0.11](#011--planning-des-repas) | Planning des repas | ⬜ |
| [0.12](#012--accueil-statistiques-partage-et-export) | Accueil, statistiques, partage et export | ⬜ |
| [1.0](#10--stabilisation--remplace-recipe-keeper) | Stabilisation : remplace Recipe Keeper | ⬜ |
| [1.1 → 1.6](#après-la-10--fonctions-différenciantes) | Fonctions différenciantes et foyer partagé | ⬜ |

Roadmap validée le 2026-10-21. L'ordre est pensé pour que tu puisses **utiliser l'app au quotidien le
plus tôt possible** (dès la 0.2 avec tes recettes Recipe Keeper) et ne jamais risquer tes données
(sauvegarde dès la 0.1, synchronisation en 0.4). On peut permuter les versions après la 0.4 selon
tes priorités.

---

## 0.0 — Fondations

Le squelette de l'application et toute la chaîne de fabrication.

- Projet Flutter Android, Android 7 (API 24) minimum → ~97 % des appareils, cible Android 16
- Navigation par onglets : barre du bas sur téléphone, rail latéral sur tablette
- Adaptation à l'orientation de l'écran
- Thème clair, sombre et automatique, construit sur ta palette (contrastes vérifiés par des tests)
- Structure de traduction (français ; anglais ajoutable sans toucher au code des écrans)
- Deux applications installables côte à côte : **Recettes** (au quotidien) et **Recettes (test)**
- CI GitHub : analyse + tests à chaque modification, APK de test publié automatiquement,
  release signée publiée à chaque tag
- Tests automatisés dès le départ

**À tester** : installer l'APK de test, naviguer entre les onglets, changer de thème,
tourner l'écran, essayer sur la tablette.

## 0.1 — Saisir ses recettes et les sauvegarder

Premier usage réel : créer des recettes sans jamais risquer de les perdre.

*Création et édition*
- Créer, modifier, dupliquer, supprimer une recette (suppression → corbeille, restaurable 30 jours)
- Enregistrement automatique des modifications (pas de bouton « Enregistrer » à oublier)
- Titre, description (champ long), photo principale carrée (appareil photo ou galerie, compressée)
- Source (texte libre ou lien cliquable, y compris vidéo), date d'ajout automatique
- Notes personnelles (un seul champ « Notes »)
- Nombre de portions
- Temps de préparation, de cuisson et de repos
- Nombre de fois réalisée (compteur)

*Ingrédients*
- **Coller toute la liste d'un coup** (depuis un site ou une IA), une ligne par ingrédient, analysée automatiquement
- Nom, quantité, unité (liste d'unités courantes + saisie libre)
- Ingrédient facultatif
- Ingrédients sans quantité précise (« une pincée », « selon le goût »)
- Groupes d'ingrédients (« Pour la pâte », « Pour la sauce »)

*Étapes*
- **Coller toute la préparation d'un coup**, numérotée ou non ; titres de parties (« Biscuit », « Montage »)

*Consultation*
- Liste des recettes (vue liste et vue grille), fiche recette soignée (grande photo, temps, ingrédients en deux colonnes, étapes numérotées), recherche simple par titre

*Données et sauvegarde*
- Base de données locale, fonctionnement 100 % hors ligne
- Modèle de données versionné, migrations testées, identifiants stables (prêt pour la synchro)
- Validation des données saisies
- **Export complet** en ZIP (données JSON + photos) vers le dossier de ton choix ou en partage
- **Import** de ce ZIP (fusion ou remplacement), avec validation et retour arrière en cas d'échec
- Sauvegarde automatique interne avant chaque migration de données
- Format d'échange documenté (`docs/FORMAT_EXPORT.md`)
- Autorisations caméra et stockage

**À tester** : saisir une dizaine de vraies recettes, exporter, désinstaller l'app de test,
la réinstaller, réimporter : tout doit être là, photos comprises.

## 0.2 — Import Recipe Keeper et recette complète

Objectif : retrouver toute ta bibliothèque et pouvoir lâcher Recipe Keeper pour la consultation.

*Import Recipe Keeper* (j'aurai besoin de ton export à ce moment-là)
- Import du ZIP d'export : titres, ingrédients, étapes, photos, catégories, notes, portions,
  temps, source, favoris, notes en étoiles, et tout ce que le format contient
- Analyse des lignes d'ingrédients (« 200 g de farine » → quantité / unité / nom)
- Détection des doublons à l'import, rapport d'import (ce qui a été importé, ce qui pose problème)

*Recette complète*
- Plusieurs photos, liens vers des vidéos
- Mise en forme du texte des étapes (gras, italique, listes)
- Matériel nécessaire, conseils
- Substitutions possibles pour un ingrédient
- Ingrédients composés : lier une autre recette (pâte, sauce préparée à l'avance)
- Favoris : ajouter, retirer
- Note de 1 à 5 étoiles
- Statut : à tester / validée / à améliorer

*Avancement* : la 0.2 se livre en deux étapes de test.
- **Étape 1** : import Recipe Keeper (ton export : 327 recettes, 348 photos) ; les
  champs sont repris tels quels (favori, statut « à tester », type de plat, catégorie,
  collections, photos supplémentaires, recettes liées) et s'affichent sur la fiche. Les notes
  en étoiles de Recipe Keeper ne sont pas reprises (décision du 2026-10-28). Validée le
  2026-10-28.
- **Étape 2 (en test)** : tout ce qui se saisit à la main (étoiles, statut, plusieurs photos, liens
  vidéo, étapes mises en forme, matériel, substitutions, choix des recettes liées). Les
  « conseils » restent dans les Notes (champ unique, décision de la 0.1).

**À tester** : importer toute ta bibliothèque Recipe Keeper et vérifier un échantillon de recettes.

## 0.3 — Organisation et classement

- Catégories : Entrées, Plats, Desserts, Boissons, Pains, Sauces par défaut ; sous-catégories ;
  catégories personnalisées (nom, icône, couleur) ; fusion des doublons
- Collections personnalisées (Noël, À tester, Goûters de la famille…) : une recette dans
  plusieurs collections, ordre des recettes personnalisable
- Étiquettes : Rapide, Économique, Végétarien, Batch cooking par défaut ; personnalisées ;
  fusion des doublons
- Classements complémentaires : origine culinaire, type de repas, occasion, saison
- Accès rapide aux favoris
- Recettes récemment consultées, récemment ajoutées
- Vues liste, grille et cartes ; affichage avec ou sans photos

**À tester** : ranger ta bibliothèque, créer tes collections, vérifier les fusions.

## 0.4 — Synchronisation Google Drive

Téléphone et tablette à jour l'un avec l'autre, et une sauvegarde permanente dans ton Drive.
Détails techniques : [décision 0002](decisions/0002-synchronisation-google-drive.md).

- Connexion à ton compte Google, écran d'explication et consentement avant
- Un dossier dédié et lisible dans ton Drive : une recette = un fichier, plus les photos
- **Synchronisation incrémentale** : seul ce qui a changé circule ; chaque photo n'est envoyée
  qu'une fois
- Synchro à l'ouverture, après chaque modification et en arrière-plan
- Modifications hors ligne mises en file d'attente puis envoyées au retour du réseau
- Résolution des conflits (même recette modifiée sur les deux appareils), sans perte : la
  version écartée reste dans l'historique
- Sauvegarde automatique (fréquence réglable) et restauration
- Réglages : activer/désactiver, état de la synchro, synchro manuelle
- Suppression complète des données (appareil et/ou Drive)
- Identifiants de connexion chiffrés sur l'appareil

**Ce qu'il te faudra faire** : créer un identifiant OAuth dans Google Cloud (gratuit, je te
guiderai pas à pas, ~10 minutes).

**À tester** : modifier sur le téléphone, voir le changement sur la tablette ; modifier en mode
avion puis reconnecter ; modifier la même recette sur les deux appareils.

## 0.5 — Recherche et filtres

- Recherche dans les titres, ingrédients, instructions et notes ; insensible aux accents ;
  tolère les fautes de frappe
- Recherche par ingrédients : tous les ingrédients choisis / au moins un / exclure certains ;
  « ce que j'ai sous la main »
- Filtres combinables : temps total, de préparation, de cuisson ; saison ; matériel disponible ;
  statut ; collection ; catégorie ; étiquettes
- Tri : date d'ajout, durée, nombre de réalisations, note, ordre alphabétique
- Historique des recherches, recherches fréquentes enregistrées
- Performance : index plein texte, listes paginées, chargement progressif des images

## 0.6 — Portions, quantités et conversions

*Ajustement des portions*
- Changer le nombre de portions : raccourcis 2, 4, 6, 8, 12 ou nombre libre
- Recalcul proportionnel, quantités originales et ajustées visibles
- Arrondis intelligents (balance au gramme, cuillères, fractions ½ ¼ ⅓)
- Unités indivisibles (œufs, sachets, boîtes) : arrondi + signalement
- Ajustement séparé par groupe (pâte, garniture…)
- Adapter à un poids final ou à une taille de moule
- Le temps de cuisson n'est pas multiplié (avertissement à la place)
- Avertissements pour la levure, les épices, le sel et les moules
- Signalement des ingrédients à ajuster à la main

*Conversions et unités*
- g, kg, ml, L, cuillères à café / à soupe, tasses (cups), pièces, tranches, gousses, bottes, sachets
- Conversion entre unités compatibles, système métrique ↔ impérial
- Celsius ↔ Fahrenheit, dimensions des moules
- Densités propres aux ingrédients (farine, sucre, beurre…) ; conversion exacte ou dépendant de
  l'ingrédient clairement distinguée
- Réglages : unités par défaut, unité de température, portions par défaut

## 0.7 — Mode cuisine et suivi des recettes

*Mode cuisine*
- Écran qui reste allumé, gros texte, étape par étape, utilisable d'une main
- Actions principales toujours accessibles pendant la cuisine
- Minuteurs lancés depuis une étape (durées repérées dans le texte), plusieurs à la fois,
  notification et sonnerie même app fermée ; autorisation des notifications
- Temps de repos, étapes parallèles (« pendant ce temps… »)
- Cocher les ingrédients et les étapes au fil de l'eau
- Dictée vocale pour la saisie (via le clavier Android)

*Suivi*
- « J'ai fait cette recette » : date, compteur, note, commentaire, photos du résultat
- Approuvée par la famille, préférée du foyer, à refaire prochainement, à tester
- Historique des modifications avec restauration d'une version précédente
- Réglages : notifications activables ou non

## 0.8 — Import depuis Internet et depuis du texte

- Partager une page depuis le navigateur vers l'app (partage Android natif)
- Coller une URL, ou une recette depuis le presse-papiers
- Extraction automatique : titre, ingrédients et quantités, étapes, photo principale, temps,
  portions, commentaires si disponibles (format standard des sites de recettes + règles par site)
- Aperçu et correction avant import, URL source conservée
- Sites incompatibles ou erreurs : message clair et solution de secours (texte à coller)
- Pages protégées (connexion requise) : ouverture dans un navigateur intégré, extraction après
  connexion
- Coller du texte brut → analyse en ingrédients et étapes
- Détection des doublons

## 0.9 — Import depuis photos et documents

- Photographier une recette dans un livre, scanner une fiche papier (recadrage, redressement)
- Capture d'écran, PDF, document texte
- Plusieurs pages pour une même recette
- Reconnaissance du texte (OCR) **sur l'appareil, hors ligne et gratuite** (Google ML Kit)
- Reconnaissance des ingrédients et des étapes, extraction de la photo principale par recadrage
- Correction des erreurs avant import

> ✅ Validé le 2026-10-21 : l'OCR sur l'appareil (ML Kit, hors ligne) est accepté
> ([décision 0004](decisions/0004-sans-ia.md)).

## 0.10 — Listes de courses

- Plusieurs listes (semaine, magasin, événement), réutiliser une ancienne liste
- Ajouter un produit à la main, les ingrédients d'une ou plusieurs recettes
- Fusion des ingrédients identiques, addition des quantités, unités incompatibles séparées
- Quantité à acheter différente de la quantité théorique, format, commentaire
- Cocher, supprimer, déplacer
- Regroupement par rayon (Fruits et légumes, Produits frais, Épicerie, Surgelés…)
- Organisation par magasin, magasins favoris (réglages)
- Exporter, imprimer, partager (texte, PDF)
- Liste partagée entre tes appareils (via la synchro Drive)

## 0.11 — Planning des repas

- Vues jour, semaine, mois ; créneaux petit-déjeuner, déjeuner, goûter, dîner
- Glisser-déposer des recettes, une recette sur plusieurs jours
- Nombre de personnes par repas, repas de toute la famille
- Restes pour le lendemain, repas à préparer à l'avance
- Menus thématiques, semaine type réutilisable, duplication d'un planning
- Vacances et occasions spéciales
- Générer la liste de courses du planning
- **Générateur de menus** (algorithme, sans IA) : temps de préparation, préférences, nombre de
  repas, pas trop de répétitions, temps disponible par jour ; propositions à partir de tes
  recettes, mise en avant des recettes non testées
- Ingrédients à utiliser rapidement (tu les signales, le planning les propose en priorité)
- Réglage : temps maximal habituel de cuisine

## 0.12 — Accueil, statistiques, partage et export

- Tableau de bord d'accueil personnalisable (favoris, récentes, repas du jour, suggestions)
- Raccourcis vers les fonctions fréquentes, personnalisation des couleurs et icônes
- Statistiques : nombre de recettes, par catégorie, par saison, les plus réalisées, les mieux
  notées, jamais testées, dernières consultées, fréquence de réalisation, temps moyen,
  repas planifiés, ingrédients les plus utilisés
- Partager une recette (partage Android natif), l'exporter pour un proche (fichier importable)
- Export PDF, Markdown, impression optimisée
- Lien de partage en lecture seule (via Google Drive), révocation
- Import de fichiers JSON et CSV
- Widgets « recette du jour » et « repas du jour », raccourcis de l'écran d'accueil
- Profil : nom, langue

## 1.0 — Stabilisation : remplace Recipe Keeper

- Accessibilité : lecteur d'écran (TalkBack), tailles de texte, contrastes, navigation au clavier
  (tablette avec clavier)
- Performance vérifiée sur une grosse bibliothèque (plusieurs milliers de recettes)
- Journal des erreurs consultable et exportable (aucun service externe), sauvegardes vérifiées
  (restauration testée automatiquement)
- Formats régionaux (dates, nombres)
- Confidentialité : écran explicatif, consentements, export et suppression des données
- Nom et icône définitifs
- Tes derniers retours

## Après la 1.0 — Fonctions différenciantes

| Version | Contenu |
|---|---|
| 1.1 Cuisine de saison | Calendrier des fruits et légumes de saison (France), suggestions du mois, filtre par produit de saison, collections saisonnières, calendrier annuel des recettes, recettes traditionnelles des fêtes |
| 1.2 Recommandations et assistant (règles, sans IA) | Recettes appréciées, variété des menus, recettes oubliées, recettes de saison ; substitutions (table de substitutions courantes + les tiennes) ; accompagnements (associations par catégorie/étiquette + celles que tu définis) ; aide pour les restes ; **mode improvisation** (ingrédients disponibles, exclusions, suggestions) |
| 1.3 Modes réception et pâtisserie | Quantités pour beaucoup de personnes, rétroplanning d'un repas ; ratios, pourcentages du boulanger, rendement |
| 1.4 Batch cooking | Programme de préparation groupée, ordre optimal et cuissons simultanées (four, plaques), réutilisation des ingrédients entre recettes, stockage des préparations, liste de tâches et planning. Le regroupement des étapes communes sera **semi-automatique** (je propose, tu valides) |
| 1.5 Mode collectionneur | Livres de cuisine, auteurs, éditions, recettes associées à leur livre source |
| 1.6 Foyer partagé | Dossier Drive partagé avec d'autres comptes Google ; droits lecture/modification et révocation via le partage Drive ; recettes, listes et planning partagés ; commentaires ; résolution des conflits |

Plus tard, si besoin : version tablette iPad / ordinateur, traduction anglaise, publication sur le
Play Store.

## Adaptations par rapport à la liste d'origine

| Demande | Adaptation |
|---|---|
| Pas d'IA | Aucune IA générative ni service d'IA en ligne. L'assistant, les substitutions, les recommandations et les menus fonctionnent par règles et algorithmes. |
| Synchronisation « en temps réel » | Sans serveur dédié, Google Drive permet du **quasi temps réel** : quelques secondes après une modification quand l'app est ouverte, plus des synchros en arrière-plan. |
| Regrouper les étapes communes (batch cooking) | Semi-automatique : l'app propose des regroupements, tu valides. |
| API | Pas de serveur, donc pas d'API ; le format d'échange documenté et la synchro Drive jouent ce rôle. |
| Interface ordinateur, langues multiples | Structure prête, mise en œuvre plus tard. |
| Gestion du compte, authentification | Un compte Google uniquement pour la synchro (0.4) ; aucun compte à créer. |
