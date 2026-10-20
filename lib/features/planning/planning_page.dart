import 'package:flutter/material.dart';

import '../../core/widgets/coming_soon.dart';
import '../../l10n/app_localizations.dart';

class PlanningPage extends StatelessWidget {
  const PlanningPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navPlanning)),
      body: ComingSoon(
        icon: Icons.calendar_month_outlined,
        title: l10n.planningEmptyTitle,
        version: '0.11',
      ),
    );
  }
}
