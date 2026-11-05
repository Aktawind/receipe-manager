/// Les champs de l'écran de modification d'une recette.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/text_search.dart';
import '../../../domain/label.dart';
import '../../../domain/recipe.dart';
import '../../../l10n/app_localizations.dart';
import '../../classification/labels_providers.dart';
import '../../equipment/equipment_providers.dart';
import '../recipe_photo.dart';

class EditorHeading extends StatelessWidget {
  const EditorHeading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 8),
      child: Text(
        text,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

/// Un grand champ de texte multi-lignes, dans un encadré qui grandit avec le
/// texte (descriptions, listes collées, notes).
class EditorBigField extends StatelessWidget {
  const EditorBigField({
    super.key,
    required this.controller,
    required this.minLines,
    this.label,
    this.hint,
    this.capitalization = TextCapitalization.sentences,
  });

  final TextEditingController controller;
  final int minLines;
  final String? label;
  final String? hint;
  final TextCapitalization capitalization;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          minLines: minLines,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          textCapitalization: capitalization,
          textAlignVertical: TextAlignVertical.top,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            hintMaxLines: 6,
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }
}

class EditorNumberField extends StatelessWidget {
  const EditorNumberField(
    this.controller,
    this.label, {
    super.key,
    this.suffix,
  });

  final TextEditingController controller;
  final String label;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label, suffixText: suffix),
    );
  }
}

/// La photo telle qu'elle s'affichera partout : un carré.
class EditorPhotoField extends StatelessWidget {
  const EditorPhotoField({
    super.key,
    required this.photo,
    required this.onTap,
    required this.label,
  });

  final String? photo;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final side = (MediaQuery.sizeOf(context).width - 32).clamp(0.0, 320.0);
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox.square(
          dimension: side,
          child: Stack(
            fit: StackFit.expand,
            children: [
              RecipePhoto(photo: photo, decodeWidth: 960, iconSize: 56),
              Material(
                color: Colors.transparent,
                child: InkWell(onTap: onTap),
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: FilledButton.tonalIcon(
                  onPressed: onTap,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(label),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.tertiaryContainer,
                    foregroundColor: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Les photos en plus de la principale : vignettes carrées, à retirer d'un
/// appui sur la croix, et une tuile pour en ajouter.
class EditorExtraPhotosField extends ConsumerWidget {
  const EditorExtraPhotosField({
    super.key,
    required this.photos,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> photos;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        height: 88,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final name in photos)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SizedBox.square(
                  dimension: 88,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: RecipePhoto(photo: name, decodeWidth: 264),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IconButton.filled(
                          tooltip: l10n.removeThisPhoto,
                          visualDensity: VisualDensity.compact,
                          iconSize: 16,
                          icon: const Icon(Icons.close),
                          onPressed: () => onRemove(name),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            InkWell(
              onTap: onAdd,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 88,
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_a_photo_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.addMorePhoto,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Le matériel de la recette : une pastille par matériel coché, et un bouton
/// qui ouvre la liste commune.
class EditorEquipmentField extends ConsumerWidget {
  const EditorEquipmentField({
    super.key,
    required this.ids,
    required this.onChoose,
    required this.onRemove,
  });

  final List<String> ids;
  final VoidCallback onChoose;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final names = {
      for (final item in ref.watch(equipmentProvider).value ?? const [])
        item.id: item.name,
    };
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final id in ids)
          if (names[id] case final name?)
            InputChip(label: Text(name), onDeleted: () => onRemove(id)),
        ActionChip(
          avatar: const Icon(Icons.checklist, size: 18),
          label: Text(l10n.chooseEquipment),
          onPressed: onChoose,
        ),
      ],
    );
  }
}

class RecipePickerDialog extends StatefulWidget {
  const RecipePickerDialog({super.key, required this.candidates});

  final List<Recipe> candidates;

  @override
  State<RecipePickerDialog> createState() => _RecipePickerDialogState();
}

class _RecipePickerDialogState extends State<RecipePickerDialog> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final query = normalizeForSearch(_query.trim());
    final shown = [
      for (final r in widget.candidates)
        if (query.isEmpty || normalizeForSearch(r.title).contains(query)) r,
    ];
    return AlertDialog(
      title: Text(l10n.chooseRecipe),
      content: SizedBox(
        width: 400,
        height: 420,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: l10n.searchRecipes,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: shown.isEmpty
                  ? Center(child: Text(l10n.noRecipeToLink))
                  : ListView.builder(
                      itemCount: shown.length,
                      itemBuilder: (context, index) => ListTile(
                        title: Text(
                          shown[index].title.isEmpty
                              ? l10n.untitledRecipe
                              : shown[index].title,
                        ),
                        onTap: () => Navigator.pop(context, shown[index]),
                      ),
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
      ],
    );
  }
}

/// Le classement de la recette, une ligne par famille : les éléments choisis
/// en pastilles et un bouton qui ouvre la liste à cocher.
class EditorClassificationField extends ConsumerWidget {
  const EditorClassificationField({
    super.key,
    required this.labelIds,
    required this.onChoose,
    required this.onRemove,
  });

  final List<String> labelIds;
  final void Function(LabelKind kind, List<Label> all) onChoose;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final all = ref.watch(labelsProvider).value ?? const <Label>[];
    final byId = {for (final l in all) l.id: l};
    const order = LabelKind.values;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final kind in order) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              kind.title(l10n),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final id in labelIds)
                if (byId[id] case final label? when label.kind == kind)
                  InputChip(
                    label: Text(labelPath(label, byId)),
                    onDeleted: () => onRemove(id),
                  ),
              ActionChip(
                key: ValueKey('classification-${kind.code}'),
                avatar: const Icon(Icons.checklist, size: 18),
                label: Text(l10n.chooseLabels),
                onPressed: () => onChoose(kind, all),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
