import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/app_services.dart';
import '../../domain/planning.dart';
import '../../domain/recipe.dart';
import '../../l10n/app_localizations.dart';
import '../recipes/recipe_photo.dart';
import '../recipes/recipe_providers.dart';
import 'meal_sheet.dart';
import 'planning_providers.dart';
import 'planning_shopping.dart';

/// Planning : la semaine (lundi à dimanche) ou un jour, avec ses créneaux
/// et leurs repas.
class PlanningPage extends ConsumerWidget {
  const PlanningPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final monday = ref.watch(plannedWeekProvider);
    final day = ref.watch(plannedDayProvider);
    final slots = [
      for (final s in ref.watch(mealSlotsProvider).value ?? const <MealSlot>[])
        if (!s.hidden) s,
    ];
    final allSlots = ref.watch(mealSlotsProvider).value ?? const <MealSlot>[];
    final weekOfDay = day == null ? monday : PlannedMeal.weekStart(day);
    final meals =
        ref.watch(weekMealsProvider(weekOfDay)).value ?? const <PlannedMeal>[];
    final locale = Localizations.localeOf(context).toString();
    final sunday = DateTime(monday.year, monday.month, monday.day + 6);

    String rangeLabel() {
      if (day != null) return DateFormat.MMMMEEEEd(locale).format(day);
      final start = DateFormat.MMMd(locale).format(monday);
      final end = DateFormat.MMMd(locale).format(sunday);
      return '$start – $end';
    }

    void shift(int delta) {
      if (day != null) {
        final next = DateTime(day.year, day.month, day.day + delta);
        ref.read(plannedDayProvider.notifier).show(next);
        ref.read(plannedWeekProvider.notifier).show(next);
      } else {
        ref.read(plannedWeekProvider.notifier).shift(delta);
      }
    }

    final days = day != null
        ? [day]
        : [
            for (var i = 0; i < 7; i++)
              DateTime(monday.year, monday.month, monday.day + i),
          ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navPlanning),
        actions: [
          IconButton(
            key: const ValueKey('planning-planner'),
            tooltip: l10n.plannerOpen,
            icon: const Icon(Icons.auto_awesome_outlined),
            onPressed: () => context.push('/planning/planificateur'),
          ),
          IconButton(
            key: const ValueKey('planning-shopping'),
            tooltip: l10n.planningToShopping,
            icon: const Icon(Icons.add_shopping_cart),
            onPressed: () => addWeekToShopping(
              context,
              ref,
              meals: day == null
                  ? meals
                  : [
                      for (final m in meals)
                        if (m.day == day) m,
                    ],
              slots: allSlots,
            ),
          ),
          IconButton(
            key: const ValueKey('planning-today'),
            tooltip: l10n.today,
            icon: const Icon(Icons.today_outlined),
            onPressed: () {
              final now = DateTime.now();
              ref.read(plannedWeekProvider.notifier).show(now);
              if (day != null) ref.read(plannedDayProvider.notifier).show(now);
            },
          ),
          IconButton(
            key: const ValueKey('planning-view'),
            tooltip: day == null ? l10n.dayView : l10n.weekView,
            icon: Icon(
              day == null ? Icons.view_day_outlined : Icons.view_week_outlined,
            ),
            onPressed: () {
              if (day == null) {
                final today = PlannedMeal.dayOf(DateTime.now());
                final inWeek =
                    !today.isBefore(monday) && !today.isAfter(sunday);
                ref
                    .read(plannedDayProvider.notifier)
                    .show(inWeek ? today : monday);
              } else {
                ref.read(plannedWeekProvider.notifier).show(day);
                ref.read(plannedDayProvider.notifier).show(null);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                IconButton(
                  key: const ValueKey('planning-previous'),
                  tooltip: day == null ? l10n.previousWeek : l10n.previousDay,
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => shift(-1),
                ),
                Expanded(
                  child: Text(
                    rangeLabel(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  key: const ValueKey('planning-next'),
                  tooltip: day == null ? l10n.nextWeek : l10n.nextDay,
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => shift(1),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              // Marge du bas : barre de navigation Android.
              padding: EdgeInsets.only(
                bottom: 16 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                for (final d in days)
                  _DayCard(
                    day: d,
                    slots: slots,
                    allSlots: allSlots,
                    meals: [
                      for (final m in meals)
                        if (m.day == d) m,
                    ],
                    expanded: day != null,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Un jour : ses repas, rangés par créneau, et de quoi en ajouter.
class _DayCard extends ConsumerWidget {
  const _DayCard({
    required this.day,
    required this.slots,
    required this.allSlots,
    required this.meals,
    required this.expanded,
  });

  final DateTime day;

  /// Les créneaux affichés (non masqués).
  final List<MealSlot> slots;

  /// Tous les créneaux : un repas d'un créneau masqué reste visible.
  final List<MealSlot> allSlots;
  final List<PlannedMeal> meals;

  /// Vue jour : tous les créneaux, même vides.
  final bool expanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final today = PlannedMeal.dayOf(DateTime.now()) == day;
    final shownSlots = [
      for (final s in allSlots)
        if (!s.hidden || meals.any((m) => m.slotId == s.id)) s,
    ];
    final title = DateFormat.MMMMEEEEd(locale).format(day);
    return Card(
      key: ValueKey('planning-day-${PlannedMeal.dayKey(day)}'),
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      // Aujourd'hui : une bordure et une teinte légère, pas un fond foncé.
      color: today ? scheme.primary.withValues(alpha: 0.05) : null,
      shape: today
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: scheme.primary.withValues(alpha: 0.6)),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: expanded
                  ? null
                  : () {
                      ref.read(plannedDayProvider.notifier).show(day);
                    },
              child: Text(
                title[0].toUpperCase() + title.substring(1),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: today ? scheme.primary : null,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            for (final slot in shownSlots)
              if (expanded || meals.any((m) => m.slotId == slot.id))
                _SlotTarget(
                  day: day,
                  slot: slot,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                slot.name,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: scheme.primary,
                                ),
                              ),
                            ),
                            if (expanded)
                              IconButton(
                                key: ValueKey(
                                  'planning-add-${PlannedMeal.dayKey(day)}-${slot.id}',
                                ),
                                visualDensity: VisualDensity.compact,
                                tooltip: l10n.addMealTo(slot.name),
                                icon: const Icon(Icons.add, size: 20),
                                onPressed: () => showMealSheet(
                                  context,
                                  day: day,
                                  slot: slot,
                                ),
                              ),
                          ],
                        ),
                      ),
                      for (final meal in meals)
                        if (meal.slotId == slot.id)
                          _MealTile(meal: meal, slots: allSlots),
                    ],
                  ),
                ),
            if (!expanded)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 6,
                  children: [
                    for (final slot in slots)
                      _SlotTarget(
                        day: day,
                        slot: slot,
                        child: ActionChip(
                          key: ValueKey(
                            'planning-add-${PlannedMeal.dayKey(day)}-${slot.id}',
                          ),
                          visualDensity: VisualDensity.compact,
                          avatar: const Icon(Icons.add, size: 16),
                          label: Text(slot.name),
                          onPressed: () =>
                              showMealSheet(context, day: day, slot: slot),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Un créneau d'un jour où l'on peut déposer un repas (appui long sur le
/// repas, puis glisser) : il change de créneau, ou de jour.
class _SlotTarget extends ConsumerWidget {
  const _SlotTarget({
    required this.day,
    required this.slot,
    required this.child,
  });

  final DateTime day;
  final MealSlot slot;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return DragTarget<PlannedMeal>(
      key: ValueKey('planning-slot-${PlannedMeal.dayKey(day)}-${slot.id}'),
      onWillAcceptWithDetails: (details) =>
          details.data.day != day || details.data.slotId != slot.id,
      onAcceptWithDetails: (details) => ref
          .read(planningRepositoryProvider)
          .move(details.data, day: day, slotId: slot.id),
      builder: (context, candidates, _) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: candidates.isEmpty ? null : scheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: child,
      ),
    );
  }
}

enum _MealAction { edit, date, slot, copy, leftovers, delete }

class _MealTile extends ConsumerWidget {
  const _MealTile({required this.meal, required this.slots});

  final PlannedMeal meal;
  final List<MealSlot> slots;

  String _title(AppLocalizations l10n) {
    if (!meal.isRecipe) return meal.note;
    final title = meal.recipeTitle.trim().isEmpty
        ? l10n.untitledRecipe
        : meal.recipeTitle;
    return title;
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    _MealAction action,
  ) async {
    final l10n = AppLocalizations.of(context);
    final planning = ref.read(planningRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final slot = slots.firstWhere(
      (s) => s.id == meal.slotId,
      orElse: () => slots.first,
    );
    switch (action) {
      case _MealAction.edit:
        await showMealSheet(context, day: meal.day, slot: slot, meal: meal);
      case _MealAction.date:
        final picked = await showDatePicker(
          context: context,
          initialDate: meal.day,
          firstDate: DateTime(meal.day.year - 1),
          lastDate: DateTime(meal.day.year + 2),
          helpText: l10n.changeMealDate,
        );
        if (picked != null) await planning.move(meal, day: picked);
      case _MealAction.slot:
        final chosen = await showDialog<MealSlot>(
          context: context,
          builder: (context) => SimpleDialog(
            title: Text(l10n.changeMealSlot),
            children: [
              for (final s in slots)
                if (!s.hidden || s.id == meal.slotId)
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, s),
                    child: Text(
                      s.name,
                      style: s.id == meal.slotId
                          ? const TextStyle(fontWeight: FontWeight.bold)
                          : null,
                    ),
                  ),
            ],
          ),
        );
        if (chosen != null) await planning.move(meal, slotId: chosen.id);
      case _MealAction.copy:
        final days = await showDialog<List<DateTime>>(
          context: context,
          builder: (context) => _CopyDialog(from: meal.day),
        );
        if (days != null && days.isNotEmpty) {
          await planning.copyTo(meal, days);
          messenger.showSnackBar(
            SnackBar(
              persist: false,
              content: Text(l10n.mealCopied(days.length)),
            ),
          );
        }
      case _MealAction.leftovers:
        final lunch = slots.where(
          (s) => s.id == DefaultMealSlots.idFor('Déjeuner') && !s.hidden,
        );
        final target = lunch.isNotEmpty ? lunch.first : slot;
        await planning.addLeftovers(meal, target.id);
        messenger.showSnackBar(
          SnackBar(
            persist: false,
            content: Text(l10n.leftoversAdded(target.name)),
          ),
        );
      case _MealAction.delete:
        await planning.delete(meal);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              persist: false,
              content: Text(l10n.mealRemoved(_title(l10n))),
              action: SnackBarAction(
                label: l10n.undo,
                onPressed: () => planning.restore(meal),
              ),
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final recipe = meal.isRecipe
        ? (ref.watch(recipesProvider).value ?? const <Recipe>[])
              .where((r) => r.id == meal.recipeId)
              .firstOrNull
        : null;
    final details = [
      if (meal.isLeftovers) l10n.leftovers,
      if (meal.isRecipe && meal.note.isNotEmpty) meal.note,
    ];
    final tile = InkWell(
      key: ValueKey('planning-meal-${meal.id}'),
      onTap: meal.isRecipe
          ? () => context.push('/recettes/${meal.recipeId}')
          : () => _onAction(context, ref, _MealAction.edit),
      child: Row(
        children: [
          // Une miniature carrée de la photo de la recette ; une icône pour
          // une note.
          SizedBox.square(
            dimension: 36,
            child: meal.isRecipe
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: RecipePhoto(
                      photo: recipe?.mainPhoto,
                      decodeWidth: 108,
                      iconSize: 18,
                    ),
                  )
                : Icon(
                    Icons.sticky_note_2_outlined,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_title(l10n), style: theme.textTheme.bodyLarge),
                  if (details.isNotEmpty)
                    Text(
                      details.join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
          PopupMenuButton<_MealAction>(
            key: ValueKey('planning-meal-menu-${meal.id}'),
            tooltip: MaterialLocalizations.of(context).showMenuTooltip,
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (action) => _onAction(context, ref, action),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _MealAction.edit,
                child: Text(
                  meal.isRecipe ? l10n.editMealQuantities : l10n.editMealNote,
                ),
              ),
              PopupMenuItem(
                value: _MealAction.date,
                child: Text(l10n.changeMealDate),
              ),
              PopupMenuItem(
                value: _MealAction.slot,
                child: Text(l10n.changeMealSlot),
              ),
              PopupMenuItem(
                value: _MealAction.copy,
                child: Text(l10n.copyMeal),
              ),
              if (!meal.isLeftovers)
                PopupMenuItem(
                  value: _MealAction.leftovers,
                  child: Text(l10n.leftoversTomorrow),
                ),
              PopupMenuItem(
                value: _MealAction.delete,
                child: Text(l10n.removeMeal),
              ),
            ],
          ),
        ],
      ),
    );
    return LongPressDraggable<PlannedMeal>(
      data: meal,
      feedback: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(_title(l10n), style: theme.textTheme.bodyLarge),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: tile),
      child: tile,
    );
  }
}

/// Choisir les jours où copier un repas : les deux semaines qui suivent.
class _CopyDialog extends StatefulWidget {
  const _CopyDialog({required this.from});

  final DateTime from;

  @override
  State<_CopyDialog> createState() => _CopyDialogState();
}

class _CopyDialogState extends State<_CopyDialog> {
  final _chosen = <DateTime>{};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final days = [
      for (var i = 1; i <= 14; i++)
        DateTime(widget.from.year, widget.from.month, widget.from.day + i),
    ];
    return AlertDialog(
      title: Text(l10n.copyMeal),
      content: SizedBox(
        width: 360,
        height: 420,
        child: ListView(
          children: [
            for (final d in days)
              CheckboxListTile(
                key: ValueKey('copy-${PlannedMeal.dayKey(d)}'),
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                value: _chosen.contains(d),
                title: Text(DateFormat.MMMMEEEEd(locale).format(d)),
                onChanged: (on) => setState(() {
                  on == true ? _chosen.add(d) : _chosen.remove(d);
                }),
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
          key: const ValueKey('copy-ok'),
          onPressed: _chosen.isEmpty
              ? null
              : () => Navigator.pop(context, _chosen.toList()..sort()),
          child: Text(l10n.validate),
        ),
      ],
    );
  }
}
