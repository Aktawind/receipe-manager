# Palette

Bleu canard et pêche, dans des tons doux (1.0 ; avant : vert, jaune et caramel, qui « faisaient
Noël »).

| Couleur | Hex | Rôle (thème clair) | Rôle (thème sombre) |
|---|---|---|---|
| Bleu canard profond | `#0E5A62` | Couleur principale (barres, boutons) | — |
| Bleu canard | `#1C7880` | Secondaire, conteneurs | Conteneurs |
| Blanc cassé | `#FAF6F1` | Fond | Texte |
| Pêche clair | `#FFDDD0` | Mises en avant, onglet sélectionné | Mises en avant |
| Pêche | `#F2A285` | Accent : bouton d'action, minuteurs | Accent |

Couleurs dérivées pour le thème sombre : fond `#0D2427`, principal `#8ED0D3` ; encre `#132326`.

Icône : une toque blanc cassé au bandeau pêche, sur fond bleu canard (l'app de test : toque bleu
canard sur fond pêche). Elle est générée par `tools/make_icons.py` (Pillow), pour toutes les
densités, avec la version monochrome d'Android 13.

Règles :
- Texte sur pêche : toujours foncé (`#132326`), jamais blanc (contraste insuffisant).
- Les contrastes texte/fond sont vérifiés par `test/theme_contrast_test.dart` (≥ 4,5:1, WCAG AA).
- Dans le code, toujours passer par `Theme.of(context).colorScheme`, jamais par les couleurs brutes.
