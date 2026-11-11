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
import '../../domain/side_emoji.dart';
import '../../l10n/app_localizations.dart';
import '../classification/labels_providers.dart';
import '../recipes/recipe_photo.dart';
import 'planning_providers.dart';
import 'side_dishes_page.dart';

/// Une proposition du planificateur pour un repas à prévoir.
class _Proposal {
  _Proposal(this.slot, this.day, this.recipe);

  final PlannerSlot slot;
  final DateTime day;
  Recipe? recipe;
  var keep = true;
  final sides = <SideDish>[];

  /// Les recettes déjà écartées pour ce repas (« Remplacer »).
  final rejected = <String>{};
}

/// Le planificateur : les repas à prévoir d'une ou plusieurs semaines (jour,
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

  /// Le lundi de la première semaine à prévoir, et le nombre de semaines.
  late DateTime _start = ref.read(plannedWeekProvider);
  var _weeks = 1;
  late Season _season = Season.of(_start);
  List<Recipe>? _recipes;
  List<_Proposal>? _proposals;
  var _busy = false;

  @override
  void dispose() {
    _useUp.dispose();
    super.dispose();
  }

  DateTime _weekStart(int week) =>
      DateTime(_start.year, _start.month, _start.day + 7 * week);

  DateTime _dayOf(int weekday, [int week = 0]) =>
      DateTime(_start.year, _start.month, _start.day + 7 * week + weekday - 1);

  void _setStart(DateTime monday) {
    _start = monday;
    _season = Season.of(monday);
    _proposals = null;
  }

  /// Les types de plat de chaque créneau, sous-catégories comprises.
  Map<String, Set<String>> _categories(List<MealSlot> slots) {
    final labels = ref.read(labelsProvider).value ?? const <Label>[];
    final children = <String, List<String>>{};
    for (final l in labels) {
      if (l.parentId != null) (children[l.parentId!] ??= []).add(l.id);
    }
    Set<String> expand(Set<String> ids) {
      final all = <String>{};
      final queue = [...ids];
      while (queue.isNotEmpty) {
        final id = queue.removeLast();
        if (all.add(id)) queue.addAll(children[id] ?? const []);
      }
      return all;
    }

    return {
      for (final s in slots)
        if (s.categoryIds.isNotEmpty) s.id: expand(s.categoryIds),
    };
  }

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

  bool _isFilled(List<PlannedMeal> meals, PlannerSlot slot, int week) {
    final day = _dayOf(slot.weekday, week);
    return meals.any((m) => m.day == day && m.slotId == slot.slotId);
  }

  /// Le nombre de semaines où le repas est déjà prévu.
  int _filledWeeks(List<PlannedMeal> meals, PlannerSlot slot) => [
    for (var w = 0; w < _weeks; w++)
      if (_isFilled(meals, slot, w)) w,
  ].length;

  Future<void> _propose(
    List<PlannedMeal> meals,
    List<MealSlot> mealSlots,
  ) async {
    setState(() => _busy = true);
    final recipes = _recipes ??= await ref
        .read(recipeRepositoryProvider)
        .getAllWithDetails();
    final free = [
      for (var w = 0; w < _weeks; w++)
        for (final s in _slots!)
          if (!_isFilled(meals, s, w)) (s, _dayOf(s.weekday, w)),
    ];
    final picks = MealPlanner.propose(
      recipes,
      [for (final (s, _) in free) s],
      season: _season,
      useUp: _useUpTerms,
      categories: _categories(mealSlots),
      random: _random,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _proposals = [
        for (final (i, (slot, day)) in free.indexed)
          _Proposal(slot, day, picks[i]),
      ];
    });
  }

  void _replace(_Proposal proposal) {
    final categories =
        _categories(
          ref.read(mealSlotsProvider).value ?? const <MealSlot>[],
        )[proposal.slot.slotId] ??
        const <String>{};
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
      categories: categories,
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
        categories: categories,
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
      final day = p.day;
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
    final mealSlots = ref.watch(mealSlotsProvider).value;
    final setups = ref.watch(plannerSetupsProvider).value;
    // Lus au moment d'ajouter un accompagnement.
    ref.watch(sideDishesProvider);
    final meals = [
      for (var w = 0; w < _weeks; w++)
        ...?ref.watch(weekMealsProvider(_weekStart(w))).value,
    ];
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
    String proposalTitle(_Proposal p) =>
        '${DateFormat.MMMMEEEEd(locale).format(p.day)} · '
        '${slotNames[p.slot.slotId] ?? ''}';
    final allPlanned = slots.every((s) => _filledWeeks(meals, s) == _weeks);
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
          // La période : la première semaine, et combien de semaines.
          _Header(l10n.plannerPeriod),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
            child: Row(
              children: [
                Expanded(child: Text(l10n.plannerFirstWeek)),
                IconButton(
                  key: const ValueKey('planner-week-previous'),
                  tooltip: l10n.plannerPreviousWeek,
                  onPressed: () => setState(() => _setStart(_weekStart(-1))),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  DateFormat.MMMd(locale).format(_start),
                  style: theme.textTheme.titleSmall,
                ),
                IconButton(
                  key: const ValueKey('planner-week-next'),
                  tooltip: l10n.plannerNextWeek,
                  onPressed: () => setState(() => _setStart(_weekStart(1))),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
            child: Row(
              children: [
                Expanded(child: Text(l10n.plannerWeekCount)),
                IconButton(
                  key: const ValueKey('planner-weeks-less'),
                  tooltip: l10n.plannerFewerWeeks,
                  onPressed: _weeks > 1
                      ? () => setState(() {
                          _weeks--;
                          _proposals = null;
                        })
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text(
                  '$_weeks',
                  key: const ValueKey('planner-weeks'),
                  style: theme.textTheme.titleSmall,
                ),
                IconButton(
                  key: const ValueKey('planner-weeks-more'),
                  tooltip: l10n.plannerMoreWeeks,
                  onPressed: _weeks < 8
                      ? () => setState(() {
                          _weeks++;
                          _proposals = null;
                        })
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Text(
              l10n.plannerRange(
                DateFormat.MMMMEEEEd(locale).format(_start),
                DateFormat.MMMMEEEEd(locale).format(_dayOf(7, _weeks - 1)),
              ),
              key: const ValueKey('planner-range'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
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
            if (_filledWeeks(meals, slot) case final filled)
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
                            style: filled == _weeks
                                ? theme.textTheme.bodyLarge?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  )
                                : theme.textTheme.bodyLarge,
                          ),
                          if (filled > 0)
                            Text(
                              filled == _weeks
                                  ? l10n.plannerAlreadyPlanned
                                  : l10n.plannerPartlyPlanned,
                              style: theme.textTheme.bodySmall,
                            ),
                          if (filled < _weeks && collections.isNotEmpty)
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
                    PopupMenuButton<int>(
                      key: ValueKey('planner-time-$i'),
                      tooltip: l10n.plannerTime,
                      initialValue: slot.minutes ?? 0,
                      onSelected: (minutes) => editSlot(
                        i,
                        slot.copyWith(
                          minutes: () => minutes == 0 ? null : minutes,
                        ),
                      ),
                      itemBuilder: (context) => [
                        for (final m in const [0, 15, 20, 30, 45, 60, 90, 120])
                          PopupMenuItem(
                            key: ValueKey('planner-time-$i-$m'),
                            value: m,
                            child: Text(
                              m == 0
                                  ? l10n.plannerNoLimit
                                  : l10n.plannerMinutes(m),
                            ),
                          ),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.timer_outlined, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              slot.minutes == null
                                  ? l10n.plannerNoLimit
                                  : l10n.plannerMinutes(slot.minutes!),
                            ),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
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
              // La saison suit la semaine choisie.
              key: ValueKey('planner-season-${_season.name}'),
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
              onPressed: _busy || allPlanned
                  ? null
                  : () => _propose(meals, mealSlots),
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
                title: proposalTitle(p),
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
            if (recipe != null && proposal.keep) ...[
              // Les accompagnements choisis, en couleur, avec leur emoji.
              if (proposal.sides.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6, right: 8),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final (i, side) in proposal.sides.indexed)
                        InputChip(
                          key: ValueKey('planner-side-$index-$i'),
                          avatar: Text(SideEmoji.of(side)),
                          label: Text(side.name),
                          backgroundColor: theme.colorScheme.secondaryContainer,
                          labelStyle: TextStyle(
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                          side: BorderSide.none,
                          onPressed: () => onReplaceSide(i),
                          onDeleted: () => onRemoveSide(i),
                          deleteButtonTooltipMessage: l10n.delete,
                        ),
                    ],
                  ),
                ),
              // Les boutons pour en ajouter, à part et discrets.
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  children: [
                    for (final kind in SideKind.values)
                      TextButton.icon(
                        key: ValueKey('planner-add-${kind.name}-$index'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => onAddSide(kind),
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(switch (kind) {
                          SideKind.starch => l10n.sideStarch,
                          SideKind.protein => l10n.sideProtein,
                          SideKind.vegetable => l10n.sideVegetable,
                        }),
                      ),
                  ],
                ),
              ),
            ],
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
