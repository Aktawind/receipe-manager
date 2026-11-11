import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'home_layout.dart';
import 'home_page.dart';

/// Personnaliser l'accueil : l'ordre des rubriques (☰) et celles qui
/// s'affichent.
class HomeCustomizePage extends ConsumerWidget {
  const HomeCustomizePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final layout = ref.watch(homeLayoutProvider);
    final controller = ref.read(homeLayoutProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.homeCustomize),
        actions: [
          TextButton(
            key: const ValueKey('home-reset'),
            onPressed: controller.reset,
            child: Text(l10n.homeReset),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(l10n.homeCustomizeHint),
          ),
          Expanded(
            child: ReorderableListView.builder(
              // Marge du bas : barre de navigation Android.
              padding: EdgeInsets.only(
                bottom: 16 + MediaQuery.paddingOf(context).bottom,
              ),
              buildDefaultDragHandles: false,
              itemCount: layout.length,
              onReorderItem: controller.move,
              itemBuilder: (context, index) {
                final e = layout[index];
                return SwitchListTile(
                  key: ValueKey('home-section-${e.section.name}'),
                  secondary: ReorderableDragStartListener(
                    index: index,
                    child: const Icon(Icons.drag_handle),
                  ),
                  title: Text(homeSectionName(l10n, e.section)),
                  value: e.shown,
                  onChanged: (on) => controller.toggle(e.section, on),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
