import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/format/text_search.dart';
import '../../data/app_services.dart';
import '../../data/photo_store.dart';
import '../../data/recipe_repository.dart';
import '../../domain/ingredient_text.dart';
import '../../domain/recipe.dart';
import '../../domain/step_text.dart';
import '../../l10n/app_localizations.dart';
import 'recipe_photo.dart';
import '../equipment/equipment_page.dart';
import '../equipment/equipment_providers.dart';
import 'recipe_providers.dart';

/// Délai entre la dernière frappe et l'enregistrement automatique.
const autosaveDelay = Duration(milliseconds: 800);

class RecipeEditorPage extends ConsumerStatefulWidget {
  const RecipeEditorPage({
    super.key,
    required this.recipeId,
    this.isNew = false,
  });

  final String recipeId;

  /// Recette créée à l'ouverture : elle est supprimée si on la quitte vide.
  final bool isNew;

  @override
  ConsumerState<RecipeEditorPage> createState() => _RecipeEditorPageState();
}

enum _SaveState { idle, saving, saved }

class _RecipeEditorPageState extends ConsumerState<RecipeEditorPage> {
  late final RecipeRepository _repository;
  late final PhotoStore _photos;

  Recipe? _recipe;
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _servings = TextEditingController();
  final _servingsUnit = TextEditingController();
  final _prep = TextEditingController();
  final _cook = TextEditingController();
  final _rest = TextEditingController();
  final _timesCooked = TextEditingController();
  final _source = TextEditingController();
  final _notes = TextEditingController();
  final _ingredients = TextEditingController();
  final _steps = TextEditingController();
  final _videos = TextEditingController();
  String? _photo;
  var _extraPhotos = <String>[];
  var _equipmentIds = <String>[];

  /// Les autres recettes, pour lier une pâte ou une sauce dans les ingrédients.
  var _known = const <Recipe>[];
  final _replacedPhotos = <String>{};

  Timer? _saveTimer;
  Future<void>? _pendingSave;
  var _saveState = _SaveState.idle;
  var _closed = false;

  List<TextEditingController> get _fieldControllers => [
    _title,
    _description,
    _servings,
    _servingsUnit,
    _prep,
    _cook,
    _rest,
    _timesCooked,
    _source,
    _notes,
    _ingredients,
    _steps,
    _videos,
  ];

  @override
  void initState() {
    super.initState();
    _repository = ref.read(recipeRepositoryProvider);
    _photos = ref.read(photoStoreProvider);
    _load();
  }

  Future<void> _load() async {
    final recipe = await _repository.getRecipe(widget.recipeId);
    _known = await ref.read(recipesProvider.future);
    if (!mounted || recipe == null) return;
    String number(int? value) => value?.toString() ?? '';
    _title.text = recipe.title;
    _description.text = recipe.description;
    _servings.text = number(recipe.servings);
    _servingsUnit.text = recipe.servingsUnit;
    _prep.text = number(recipe.prepMinutes);
    _cook.text = number(recipe.cookMinutes);
    _rest.text = number(recipe.restMinutes);
    _timesCooked.text = recipe.timesCooked == 0 ? '' : '${recipe.timesCooked}';
    _source.text = recipe.source;
    _notes.text = recipe.notes;
    _photo = recipe.mainPhoto;
    _ingredients.text = IngredientText.formatList(
      recipe.ingredients,
      titleOf: _titleOf,
    );
    _steps.text = StepText.format(recipe.steps);
    _videos.text = recipe.videoLinks.join('\n');
    _extraPhotos = [...recipe.extraPhotos];
    _equipmentIds = [...recipe.equipmentIds];
    for (final controller in _fieldControllers) {
      controller.addListener(_scheduleSave);
    }
    setState(() => _recipe = recipe);
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(autosaveDelay, _save);
  }

  Future<void> _save() {
    _saveTimer?.cancel();
    final base = _recipe;
    if (base == null) return Future.value();
    final previous = _pendingSave ?? Future<void>.value();
    final recipe = _build(base);
    if (mounted && !_closed) setState(() => _saveState = _SaveState.saving);
    final future = previous.then((_) async {
      final saved = await _repository.save(recipe);
      _recipe = saved;
      if (mounted && !_closed) setState(() => _saveState = _SaveState.saved);
    });
    _pendingSave = future;
    return future;
  }

  RecipeRef? _resolveRecipe(String title) {
    final key = normalizeForSearch(title.trim());
    for (final recipe in _known) {
      if (recipe.id != widget.recipeId &&
          normalizeForSearch(recipe.title.trim()) == key) {
        return (id: recipe.id, title: recipe.title.trim());
      }
    }
    return null;
  }

  String? _titleOf(String id) {
    for (final recipe in _known) {
      if (recipe.id == id) return recipe.title.trim();
    }
    return null;
  }

  List<String> _lines(TextEditingController controller) => [
    for (final line in controller.text.split('\n'))
      if (line.trim().isNotEmpty) line.trim(),
  ];

  Recipe _build(Recipe base) {
    int? number(TextEditingController c) => int.tryParse(c.text.trim());
    return base.copyWith(
      title: _title.text.trim(),
      description: _description.text.trim(),
      servings: () => number(_servings),
      servingsUnit: _servingsUnit.text.trim(),
      prepMinutes: () => number(_prep),
      cookMinutes: () => number(_cook),
      restMinutes: () => number(_rest),
      timesCooked: number(_timesCooked) ?? 0,
      source: _source.text.trim(),
      notes: _notes.text.trim(),
      mainPhoto: () => _photo,
      extraPhotos: _extraPhotos,
      equipmentIds: _equipmentIds,
      videoLinks: _lines(_videos),
      ingredients: IngredientText.parseList(
        _ingredients.text,
        previousIds: [for (final line in base.ingredients) line.id],
        resolveRecipe: _resolveRecipe,
      ),
      steps: StepText.parse(
        _steps.text,
        previousIds: [for (final step in base.steps) step.id],
      ),
    );
  }

  /// Dernier enregistrement à la sortie, puis nettoyage : recette neuve
  /// restée vide, photos remplacées.
  Future<void> _close() async {
    if (_closed) return;
    _closed = true;
    final base = _recipe;
    if (base == null) return;
    if (widget.isNew && _build(base).isBlank) {
      _saveTimer?.cancel();
      await _pendingSave;
      final unused = await _repository.deletePermanently([base.id]);
      await _photos.deleteAll({...unused, ..._replacedPhotos});
      return;
    }
    await _save();
    if (_replacedPhotos.isNotEmpty) {
      final used = await _repository.usedPhotos();
      await _photos.deleteAll(_replacedPhotos.difference(used));
    }
  }

  @override
  void dispose() {
    unawaited(_close());
    for (final controller in _fieldControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final l10n = AppLocalizations.of(context);
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );
      if (picked == null) return;
      final name = await _photos.add(File(picked.path));
      setState(() {
        if (_photo != null) _replacedPhotos.add(_photo!);
        _photo = name;
      });
      _scheduleSave();
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.photoError('$error'))));
    }
  }

  Future<void> _addExtraPhoto() async {
    final l10n = AppLocalizations.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.takePhoto),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.chooseFromGallery),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );
      if (picked == null) return;
      final name = await _photos.add(File(picked.path));
      setState(() => _extraPhotos = [..._extraPhotos, name]);
      _scheduleSave();
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.photoError('$error'))));
    }
  }

  void _removeExtraPhoto(String name) {
    setState(() {
      _extraPhotos = [..._extraPhotos]..remove(name);
      _replacedPhotos.add(name);
    });
    _scheduleSave();
  }

  /// Ajoute, sur la ligne suivante des ingrédients, une recette choisie dans
  /// la liste : « [[Pâte brisée]] », que l'on peut faire précéder d'une
  /// quantité (« 1 [[Pâte brisée]] »).
  Future<void> _insertRecipe() async {
    final candidates = [
      for (final r in _known)
        if (r.id != widget.recipeId && r.title.trim().isNotEmpty) r,
    ];
    final chosen = await showDialog<Recipe>(
      context: context,
      builder: (context) => _RecipePickerDialog(candidates: candidates),
    );
    if (chosen == null) return;
    final value = _ingredients.value;
    final text = value.text;
    final offset = value.selection.isValid ? value.selection.end : text.length;
    final newline = text.indexOf('\n', offset);
    final end = newline < 0 ? text.length : newline;
    final before = text.substring(0, end);
    final line = '[[${chosen.title.trim()}]]';
    final insertion = before.isEmpty || before.endsWith('\n')
        ? line
        : '\n$line';
    _ingredients.value = TextEditingValue(
      text: before + insertion + text.substring(end),
      selection: TextSelection.collapsed(
        offset: before.length + insertion.length,
      ),
    );
  }

  Future<void> _chooseEquipment() async {
    final chosen = await pickEquipment(context, selected: _equipmentIds);
    if (chosen == null) return;
    setState(() => _equipmentIds = chosen);
    _scheduleSave();
  }

  /// Entoure le texte sélectionné de [marker] (« ** » gras, « * » italique) ;
  /// sans sélection, pose les deux marqueurs et place le curseur entre eux.
  void _wrapSelection(String marker) {
    final value = _steps.value;
    final selection = value.selection;
    if (!selection.isValid) return;
    final text = value.text;
    final selected = selection.textInside(text);
    final replacement = '$marker$selected$marker';
    final updated = text.replaceRange(
      selection.start,
      selection.end,
      replacement,
    );
    final caret = selection.isCollapsed
        ? selection.start + marker.length
        : selection.start + replacement.length;
    _steps.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: caret),
    );
  }

  void _removePhoto() {
    setState(() {
      if (_photo != null) _replacedPhotos.add(_photo!);
      _photo = null;
    });
    _scheduleSave();
  }

  Future<void> _showPhotoMenu() async {
    final l10n = AppLocalizations.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.takePhoto),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.chooseFromGallery),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            if (_photo != null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(l10n.removePhoto),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
          ],
        ),
      ),
    );
    switch (choice) {
      case 'camera':
        await _pickPhoto(ImageSource.camera);
      case 'gallery':
        await _pickPhoto(ImageSource.gallery);
      case 'remove':
        _removePhoto();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final recipe = _recipe;
    _known = ref.watch(recipesProvider).value ?? _known;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? l10n.editorTitleNew : l10n.editorTitleEdit),
        actions: [
          if (_saveState != _SaveState.idle)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  _saveState == _SaveState.saving ? l10n.saving : l10n.saved,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
          IconButton(
            tooltip: MaterialLocalizations.of(context).okButtonLabel,
            icon: const Icon(Icons.check),
            onPressed: () => Navigator.maybePop(context),
          ),
        ],
      ),
      body: recipe == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              // Marge du bas : la barre de navigation Android ne doit pas
              // recouvrir la fin du formulaire.
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                48 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                _PhotoField(
                  photo: _photo,
                  onTap: _showPhotoMenu,
                  label: _photo == null ? l10n.addPhoto : l10n.changePhoto,
                ),
                _ExtraPhotosField(
                  photos: _extraPhotos,
                  onAdd: _addExtraPhoto,
                  onRemove: _removeExtraPhoto,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _title,
                  autofocus: widget.isNew,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 1,
                  maxLines: 3,
                  style: theme.textTheme.titleLarge,
                  decoration: InputDecoration(labelText: l10n.fieldTitle),
                ),
                const SizedBox(height: 16),
                _BigField(
                  key: const ValueKey('field-description'),
                  controller: _description,
                  label: l10n.fieldDescription,
                  hint: l10n.fieldDescriptionHint,
                  minLines: 3,
                ),
                _Heading(l10n.sectionInfo),
                Row(
                  children: [
                    Expanded(
                      child: _NumberField(_servings, l10n.fieldServings),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        key: const ValueKey('field-servings-unit'),
                        controller: _servingsUnit,
                        decoration: InputDecoration(
                          labelText: l10n.fieldServingsUnit,
                          hintText: l10n.fieldServingsUnitHint,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _NumberField(_timesCooked, l10n.fieldTimesCooked),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(child: SizedBox.shrink()),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _NumberField(
                        _prep,
                        l10n.fieldPrepMinutes,
                        suffix: l10n.minutesUnit,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _NumberField(
                        _cook,
                        l10n.fieldCookMinutes,
                        suffix: l10n.minutesUnit,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _NumberField(
                        _rest,
                        l10n.fieldRestMinutes,
                        suffix: l10n.minutesUnit,
                      ),
                    ),
                  ],
                ),
                _Heading(l10n.fieldIngredients),
                _BigField(
                  key: const ValueKey('field-ingredients'),
                  controller: _ingredients,
                  hint: l10n.ingredientsHint,
                  minLines: 8,
                  capitalization: TextCapitalization.none,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _insertRecipe,
                    icon: const Icon(Icons.add_link),
                    label: Text(l10n.insertRecipe),
                  ),
                ),
                _Heading(l10n.equipment),
                _EquipmentField(
                  ids: _equipmentIds,
                  onChoose: _chooseEquipment,
                  onRemove: (id) {
                    setState(
                      () => _equipmentIds = [..._equipmentIds]..remove(id),
                    );
                    _scheduleSave();
                  },
                ),
                _Heading(l10n.fieldSteps),
                Row(
                  children: [
                    IconButton.outlined(
                      tooltip: l10n.formatBold,
                      icon: const Icon(Icons.format_bold),
                      onPressed: () => _wrapSelection('**'),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      tooltip: l10n.formatItalic,
                      icon: const Icon(Icons.format_italic),
                      onPressed: () => _wrapSelection('*'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _BigField(
                  key: const ValueKey('field-steps'),
                  controller: _steps,
                  hint: l10n.stepsHint,
                  minLines: 8,
                ),
                _Heading(l10n.fieldNotes),
                _BigField(
                  key: const ValueKey('field-notes'),
                  controller: _notes,
                  hint: l10n.fieldNotesHint,
                  minLines: 3,
                ),
                _Heading(l10n.sectionAbout),
                TextField(
                  key: const ValueKey('field-source'),
                  controller: _source,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(labelText: l10n.fieldSource),
                ),
                const SizedBox(height: 12),
                _BigField(
                  key: const ValueKey('field-videos'),
                  controller: _videos,
                  label: l10n.fieldVideos,
                  minLines: 2,
                  capitalization: TextCapitalization.none,
                ),
              ],
            ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

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
class _BigField extends StatelessWidget {
  const _BigField({
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

class _NumberField extends StatelessWidget {
  const _NumberField(this.controller, this.label, {this.suffix});

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
class _PhotoField extends StatelessWidget {
  const _PhotoField({
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
class _ExtraPhotosField extends ConsumerWidget {
  const _ExtraPhotosField({
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
class _EquipmentField extends ConsumerWidget {
  const _EquipmentField({
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

class _RecipePickerDialog extends StatefulWidget {
  const _RecipePickerDialog({required this.candidates});

  final List<Recipe> candidates;

  @override
  State<_RecipePickerDialog> createState() => _RecipePickerDialogState();
}

class _RecipePickerDialogState extends State<_RecipePickerDialog> {
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
