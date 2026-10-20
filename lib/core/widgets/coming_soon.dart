import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Écran d'attente pour une fonctionnalité prévue dans une version future.
class ComingSoon extends StatelessWidget {
  const ComingSoon({
    super.key,
    required this.icon,
    required this.title,
    required this.version,
  });

  final IconData icon;
  final String title;
  final String version;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: theme.colorScheme.secondary),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Chip(
              label: Text(
                AppLocalizations.of(context).comingInVersion(version),
              ),
              backgroundColor: theme.colorScheme.tertiaryContainer,
              labelStyle: TextStyle(
                color: theme.colorScheme.onTertiaryContainer,
              ),
              side: BorderSide.none,
            ),
          ],
        ),
      ),
    );
  }
}
