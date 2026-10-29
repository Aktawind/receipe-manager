import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../domain/label.dart';
import '../../features/classification/labels_page.dart';
import '../../features/equipment/equipment_page.dart';
import '../../features/home/home_shell.dart';
import '../../features/planning/planning_page.dart';
import '../../features/recipes/recipe_detail_page.dart';
import '../../features/recipes/recipe_editor_page.dart';
import '../../features/recipes/recipes_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/settings/trash_page.dart';
import '../../features/shopping/shopping_page.dart';

final _rootKey = GlobalKey<NavigatorState>();

GoRouter buildRouter() => GoRouter(
  navigatorKey: _rootKey,
  initialLocation: '/recettes',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => HomeShell(navigationShell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/recettes',
              builder: (context, state) => const RecipesPage(),
              routes: [
                // Fiche et éditeur en plein écran, au-dessus de la navigation.
                GoRoute(
                  path: ':id',
                  parentNavigatorKey: _rootKey,
                  builder: (context, state) =>
                      RecipeDetailPage(recipeId: state.pathParameters['id']!),
                  routes: [
                    GoRoute(
                      path: 'modifier',
                      parentNavigatorKey: _rootKey,
                      builder: (context, state) => RecipeEditorPage(
                        recipeId: state.pathParameters['id']!,
                        isNew: state.uri.queryParameters['nouvelle'] == '1',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        _branch('/planning', const PlanningPage()),
        _branch('/courses', const ShoppingPage()),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/reglages',
              builder: (context, state) => const SettingsPage(),
              routes: [
                GoRoute(
                  path: 'classement',
                  parentNavigatorKey: _rootKey,
                  builder: (context, state) => const ClassificationPage(),
                  routes: [
                    GoRoute(
                      path: ':kind',
                      parentNavigatorKey: _rootKey,
                      builder: (context, state) => LabelsPage(
                        kind:
                            LabelKind.fromCode(state.pathParameters['kind']) ??
                            LabelKind.tag,
                      ),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'materiel',
                  parentNavigatorKey: _rootKey,
                  builder: (context, state) => const EquipmentPage(),
                ),
                GoRoute(
                  path: 'corbeille',
                  parentNavigatorKey: _rootKey,
                  builder: (context, state) => const TrashPage(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);

StatefulShellBranch _branch(String path, Widget page) => StatefulShellBranch(
  routes: [GoRoute(path: path, builder: (context, state) => page)],
);
