# Roadmap

Toutes les fonctionnalités de [fonctionnalites.md](fonctionnalites.md), réparties en versions
que tu peux installer et tester toi-même. On ne passe à la version suivante qu'après ta validation.

**Légende** : ⬜ à faire · 🟨 en cours · 🟦 à tester par toi · ✅ validée (mergée sur `main` et taguée)

| Version | Thème | Statut |
|---|---|---|
| [0.0](#00--fondations) | Fondations | ✅ |
| [0.1](#01--saisir-ses-recettes-et-les-sauvegarder) | Saisir ses recettes et les sauvegarder | ✅ |
| [0.2](#02--import-recipe-keeper-et-recette-complète) | Import Recipe Keeper et recette complète | ✅ |
| [0.3](#03--organisation-et-classement) | Organisation et classement | ✅ |
| [0.4](#04--synchronisation-google-drive) | Synchronisation Google Drive | ✅ |
| [0.5](#05--recherche-et-filtres) | Recherche et filtres | ✅ |
| [0.6](#06--portions-quantités-et-conversions) | Portions, quantités et conversions | ✅ |
| [0.7](#07--mode-cuisine) | Mode cuisine | ✅ |
| [0.8](#08--import-depuis-internet-et-depuis-du-texte) | Import depuis Internet et depuis du texte | ✅ |
| [0.9](#09--import-depuis-photos-et-documents) | Import depuis photos et documents | ✅ |
| [0.10](#010--listes-de-courses) | Listes de courses | 🟨 |
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
- **Étape 2** (validée le 2026-10-29) : tout ce qui se saisit à la main (étoiles, statut, plusieurs photos, liens
  vidéo, étapes mises en forme, matériel, substitutions, choix des recettes liées). Les
  « conseils » restent dans les Notes (champ unique, décision de la 0.1).

**À tester** : importer toute ta bibliothèque Recipe Keeper et vérifier un échantillon de recettes.

## 0.3 — Organisation et classement

- Catégories : Entrées, Plats, Desserts, Boissons, Pains, Sauces par défaut ; sous-catégories ;
  catégories personnalisées (nom, icône, couleur) ; fusion des doublons
- Collections personnalisées (Noël, À tester, Goûters de la famille…) : une recette dans
  plusieurs collections, ordre des recettes personnalisable
- ~~Étiquettes~~ : abandonnées le 2026-10-29, une collection fait le même travail (« Végétarien »,
  « Pâques », « Rapide »…) et se combine avec les autres au filtrage
- Classements complémentaires : origine culinaire, saison (le type de repas viendra avec le
  planning, 0.11 ; les occasions sont des collections)
- Accès rapide aux favoris
- Tri par consultation et par ajout (pas de filtre « récentes », retiré le 2026-11-01)
- Vues liste, grille et cartes (photos toujours affichées)

*Décisions du 2026-10-29* : les types de plat de Recipe Keeper (Plat, Dessert, Goûter…) deviennent
les catégories par défaut et leurs catégories les sous-catégories ; les noms qui se ressemblent sont
fusionnés ; Printemps, Été, Automne et Hiver deviennent des saisons, avec « Toute saison » quand la
saison n'a pas d'importance (les quatre ensemble à l'import).

*Avancement* : deux étapes de test.
- **Étape 1** : classement commun (catégories et sous-catégories, collections, étiquettes, origine,
  type de repas, occasion, saison) géré dans Réglages → Classement, choisi dans le formulaire,
  affiché sur la fiche ; conversion de tes recettes et de l'import Recipe Keeper.
- **Étape 2** : filtrer la liste par classement (listes à cocher), favoris, récemment consultées et
  ajoutées, vues liste / grille / cartes, ordre personnalisé d'une collection.
- **Retours du 2026-10-29** : quatre familles seulement (catégories, saisons, collections, origine),
  classement rangé dans « À propos », filtres en listes, accès rapides dans le filtre, photos
  toujours affichées.

*Validée le 2026-10-30.*

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

**Ce qu'il te faudra faire** : déclarer l'application dans la Google Cloud Console avec ton
compte (gratuit, je te guiderai pas à pas, ~10 minutes). Pour toi, la connexion se résume à
choisir ton compte Google et à accepter l'accès au dossier.

*Décisions du 2026-10-30* : synchro automatique (à l'ouverture et après chaque modification) avec
un bouton « Synchroniser maintenant » en plus. Les photos gardent leur nom de fichier (unique et
jamais modifié, comme une empreinte) au lieu d'un `sha256`.

*Avancement* : trois étapes.
- **Étape 1 (faite, invisible)** : le moteur de synchro, sans Google — suivi de ce qui a changé
  (base v9), un fichier par élément dans le format des sauvegardes, conflits, suppressions, photos
  envoyées une seule fois, horloge corrigée des écarts entre appareils. Testé sur deux appareils
  simulés.
- **Étape 2 (validée le 2026-11-02)** : filtre de durée (total, préparation, cuisson : « au plus X min »), matériel
  (seules restent les recettes qui utilisent tous les matériels cochés), recherche par ingrédients
  (avec tous / au moins un / sans), tris par durée et par note, interrupteur « Favoris », bouton
  « Effacer les filtres » sous le compteur ; champ de recherche qui annonce qu'il cherche partout ;
  en-tête du filtre fixe pendant qu'on fait défiler. « Ce que j'ai sous la main » a été essayé puis
  retiré le 2026-11-02 (les filtres par ingrédients font le travail).
- **Étape 3 (validée le 2026-11-03)** : recherches enregistrées (texte cherché, filtres et tri sous un nom, en
  haut du filtre ; un appui les applique), images qui apparaissent en fondu une fois décodées. Les
  listes ne construisaient déjà que ce qui est visible ; l'index de recherche est en mémoire (pas
  besoin d'index SQLite plein texte pour quelques centaines de recettes).
- Écarté : tri par nombre de réalisations (compteur retiré en 0.4), étiquettes (retirées en 0.3).

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

*Avancement* : trois étapes.
- **Étape 1 (validée le 2026-11-03)** : changer les portions sur la fiche (− / +, raccourcis 2, 4,
  6, 8, 12, nombre libre), quantités recalculées, arrondis de
  cuisine (gramme, quart de cuillère, demi-citron), œufs et sachets entiers avec la quantité
  exacte, « à goûter » / « à doser » / « à ajuster » sur les lignes concernées. Le choix revient à
  la recette en quittant la fiche. Retours : un simple rappel « Quantités recalculées » sous le
  nombre de personnes (plus de cadre d'avertissements), plus de bouton « Ajuster » (les − / +
  suffisent ; une recette sans nombre de personnes ne se recalcule pas), plus de « au lieu de »
  à côté des quantités recalculées.
- **Étape 2 (retirée le 2026-11-03)** : conversions d'unités et de températures, réglages
  d'unités et de portions par défaut. Essayées puis retirées : pas utiles. Une recette collée garde
  ses unités telles qu'écrites.
- **Étape 3 (abandonnée le 2026-11-03)** : ajustement par groupe d'ingrédients, poids final,
  taille de moule — pas nécessaires.

## 0.7 — Mode cuisine

- Un bouton « Mode cuisine » sur la fiche, toujours visible
- L'écran reste allumé tant que le mode cuisine est ouvert
- Ingrédients et préparation en grand (onglets sur téléphone, côte à côte sur tablette), pour le
  nombre de personnes choisi sur la fiche
- Minuteurs lancés depuis une étape (durées repérées dans le texte), plusieurs à la fois,
  notification et sonnerie même app fermée ; autorisation des notifications

*Décisions du 2026-11-03* : pas de cases à cocher pour les ingrédients ni les étapes ; le suivi
(« J'ai fait cette recette », historique des modifications, approuvée par la famille…) est retiré
de la feuille de route.

*Avancement* : deux étapes.
- **Étape 1 (validée le 2026-11-03)** : bouton « Mode cuisine », écran allumé, ingrédients et
  préparation en grand. L'écran allumé passe par un petit canal Android maison (`MainActivity`),
  sans nouveau plugin. Retour : plus de rappel « Quantités recalculées » sur la fiche (les
  quantités reviennent à celles de la recette en la quittant).
- **Étape 2 (validée le 2026-11-04)** : minuteurs. Les durées de chaque étape (« 20 minutes », « 1 h 30 »,
  « une demi-heure ») deviennent des boutons ; minuteur libre depuis la barre du haut ; plusieurs
  à la fois en bas de l'écran (pause, une minute de plus, arrêt). À la fin, notification avec la
  sonnerie d'alarme, répétée jusqu'à ce qu'on la touche, même app fermée : alarmes Android
  (`TimerAlarms.kt`), là encore sans plugin.
- Retour du 2026-11-04 : texte du mode cuisine un peu plus petit par défaut, et réglable
  (Réglages → Apparence → Texte du mode cuisine : petit, moyen, grand, très grand).

## 0.8 — Import depuis Internet et depuis du texte

- Partager une page depuis le navigateur vers l'app (partage Android natif)
- Coller une URL, ou une recette depuis le presse-papiers
- Extraction automatique : titre, ingrédients et quantités, étapes, photo principale, temps,
  portions, commentaires si disponibles (format standard des sites de recettes + règles par site)
- Aperçu et correction avant import, URL source conservée
- Sites incompatibles ou erreurs : message clair et solution de secours (texte à coller)
- Coller du texte brut → analyse en ingrédients et étapes

*Décisions du 2026-11-04* : pas de navigateur intégré pour les pages protégées, pas de détection
des doublons.

*Avancement* : deux étapes.
- **Étape 1 (validée le 2026-11-04, essayée avec Marmiton)** : adresse saisie, collée (proposée d'office si le presse-papiers en
  contient une) ou partagée depuis le navigateur ; lecture du format standard schema.org/Recipe
  (JSON-LD, y compris dans un `@graph`, et microdonnées) ; aperçu (photo, titre, portions, temps,
  ingrédients et étapes tels que l'app les a compris) ; import avec la photo et l'adresse en
  source, puis l'éditeur pour corriger ; message clair si le site est injoignable, refuse la page
  ou n'a pas de recette lisible, avec « Saisir la recette à la main ». Partage reçu par un canal
  Android maison (`MainActivity`, activité en `singleTask`), sans plugin.
- **Étape 2 (validée le 2026-11-04, après deux retours sur de vraies réponses d'IA)** : coller le texte d'une recette entière, surtout les réponses d'IA
  (Markdown, emojis, phrase d'introduction) : titre, description, personnes (ou pièces), temps de
  préparation et de cuisson, ingrédients avec leurs groupes, étapes avec leurs parties, astuces
  dans les notes ; sans rubriques, les lignes avec une quantité deviennent des ingrédients. Le
  presse-papiers est proposé d'office, et un texte partagé depuis une autre app (une IA) ouvre
  l'import du texte. Décision du 2026-11-04 : pas de règles par site ni de commentaires pour
  l'instant (un site qui ne passe pas sera signalé).

## 0.9 — Import depuis photos et documents

- Photographier une recette dans un livre, scanner une fiche papier (recadrage, redressement)
- Capture d'écran (image de la galerie)
- Plusieurs pages pour une même recette
- Reconnaissance du texte (OCR) **sur l'appareil, hors ligne et gratuite** (Google ML Kit)
- Reconnaissance des ingrédients et des étapes, photo de la recette recadrée sur la page ou prise
  à part
- Correction des erreurs avant import

> ✅ Validé le 2026-10-21 : l'OCR sur l'appareil (ML Kit, hors ligne) est accepté
> ([décision 0004](decisions/0004-sans-ia.md)).

*Décisions du 2026-11-04* : pas de PDF ni de documents (Word…) pour l'instant ; la photo du plat
se recadre sur la page scannée **ou** se prend à part ; le scanner de pages de Google Play
(services Google Play du téléphone) est accepté.

*Livré en 0.9.0 (2026-11-05)* : onglet « Photo » de l'import : scanner de pages de Google Play
(cadrage et redressement automatiques, jusqu'à 5 pages, image de la galerie) ou « Prendre une
photo » / « Choisir une image », lecture du texte sur l'appareil (ML Kit, modèle latin inclus),
puis **lecture de la mise en page** (`OcrLayout`) : page tournée remise droite, titre, colonnes,
légendes des photos d'ingrédients et leurs quantités, gros numéros d'étapes, listes « + », temps
en pictogrammes, astuces ; le texte obtenu arrive dans l'onglet « Texte » pour être corrigé.
Retour du 2026-11-04 (Galaxy Tab S9) : le scanner est appelé directement (`PageScanner.kt`,
téléchargement du module à la demande, erreur détaillée).

*Décision du 2026-11-05* : pas de photo du plat prise sur le livre ni à part à l'import (les
photos des livres rendent mal) ; l'étape 2 est abandonnée.

## 0.10 — Listes de courses

- Plusieurs listes (semaine, magasin, événement), réutiliser une ancienne liste
- Ajouter un produit à la main, les ingrédients d'une ou plusieurs recettes — **y compris ceux des
  recettes liées** (la pâte d'une quiche, la sauce d'un plat) : une ligne d'ingrédient liée à une
  recette ajoute les ingrédients de cette recette, proportionnellement à la quantité demandée
  (demande du 2026-10-29)
- Fusion des ingrédients identiques, addition des quantités, unités incompatibles séparées
- Quantité à acheter différente de la quantité théorique, format, commentaire
- Cocher, supprimer, déplacer
- Regroupement par rayon (Fruits et légumes, Produits frais, Épicerie, Surgelés…)
- Exporter, imprimer, partager (texte, PDF)
- Liste partagée entre tes appareils (via la synchro Drive)

*Décisions du 2026-11-05* :
- **dictée** des produits au micro (reconnaissance vocale d'Android) ;
- singulier et pluriel fusionnés (« jambon » / « jambons ») ;
- les recettes d'origine s'affichent en petit sous chaque produit ;
- sel, poivre, eau… proposés mais décochés à l'ajout d'une recette ;
- produits cochés dans « Dans le panier », barrés, avec « Retirer les cochés » ;
- **rayons modifiables dans les réglages** ; un produit rangé à la main retourne dans le même rayon
  ensuite (ex. « sauce soja » → Épicerie salée) ;
- **pas de magasins** ;
- partage en texte groupé par rayon, et **PDF / impression tenant sur une feuille A4** ;
- pas de partage avec d'autres personnes (le partage et la synchro suffisent), pas de placard ;
- la liste générée depuis le planning viendra avec la 0.11.

*Avancement* : quatre étapes.
- **Étape 1 (à tester)** : listes (créer, renommer, supprimer, réutiliser), produits ajoutés en une
  ligne (« 2 kg de pommes de terre », « Beurre 50 g ») ou dictés, avec les produits déjà achetés en
  suggestion ; fusion du même produit (quantités additionnées) ; cocher → « Dans le panier »,
  « Retirer les cochés » ; modifier (quantité, ce que j'achète, format, commentaire), déplacer,
  glisser pour retirer. Base v10, sauvegarde v9, synchro Drive des listes et des rayons.
- **Étape 2** : « Ajouter aux courses » depuis une recette (et plusieurs recettes d'un coup), recettes
  liées, recettes d'origine.
- **Étape 3** : rayons (rangement automatique, réglages, mémoire par produit).
- **Étape 4** : partage en texte, PDF et impression sur une page A4.

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
