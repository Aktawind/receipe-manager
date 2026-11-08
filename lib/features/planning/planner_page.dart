import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/name_dialog.dart';
import '../../data/app_services.dart';
import '../../domain/label.dart';
import '../../domain/meal_planner.dart';
import '../../domain/planning.dart';
import '../../domain/recipe.dart';
import '../../l10n/app_localizations.dart';
import '../classification/labels_providers.dart';
import '../recipes/recipe_photo.dart';
import 'planning_providers.dart';
import 'side_dishes_page.dart';

/// Une proposition du planificateur pour un repas à prévoir.
class _Proposal {
  _Proposal(this.slot, this.recipe);

  final PlannerSlot slot;
  Recipe? recipe;
  var keep = true;
  final sides = <SideDish>[];

  /// Les recettes déjà écartées pour ce repas (« Remplacer »).
  final rejected = <String>{};
}

/// Le planificateur : les repas à prévoir de la semaine affichée (jour,
/// créneau, temps, collection), la saison et les ingrédients à écouler ;
/// propose une recette par repas, à garder ou remplacer, avec des
/// accompagnements, puis remplit les créneaux libres du planning.
class PlannerPage extends ConsumerStatefulWidget {
  const PlannerPage({super.key});

  @override
  ConsumerState<PlannerPage> createState() => _PlannerPageState();
}

class _PlannerPageState extends ConsumerState<PlannerPage> {
  final _random = Random();
  final _useUp = TextEditingController();

  /// Les repas à prévoir ; `null` tant que la planification de départ
  /// n'est pas choisie.
  List<PlannerSlot>? _slots;
  late Season _season = Season.of(ref.read(plannedWeekProvider));
  List<Recipe>? _recipes;
  List<_Proposal>? _proposals;
  var _busy = false;

  @override
  void dispose() {
    _useUp.dispose();
    super.dispose();
  }

  DateTime get _monday => ref.read(plannedWeekProvider);

  DateTime _dayOf(int weekday) =>
      DateTime(_monday.year, _monday.month, _monday.day + weekday - 1);

  List<String> get _useUpTerms => [
    for (final t in _useUp.text.split(RegExp(r'[,;\n]')))
      if (t.trim().isNotEmpty) t.trim(),
  ];

  /// Au départ : la dernière planification enregistrée, sinon un dîner par
  /// jour.
  void _initSlots(List<PlannerSetup> setups, List<MealSlot> mealSlots) {
    if (_slots != null) return;
    final saved = [
      for (final s in setups)
        if (!s.isDeleted) s,
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (saved.isNotEmpty) {
      _slots = [...saved.first.slots];
      return;
    }
    final dinner =
        mealSlots
            .where((s) => s.id == DefaultMealSlots.idFor('Dîner') && !s.hidden)
            .firstOrNull ??
        mealSlots.where((s) => !s.hidden).lastOrNull;
    _slots = [
      if (dinner != null)
        for (var d = 1; d <= 7; d++) PlannerSlot(weekday: d, slotId: dinner.id),
    ];
  }

  void _sortSlots(List<MealSlot> mealSlots) {
    final order = {for (final s in mealSlots) s.id: s.position};
    _slots!.sort((a, b) {
      final byDay = a.weekday.compareTo(b.weekday);
      if (byDay != 0) return byDay;
      return (order[a.slotId] ?? 0).compareTo(order[b.slotId] ?? 0);
    });
  }

  bool _isFilled(List<PlannedMeal> meals, PlannerSlot slot) {
    final day = _dayOf(slot.weekday);
    return meals.any((m) => m.day == day && m.slotId == slot.slotId);
  }

  Future<void> _propose(List<PlannedMeal> meals) async {
    setState(() => _busy = true);
    final recipes = _recipes ??= await ref
        .read(recipeRepositoryProvider)
        .getAllWithDetails();
    final free = [
      for (final s in _slots!)
        if (!_isFilled(meals, s)) s,
    ];
    final picks = MealPlanner.propose(
      recipes,
      free,
      season: _season,
      useUp: _useUpTerms,
      random: _random,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _proposals = [
        for (final (i, slot) in free.indexed) _Proposal(slot, picks[i]),
      ];
    });
  }

  void _replace(_Proposal proposal) {
    final current = proposal.recipe;
    if (current != null) proposal.rejected.add(current.id);
    final taken = {
      for (final p in _proposals!)
        if (p != proposal && p.recipe != null) p.recipe!.id,
    };
    var next = MealPlanner.replace(
      _recipes!,
      proposal.slot,
      season: _season,
      useUp: _useUpTerms,
      taken: taken,
      rejected: proposal.rejected,
      random: _random,
    );
    if (next == null && proposal.rejected.isNotEmpty) {
      // Tout a été écarté : on repart du début.
      proposal.rejected
        ..clear()
        ..addAll([?current?.id]);
      next = MealPlanner.replace(
        _recipes!,
        proposal.slot,
        season: _season,
        useUp: _useUpTerms,
        taken: taken,
        rejected: proposal.rejected,
        random: _random,
      );
    }
    setState(() {
      proposal.recipe = next ?? current;
      proposal.keep = true;
    });
  }

  /// Ajoute (ou remplace, [index]) un accompagnement de [kind].
  void _side(_Proposal proposal, SideKind kind, {int? index}) {
    final sides = ref.read(sideDishesProvider).value ?? const <SideDish>[];
    final pick = MealPlanner.side(
      sides,
      kind,
      season: _season,
      exclude: {for (final s in proposal.sides) s.name},
      random: _random,
    );
    if (pick == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).plannerNoSide)),
        );
      return;
    }
    setState(() {
      if (index == null) {
        proposal.sides.add(pick);
      } else {
        proposal.sides[index] = pick;
      }
    });
  }

  Future<void> _apply() async {
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(planningRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    var added = 0;
    for (final p in _proposals!) {
      final recipe = p.recipe;
      if (!p.keep || recipe == null) continue;
      final day = _dayOf(p.slot.weekday);
      await repository.add(
        day: day,
        slotId: p.slot.slotId,
        recipeId: recipe.id,
        recipeTitle: recipe.title,
        servings: recipe.servings,
      );
      for (final side in p.sides) {
        await repository.add(day: day, slotId: p.slot.slotId, note: side.name);
      }
      added++;
    }
    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.plannerAdded(added))));
  }

  Future<void> _saveSetup(List<PlannerSetup> setups) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final name = await askName(
      context,
      title: l10n.plannerSaveSetup,
      label: l10n.plannerSetupName,
      initial: setups.where((s) => !s.isDeleted).firstOrNull?.name ?? '',
    );
    if (name == null || name.trim().isEmpty) return;
    await ref.read(planningRepositoryProvider).saveSetup(name, _slots!);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(l10n.plannerSetupSaved(name.trim()))),
      );
  }

  Future<void> _addMeals(List<MealSlot> mealSlots) async {
    final added = await showDialog<List<PlannerSlot>>(
      context: context,
      builder: (context) => _AddMealsDialog(
        slots: [
          for (final s in mealSlots)
            if (!s.hidden) s,
        ],
        dayOf: _dayOf,
      ),
    );
    if (added == null || added.isEmpty) return;
    setState(() {
      for (final s in added) {
        final same = _slots!.indexWhere(
          (o) => o.weekday == s.weekday && o.slotId == s.slotId,
        );
        if (same < 0) _slots!.add(s);
      }
      _sortSlots(mealSlots);
      _proposals = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final monday = ref.watch(plannedWeekProvider);
    final mealSlots = ref.watch(mealSlotsProvider).value;
    final setups = ref.watch(plannerSetupsProvider).value;
    // Lus au moment d'ajouter un accompagnement.
    ref.watch(sideDishesProvider);
    final meals =
        ref.watch(weekMealsProvider(monday)).value ?? const <PlannedMeal>[];
    final collections = [
      for (final l in ref.watch(labelsProvider).value ?? const <Label>[])
        if (l.kind == LabelKind.collection && !l.isDeleted) l,
    ];
    if (mealSlots == null || setups == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.plannerTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    _initSlots(setups, mealSlots);
    final slots = _slots!;
    final slotNames = {for (final s in mealSlots) s.id: s.name};
    final saved = [
      for (final s in setups)
        if (!s.isDeleted) s,
    ];
    String slotTitle(PlannerSlot s) =>
        '${DateFormat.EEEE(locale).format(_dayOf(s.weekday))} · '
        '${slotNames[s.slotId] ?? ''}';
    final proposals = _proposals;
    final keptCount = proposals == null
        ? 0
        : proposals.where((p) => p.keep && p.recipe != null).length;

    void editSlot(int i, PlannerSlot value) => setState(() {
      slots[i] = value;
      _proposals = null;
    });

    return Scaffold(
      appBar: AppBar(title: Text(l10n.plannerTitle)),
      body: ListView(
        // Marge du bas : barre de navigation Android.
        padding: EdgeInsets.only(
          bottom: 24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              l10n.plannerWeekOf(DateFormat.MMMMd(locale).format(monday)),
              style: theme.textTheme.titleMedium,
            ),
          ),
          if (saved.isNotEmpty) ...[
            _Header(l10n.plannerSetups),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final setup in saved)
                    InputChip(
                      key: ValueKey('planner-setup-${setup.id}'),
                      label: Text(setup.name),
                      onPressed: () => setState(() {
                        _slots = [...setup.slots];
                        _sortSlots(mealSlots);
                        _proposals = null;
                      }),
                      onDeleted: () => ref
                          .read(planningRepositoryProvider)
                          .deleteSetup(setup),
                      deleteButtonTooltipMessage: l10n.delete,
                    ),
                ],
              ),
            ),
          ],
          _Header(l10n.plannerMeals),
          if (slots.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(l10n.plannerNoMeals),
            ),
          for (final (i, slot) in slots.indexed)
            Padding(
              key: ValueKey('planner-slot-$i'),
              padding: const EdgeInsets.fromLTRB(16, 2, 4, 2),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          slotTitle(slot),
                          style: _isFilled(meals, slot)
                              ? theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                )
                              : theme.textTheme.bodyLarge,
                        ),
                        if (_isFilled(meals, slot))
                          Text(
                            l10n.plannerAlreadyPlanned,
                            style: theme.textTheme.bodySmall,
                          )
                        else if (collections.isNotEmpty)
                          DropdownButton<String?>(
                            key: ValueKey('planner-collection-$i'),
                            value: slot.collectionId,
                            isDense: true,
                            underline: const SizedBox.shrink(),
                            style: theme.textTheme.bodySmall,
                            items: [
                              DropdownMenuItem(
                                child: Text(l10n.plannerAnyCollection),
                              ),
                              for (final c in collections)
                                DropdownMenuItem(
                                  value: c.id,
                                  child: Text(c.name),
                                ),
                            ],
                            onChanged: (id) => editSlot(
                              i,
                              slot.copyWith(collectionId: () => id),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: ValueKey('planner-less-$i'),
                    tooltip: l10n.plannerLessTime,
                    onPressed: slot.minutes > 10
                        ? () => editSlot(
                            i,
                            slot.copyWith(minutes: slot.minutes - 10),
                          )
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text(l10n.plannerMinutes(slot.minutes)),
                  IconButton(
                    key: ValueKey('planner-more-$i'),
                    tooltip: l10n.plannerMoreTime,
                    onPressed: () =>
                        editSlot(i, slot.copyWith(minutes: slot.minutes + 10)),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                  IconButton(
                    key: ValueKey('planner-remove-$i'),
                    tooltip: l10n.delete,
                    onPressed: () => setState(() {
                      slots.removeAt(i);
                      _proposals = null;
                    }),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  key: const ValueKey('planner-add-meals'),
                  onPressed: () => _addMeals(mealSlots),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.plannerAddMeals),
                ),
                if (slots.isNotEmpty)
                  TextButton.icon(
                    key: const ValueKey('planner-save-setup'),
                    onPressed: () => _saveSetup(saved),
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: Text(l10n.plannerSaveSetup),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: DropdownButtonFormField<Season>(
              key: const ValueKey('planner-season'),
              initialValue: _season,
              decoration: InputDecoration(
                labelText: l10n.plannerSeason,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                for (final s in Season.values)
                  DropdownMenuItem(value: s, child: Text(seasonName(l10n, s))),
              ],
              onChanged: (s) => setState(() {
                if (s != null) _season = s;
                _proposals = null;
              }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              key: const ValueKey('planner-use-up'),
              controller: _useUp,
              decoration: InputDecoration(
                labelText: l10n.plannerUseUp,
                hintText: l10n.plannerUseUpHint,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: FilledButton.icon(
              key: const ValueKey('planner-propose'),
              onPressed: _busy || slots.every((s) => _isFilled(meals, s))
                  ? null
                  : () => _propose(meals),
              icon: const Icon(Icons.auto_awesome_outlined),
              label: Text(
                proposals == null
                    ? l10n.plannerPropose
                    : l10n.plannerProposeAgain,
              ),
            ),
          ),
          if (proposals != null) ...[
            for (final (i, p) in proposals.indexed)
              _ProposalCard(
                key: ValueKey('planner-proposal-$i'),
                index: i,
                title: slotTitle(p.slot),
                proposal: p,
                onKeep: (on) => setState(() => p.keep = on),
                onReplace: () => _replace(p),
                onAddSide: (kind) => _side(p, kind),
                onReplaceSide: (index) =>
                    _side(p, p.sides[index].kind, index: index),
                onRemoveSide: (index) =>
                    setState(() => p.sides.removeAt(index)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: FilledButton.icon(
                key: const ValueKey('planner-apply'),
                onPressed: _busy || keptCount == 0 ? null : _apply,
                icon: const Icon(Icons.event_available_outlined),
                label: Text(l10n.plannerApply(keptCount)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _ProposalCard extends StatelessWidget {
  const _ProposalCard({
    super.key,
    required this.index,
    required this.title,
    required this.proposal,
    required this.onKeep,
    required this.onReplace,
    required this.onAddSide,
    required this.onReplaceSide,
    required this.onRemoveSide,
  });

  final int index;
  final String title;
  final _Proposal proposal;
  final ValueChanged<bool> onKeep;
  final VoidCallback onReplace;
  final ValueChanged<SideKind> onAddSide;
  final ValueChanged<int> onReplaceSide;
  final ValueChanged<int> onRemoveSide;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final recipe = proposal.recipe;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Row(
              children: [
                if (recipe != null)
                  SizedBox.square(
                    dimension: 48,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: RecipePhoto(
                        photo: recipe.mainPhoto,
                        decodeWidth: 144,
                        iconSize: 24,
                      ),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    recipe?.title ?? l10n.plannerNoRecipe,
                    style: recipe == null
                        ? theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          )
                        : theme.textTheme.titleMedium,
                  ),
                ),
                if (recipe != null) ...[
                  IconButton(
                    key: ValueKey('planner-replace-$index'),
                    tooltip: l10n.plannerReplace,
                    onPressed: onReplace,
                    icon: const Icon(Icons.refresh),
                  ),
                  Checkbox(
                    key: ValueKey('planner-keep-$index'),
                    value: proposal.keep,
                    semanticLabel: l10n.plannerKeep,
                    onChanged: (on) => onKeep(on ?? false),
                  ),
                ],
              ],
            ),
            if (recipe != null && proposal.keep)
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final (i, side) in proposal.sides.indexed)
                    InputChip(
                      key: ValueKey('planner-side-$index-$i'),
                      label: Text(side.name),
                      onPressed: () => onReplaceSide(i),
                      onDeleted: () => onRemoveSide(i),
                      deleteButtonTooltipMessage: l10n.delete,
                    ),
                  for (final kind in SideKind.values)
                    ActionChip(
                      key: ValueKey('planner-add-${kind.name}-$index'),
                      avatar: const Icon(Icons.add, size: 18),
                      label: Text(switch (kind) {
                        SideKind.starch => l10n.sideStarch,
                        SideKind.protein => l10n.sideProtein,
                        SideKind.vegetable => l10n.sideVegetable,
                      }),
                      onPressed: () => onAddSide(kind),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Ajoute des repas à prévoir : les jours (plusieurs), un créneau.
class _AddMealsDialog extends StatefulWidget {
  const _AddMealsDialog({required this.slots, required this.dayOf});

  final List<MealSlot> slots;
  final DateTime Function(int weekday) dayOf;

  @override
  State<_AddMealsDialog> createState() => _AddMealsDialogState();
}

class _AddMealsDialogState extends State<_AddMealsDialog> {
  final _days = <int>{};
  late String? _slotId = widget.slots.lastOrNull?.id;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    return AlertDialog(
      title: Text(l10n.plannerAddMeals),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.plannerDays, style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (var d = 1; d <= 7; d++)
                  FilterChip(
                    key: ValueKey('planner-day-$d'),
                    label: Text(DateFormat.E(locale).format(widget.dayOf(d))),
                    selected: _days.contains(d),
                    onSelected: (on) =>
                        setState(() => on ? _days.add(d) : _days.remove(d)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(l10n.plannerSlot, style: theme.textTheme.labelLarge),
            RadioGroup<String>(
              groupValue: _slotId,
              onChanged: (id) => setState(() => _slotId = id),
              child: Column(
                children: [
                  for (final s in widget.slots)
                    RadioListTile<String>(
                      key: ValueKey('planner-slot-choice-${s.id}'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: s.id,
                      title: Text(s.name),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const ValueKey('planner-add-meals-confirm'),
          onPressed: _days.isEmpty || _slotId == null
              ? null
              : () => Navigator.pop(context, [
                  for (final d in _days.toList()..sort())
                    PlannerSlot(weekday: d, slotId: _slotId!),
                ]),
          child: Text(l10n.plannerAddMeals),
        ),
      ],
    );
  }
}
