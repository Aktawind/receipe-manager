import 'package:flutter/material.dart';

import '../../core/widgets/coming_soon.dart';
import '../../l10n/app_localizations.dart';

class RecipesPage extends StatelessWidget {
  const RecipesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navRecipes)),
      body: ComingSoon(
        icon: Icons.menu_book_outlined,
        title: l10n.recipesEmptyTitle,
        version: '0.1',
      ),
    );
  }
}
