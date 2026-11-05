import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/format/text_search.dart';
import '../../data/app_services.dart';
import '../../data/photo_store.dart';
import '../../data/recipe_repository.dart';
import '../../domain/ingredient_text.dart';
import '../../domain/label.dart';
import '../../domain/recipe.dart';
import '../../domain/step_text.dart';
import '../../l10n/app_localizations.dart';
import '../classification/label_picker.dart';
import '../equipment/equipment_page.dart';
import 'editor/editor_fields.dart';
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
  final _source = TextEditingController();
  final _notes = TextEditingController();
  final _ingredients = TextEditingController();
  final _steps = TextEditingController();
  final _videos = TextEditingController();
  String? _photo;
  var _extraPhotos = <String>[];
  var _equipmentIds = <String>[];
  var _labelIds = <String>[];

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
    _labelIds = [...recipe.labelIds];
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
      source: _source.text.trim(),
      notes: _notes.text.trim(),
      mainPhoto: () => _photo,
      extraPhotos: _extraPhotos,
      equipmentIds: _equipmentIds,
      labelIds: _labelIds,
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
      builder: (context) => RecipePickerDialog(candidates: candidates),
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

  /// Remplace le classement d'une famille par le choix de la personne ; les
  /// autres familles ne bougent pas.
  Future<void> _chooseLabels(LabelKind kind, List<Label> all) async {
    final ofKind = {
      for (final l in all)
        if (l.kind == kind) l.id,
    };
    final chosen = await pickLabels(
      context,
      kind: kind,
      selected: [
        for (final id in _labelIds)
          if (ofKind.contains(id)) id,
      ],
    );
    if (chosen == null) return;
    setState(() {
      _labelIds = [
        for (final id in _labelIds)
          if (!ofKind.contains(id)) id,
        ...chosen,
      ];
    });
    _scheduleSave();
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
                EditorPhotoField(
                  photo: _photo,
                  onTap: _showPhotoMenu,
                  label: _photo == null ? l10n.addPhoto : l10n.changePhoto,
                ),
                EditorExtraPhotosField(
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
                EditorBigField(
                  key: const ValueKey('field-description'),
                  controller: _description,
                  label: l10n.fieldDescription,
                  hint: l10n.fieldDescriptionHint,
                  minLines: 3,
                ),
                EditorHeading(l10n.sectionInfo),
                Row(
                  children: [
                    Expanded(
                      child: EditorNumberField(_servings, l10n.fieldServings),
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
                      child: EditorNumberField(
                        _prep,
                        l10n.fieldPrepMinutes,
                        suffix: l10n.minutesUnit,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: EditorNumberField(
                        _cook,
                        l10n.fieldCookMinutes,
                        suffix: l10n.minutesUnit,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: EditorNumberField(
                        _rest,
                        l10n.fieldRestMinutes,
                        suffix: l10n.minutesUnit,
                      ),
                    ),
                  ],
                ),
                EditorHeading(l10n.fieldIngredients),
                EditorBigField(
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
                EditorHeading(l10n.equipment),
                EditorEquipmentField(
                  ids: _equipmentIds,
                  onChoose: _chooseEquipment,
                  onRemove: (id) {
                    setState(
                      () => _equipmentIds = [..._equipmentIds]..remove(id),
                    );
                    _scheduleSave();
                  },
                ),
                EditorHeading(l10n.fieldSteps),
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
                EditorBigField(
                  key: const ValueKey('field-steps'),
                  controller: _steps,
                  hint: l10n.stepsHint,
                  minLines: 8,
                ),
                EditorHeading(l10n.fieldNotes),
                EditorBigField(
                  key: const ValueKey('field-notes'),
                  controller: _notes,
                  hint: l10n.fieldNotesHint,
                  minLines: 3,
                ),
                EditorHeading(l10n.sectionAbout),
                TextField(
                  key: const ValueKey('field-source'),
                  controller: _source,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(labelText: l10n.fieldSource),
                ),
                const SizedBox(height: 12),
                EditorBigField(
                  key: const ValueKey('field-videos'),
                  controller: _videos,
                  label: l10n.fieldVideos,
                  minLines: 2,
                  capitalization: TextCapitalization.none,
                ),
                const SizedBox(height: 8),
                EditorClassificationField(
                  labelIds: _labelIds,
                  onChoose: _chooseLabels,
                  onRemove: (id) {
                    setState(() => _labelIds = [..._labelIds]..remove(id));
                    _scheduleSave();
                  },
                ),
              ],
            ),
    );
  }
}
