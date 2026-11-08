import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/name_dialog.dart';
import '../../data/app_services.dart';
import '../../domain/meal_planner.dart';
import '../../l10n/app_localizations.dart';
import 'planning_providers.dart';

/// Le nom d'une saison.
String seasonName(AppLocalizations l10n, Season season) => switch (season) {
  Season.spring => l10n.seasonSpring,
  Season.summer => l10n.seasonSummer,
  Season.autumn => l10n.seasonAutumn,
  Season.winter => l10n.seasonWinter,
};

/// Le nom d'une sorte d'accompagnement.
String sideKindName(AppLocalizations l10n, SideKind kind) => switch (kind) {
  SideKind.starch => l10n.sideStarches,
  SideKind.protein => l10n.sideProteins,
  SideKind.vegetable => l10n.sideVegetables,
};

/// Réglages → Accompagnements : les féculents, protéines et légumes que le
/// planificateur propose pour compléter un repas, avec leurs saisons.
class SideDishesPage extends ConsumerWidget {
  const SideDishesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: SideKind.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.sideDishesTitle),
          bottom: TabBar(
            tabs: [
              for (final kind in SideKind.values)
                Tab(
                  key: ValueKey('sides-tab-${kind.name}'),
                  text: sideKindName(l10n, kind),
                ),
            ],
          ),
        ),
        body: TabBarView(
          children: [for (final kind in SideKind.values) _SideList(kind: kind)],
        ),
      ),
    );
  }
}

class _SideList extends ConsumerStatefulWidget {
  const _SideList({required this.kind});

  final SideKind kind;

  @override
  ConsumerState<_SideList> createState() => _SideListState();
}

class _SideListState extends ConsumerState<_SideList> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    await ref.read(planningRepositoryProvider).createSide(widget.kind, name);
    _name.clear();
  }

  Future<void> _rename(SideDish side) async {
    final l10n = AppLocalizations.of(context);
    final name = await askName(
      context,
      title: l10n.renameSideDish,
      initial: side.name,
    );
    if (name == null || name.trim().isEmpty) return;
    await ref
        .read(planningRepositoryProvider)
        .updateSide(side.copyWith(name: name.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final sides = [
      for (final s in ref.watch(sideDishesProvider).value ?? const <SideDish>[])
        if (s.kind == widget.kind) s,
    ];
    final repository = ref.read(planningRepositoryProvider);
    return ListView(
      // Marge du bas : barre de navigation Android.
      padding: EdgeInsets.only(
        bottom: 24 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: ValueKey('sides-add-${widget.kind.name}'),
                  controller: _name,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: l10n.addSideDish,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _add(),
                ),
              ),
              IconButton(
                tooltip: l10n.addSideDish,
                icon: const Icon(Icons.add_circle_outline),
                onPressed: _add,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(l10n.sideDishesHint, style: theme.textTheme.bodySmall),
        ),
        for (final side in sides)
          Padding(
            key: ValueKey('side-${side.id}'),
            padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () => _rename(side),
                        child: Text(
                          side.name,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                      Wrap(
                        spacing: 4,
                        children: [
                          for (final season in Season.values)
                            FilterChip(
                              key: ValueKey('side-${side.id}-${season.name}'),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              label: Text(seasonName(l10n, season)),
                              selected: side.seasons.contains(season),
                              onSelected: (on) => repository.updateSide(
                                side.copyWith(
                                  seasons: on
                                      ? {...side.seasons, season}
                                      : ({...side.seasons}..remove(season)),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: ValueKey('side-delete-${side.id}'),
                  tooltip: l10n.delete,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => repository.deleteSide(side),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
