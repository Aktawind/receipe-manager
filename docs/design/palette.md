# Palette

| Couleur | Hex | Rôle (thème clair) | Rôle (thème sombre) |
|---|---|---|---|
| Vert profond | `#1B524F` | Couleur principale (barres, boutons) | — |
| Vert canard | `#236C68` | Secondaire, conteneurs | Conteneurs |
| Menthe | `#EBF7F4` | Fond | Texte |
| Jaune doux | `#FDE9A0` | Mises en avant, onglet sélectionné | Mises en avant |
| Orange caramel | `#D4935A` | Accent : bouton d'action, minuteurs | Accent |

Couleurs dérivées pour le thème sombre : fond `#0F2A28`, principal `#8FD1C9`.

Règles :
- Texte sur orange ou jaune : toujours foncé (`#14211F`), jamais blanc (contraste insuffisant).
- Les contrastes texte/fond sont vérifiés par `test/theme_contrast_test.dart` (≥ 4,5:1, WCAG AA).
- Dans le code, toujours passer par `Theme.of(context).colorScheme`, jamais par les couleurs brutes.
