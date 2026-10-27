import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/home_shell.dart';
import '../../features/planning/planning_page.dart';
import '../../features/recipes/recipes_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/shopping/shopping_page.dart';

GoRouter buildRouter() => GoRouter(
  initialLocation: '/recettes',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => HomeShell(navigationShell: shell),
      branches: [
        _branch('/recettes', const RecipesPage()),
        _branch('/planning', const PlanningPage()),
        _branch('/courses', const ShoppingPage()),
        _branch('/reglages', const SettingsPage()),
      ],
    ),
  ],
);

StatefulShellBranch _branch(String path, Widget page) => StatefulShellBranch(
  routes: [GoRoute(path: path, builder: (context, state) => page)],
);
