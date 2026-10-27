import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';

/// Largeur à partir de laquelle on affiche la mise en page tablette.
const tabletBreakpoint = 600.0;

/// Navigation principale : barre du bas sur téléphone, rail latéral sur
/// tablette.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onSelect(int index) => navigationShell.goBranch(
    index,
    initialLocation: index == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final destinations = [
      (Icons.menu_book_outlined, Icons.menu_book, l10n.navRecipes),
      (Icons.calendar_month_outlined, Icons.calendar_month, l10n.navPlanning),
      (Icons.shopping_basket_outlined, Icons.shopping_basket, l10n.navShopping),
      (Icons.settings_outlined, Icons.settings, l10n.navSettings),
    ];

    final isTablet = MediaQuery.sizeOf(context).width >= tabletBreakpoint;
    if (isTablet) {
      return Scaffold(
        // Sans barre du bas, la barre de navigation Android ne doit pas
        // recouvrir le contenu.
        body: SafeArea(
          top: false,
          child: Row(
            children: [
              NavigationRail(
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: _onSelect,
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (final (icon, selectedIcon, label) in destinations)
                    NavigationRailDestination(
                      icon: Icon(icon),
                      selectedIcon: Icon(selectedIcon),
                      label: Text(label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: navigationShell),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onSelect,
        destinations: [
          for (final (icon, selectedIcon, label) in destinations)
            NavigationDestination(
              icon: Icon(icon),
              selectedIcon: Icon(selectedIcon),
              label: label,
            ),
        ],
      ),
    );
  }
}
