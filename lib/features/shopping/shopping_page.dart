import 'package:flutter/material.dart';

import '../../core/widgets/coming_soon.dart';
import '../../l10n/app_localizations.dart';

class ShoppingPage extends StatelessWidget {
  const ShoppingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navShopping)),
      body: ComingSoon(
        icon: Icons.shopping_basket_outlined,
        title: l10n.shoppingEmptyTitle,
        version: '0.10',
      ),
    );
  }
}
