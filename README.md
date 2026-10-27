# Recettes

Application Android de gestion de recettes de cuisine : hors ligne, synchronisée via Google Drive,
pensée pour le téléphone et la tablette. *(Nom provisoire.)*

## Installer
- **Version stable** : dernière [release](../../releases/latest), fichier `recettes-X.Y.Z.apk`.
- **Version de test** : [`recettes-test.apk`](../../releases/download/develop-latest/recettes-test.apk)
  (s'installe à côté de la version stable sous le nom « Recettes (test) »).

Android 7.0 minimum. Au premier téléchargement, Android demande d'autoriser l'installation depuis
le navigateur : c'est normal.

## Donner un retour
[Ouvrir un ticket](../../issues/new/choose) : 🐞 Bug, ✨ Amélioration ou 💡 Idée.

## Documentation
- [Roadmap](docs/ROADMAP.md) · [Fonctionnalités souhaitées](docs/fonctionnalites.md)
- [Décisions](docs/decisions/README.md) · [Palette](docs/design/palette.md)
- [Historique des versions](CHANGELOG.md)

## Développement
Flutter 3.47.7 (version fixée dans `pubspec.yaml`).
```bash
flutter pub get && flutter test
flutter run --flavor dev
```
Voir [CLAUDE.md](CLAUDE.md) pour les conventions.
