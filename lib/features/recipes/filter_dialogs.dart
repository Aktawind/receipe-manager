import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/durations.dart';
import '../../l10n/app_localizations.dart';
import '../equipment/equipment_providers.dart';
import 'recipe_providers.dart';

/// Les durées proposées pour limiter une recette, en minutes.
const _durationChoices = [15, 30, 45, 60, 90, 120];

/// Durée totale, préparation, cuisson : « au plus » tant de minutes.
Future<TimeLimits?> showTimeLimitsDialog(
  BuildContext context,
  TimeLimits current,
) => showDialog<TimeLimits>(
  context: context,
  builder: (context) => _TimeLimitsDialog(initial: current),
);

class _TimeLimitsDialog extends StatefulWidget {
  const _TimeLimitsDialog({required this.initial});

  final TimeLimits initial;

  @override
  State<_TimeLimitsDialog> createState() => _TimeLimitsDialogState();
}

class _TimeLimitsDialogState extends State<_TimeLimitsDialog> {
  late TimeLimits _limits = widget.initial;

  Widget _picker(
    String label,
    int? value,
    ValueChanged<int?> onChanged, {
    required Key key,
  }) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<int?>(
        key: key,
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          DropdownMenuItem(value: null, child: Text(l10n.durationAny)),
          for (final minutes in _durationChoices)
            DropdownMenuItem(
              value: minutes,
              child: Text(formatMinutes(l10n, minutes)),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.filterDuration),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _picker(
              l10n.filterDurationTotal,
              _limits.total,
              (v) => setState(() => _limits = _limits.copyWith(total: () => v)),
              key: const ValueKey('limit-total'),
            ),
            _picker(
              l10n.filterDurationPrep,
              _limits.prep,
              (v) => setState(() => _limits = _limits.copyWith(prep: () => v)),
              key: const ValueKey('limit-prep'),
            ),
            _picker(
              l10n.filterDurationCook,
              _limits.cook,
              (v) => setState(() => _limits = _limits.copyWith(cook: () => v)),
              key: const ValueKey('limit-cook'),
            ),
            Text(
              l10n.durationNote,
              style: Theme.of(context).textTheme.bodySmall,
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
          onPressed: () => Navigator.pop(context, _limits),
          child: Text(l10n.validate),
        ),
      ],
    );
  }
}

/// Le matériel dont on dispose : seules restent les recettes qui n'ont besoin
/// que de lui.
Future<Set<String>?> showEquipmentFilterDialog(
  BuildContext context,
  Set<String> current,
) => showDialog<Set<String>>(
  context: context,
  builder: (context) => _EquipmentFilterDialog(initial: current),
);

class _EquipmentFilterDialog extends ConsumerStatefulWidget {
  const _EquipmentFilterDialog({required this.initial});

  final Set<String> initial;

  @override
  ConsumerState<_EquipmentFilterDialog> createState() =>
      _EquipmentFilterDialogState();
}

class _EquipmentFilterDialogState
    extends ConsumerState<_EquipmentFilterDialog> {
  late final Set<String> _chosen = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = ref.watch(equipmentProvider).value ?? const [];
    return AlertDialog(
      title: Text(l10n.filterEquipmentTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              items.isEmpty
                  ? l10n.filterEquipmentNone
                  : l10n.filterEquipmentHelp,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            for (final item in items)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _chosen.contains(item.id),
                title: Text(item.name),
                onChanged: (on) => setState(() {
                  if (on == true) {
                    _chosen.add(item.id);
                  } else {
                    _chosen.remove(item.id);
                  }
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
          onPressed: () => Navigator.pop(context, _chosen),
          child: Text(l10n.validate),
        ),
      ],
    );
  }
}

/// La page « Chercher par ingrédients » : avec tous, avec au moins un, sans,
/// et ce qu'on a sous la main.
Future<IngredientCriteria?> showIngredientFilterPage(
  BuildContext context,
  IngredientCriteria current,
) => Navigator.of(context).push<IngredientCriteria>(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (context) => _IngredientFilterPage(initial: current),
  ),
);

class _IngredientFilterPage extends ConsumerStatefulWidget {
  const _IngredientFilterPage({required this.initial});

  final IngredientCriteria initial;

  @override
  ConsumerState<_IngredientFilterPage> createState() =>
      _IngredientFilterPageState();
}

class _IngredientFilterPageState extends ConsumerState<_IngredientFilterPage> {
  late IngredientCriteria _criteria = widget.initial;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.ingredientsPageTitle),
        actions: [
          TextButton(
            key: const ValueKey('ingredients-validate'),
            onPressed: () => Navigator.pop(context, _criteria),
            child: Text(l10n.validate),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _TermsEditor(
            fieldKey: const ValueKey('ingredients-all'),
            title: l10n.ingredientsAll,
            terms: _criteria.all,
            onChanged: (v) =>
                setState(() => _criteria = _criteria.copyWith(all: v)),
          ),
          _TermsEditor(
            fieldKey: const ValueKey('ingredients-any'),
            title: l10n.ingredientsAny,
            terms: _criteria.any,
            onChanged: (v) =>
                setState(() => _criteria = _criteria.copyWith(any: v)),
          ),
          _TermsEditor(
            fieldKey: const ValueKey('ingredients-none'),
            title: l10n.ingredientsNone,
            terms: _criteria.none,
            onChanged: (v) =>
                setState(() => _criteria = _criteria.copyWith(none: v)),
          ),
        ],
      ),
    );
  }
}

/// Une liste de mots saisis (puces) avec leur champ d'ajout.
class _TermsEditor extends StatefulWidget {
  const _TermsEditor({
    required this.fieldKey,
    required this.title,
    required this.terms,
    required this.onChanged,
  });

  final Key fieldKey;
  final String title;
  final List<String> terms;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_TermsEditor> createState() => _TermsEditorState();
}

class _TermsEditorState extends State<_TermsEditor> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (!widget.terms.contains(text)) {
      widget.onChanged([...widget.terms, text]);
    }
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: theme.textTheme.titleSmall),
          if (widget.terms.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final term in widget.terms)
                    InputChip(
                      label: Text(term),
                      onDeleted: () => widget.onChanged([
                        for (final t in widget.terms)
                          if (t != term) t,
                      ]),
                    ),
                ],
              ),
            ),
          TextField(
            key: widget.fieldKey,
            controller: _controller,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: l10n.ingredientsAdd,
              suffixIcon: IconButton(
                tooltip: l10n.ingredientsAdd,
                icon: const Icon(Icons.add),
                onPressed: _add,
              ),
            ),
            onSubmitted: (_) => _add(),
          ),
        ],
      ),
    );
  }
}
