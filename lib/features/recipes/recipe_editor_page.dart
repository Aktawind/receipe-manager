import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/app_services.dart';
import '../../data/photo_store.dart';
import '../../data/recipe_repository.dart';
import '../../domain/ingredient_text.dart';
import '../../domain/recipe.dart';
import '../../l10n/app_localizations.dart';
import 'recipe_photo.dart';

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

/// Une ligne éditable (ingrédient ou étape) avec un identifiant stable.
class _Line {
  _Line(this.id, String text)
    : controller = TextEditingController(text: text),
      focusNode = FocusNode();

  final String id;
  final TextEditingController controller;
  final FocusNode focusNode;

  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}

class _RecipeEditorPageState extends ConsumerState<RecipeEditorPage> {
  late final RecipeRepository _repository;
  late final PhotoStore _photos;

  Recipe? _recipe;
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _servings = TextEditingController();
  final _prep = TextEditingController();
  final _cook = TextEditingController();
  final _rest = TextEditingController();
  final _timesCooked = TextEditingController();
  final _source = TextEditingController();
  final _notes = TextEditingController();
  final _tips = TextEditingController();
  final _ingredients = <_Line>[];
  final _steps = <_Line>[];
  String? _photo;
  final _replacedPhotos = <String>{};

  Timer? _saveTimer;
  Future<void>? _pendingSave;
  var _saveState = _SaveState.idle;
  var _closed = false;

  List<TextEditingController> get _fieldControllers => [
    _title,
    _description,
    _servings,
    _prep,
    _cook,
    _rest,
    _timesCooked,
    _source,
    _notes,
    _tips,
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
    if (!mounted || recipe == null) return;
    String number(int? value) => value?.toString() ?? '';
    _title.text = recipe.title;
    _description.text = recipe.description;
    _servings.text = number(recipe.servings);
    _prep.text = number(recipe.prepMinutes);
    _cook.text = number(recipe.cookMinutes);
    _rest.text = number(recipe.restMinutes);
    _timesCooked.text = recipe.timesCooked == 0 ? '' : '${recipe.timesCooked}';
    _source.text = recipe.source;
    _notes.text = recipe.notes;
    _tips.text = recipe.tips;
    _photo = recipe.mainPhoto;
    for (final line in recipe.ingredients) {
      _ingredients.add(_watch(_Line(line.id, IngredientText.format(line))));
    }
    for (final step in recipe.steps) {
      _steps.add(_watch(_Line(step.id, step.text)));
    }
    if (_ingredients.isEmpty) _ingredients.add(_watch(_newLine()));
    if (_steps.isEmpty) _steps.add(_watch(_newLine()));
    for (final controller in _fieldControllers) {
      controller.addListener(_scheduleSave);
    }
    setState(() => _recipe = recipe);
  }

  _Line _newLine() => _Line(RecipeRepository.newId(), '');

  _Line _watch(_Line line) {
    line.controller.addListener(_scheduleSave);
    return line;
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

  Recipe _build(Recipe base) {
    int? number(TextEditingController c) => int.tryParse(c.text.trim());
    return base.copyWith(
      title: _title.text.trim(),
      description: _description.text.trim(),
      servings: () => number(_servings),
      prepMinutes: () => number(_prep),
      cookMinutes: () => number(_cook),
      restMinutes: () => number(_rest),
      timesCooked: number(_timesCooked) ?? 0,
      source: _source.text.trim(),
      notes: _notes.text.trim(),
      tips: _tips.text.trim(),
      mainPhoto: () => _photo,
      ingredients: [
        for (final line in _ingredients)
          if (line.controller.text.trim().isNotEmpty)
            IngredientText.parse(line.controller.text, id: line.id),
      ],
      steps: [
        for (final line in _steps)
          if (line.controller.text.trim().isNotEmpty)
            RecipeStep(id: line.id, text: line.controller.text.trim()),
      ],
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
    for (final line in [..._ingredients, ..._steps]) {
      line.dispose();
    }
    super.dispose();
  }

  void _addLine(List<_Line> lines, {int? after}) {
    final line = _watch(_newLine());
    setState(
      () => lines.insert(after == null ? lines.length : after + 1, line),
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => line.focusNode.requestFocus(),
    );
  }

  void _removeLine(List<_Line> lines, int index) {
    final line = lines.removeAt(index);
    setState(() {});
    // Disposed after the frame: the TextField may still be using it.
    WidgetsBinding.instance.addPostFrameCallback((_) => line.dispose());
    _scheduleSave();
  }

  void _reorder(List<_Line> lines, int oldIndex, int newIndex) {
    setState(() => lines.insert(newIndex, lines.removeAt(oldIndex)));
    _scheduleSave();
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
          : CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList.list(
                    children: [
                      _PhotoField(
                        photo: _photo,
                        onTap: _showPhotoMenu,
                        label: _photo == null
                            ? l10n.addPhoto
                            : l10n.changePhoto,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _title,
                        autofocus: widget.isNew,
                        textCapitalization: TextCapitalization.sentences,
                        style: theme.textTheme.titleLarge,
                        decoration: InputDecoration(labelText: l10n.fieldTitle),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _description,
                        textCapitalization: TextCapitalization.sentences,
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: l10n.fieldDescription,
                        ),
                      ),
                      _Heading(l10n.sectionInfo),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _NumberField(_servings, l10n.fieldServings),
                          _NumberField(_prep, l10n.fieldPrepMinutes),
                          _NumberField(_cook, l10n.fieldCookMinutes),
                          _NumberField(_rest, l10n.fieldRestMinutes),
                          _NumberField(_timesCooked, l10n.fieldTimesCooked),
                        ],
                      ),
                      _Heading(l10n.ingredients),
                      Text(
                        l10n.ingredientsHelp,
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                _LineList(
                  lines: _ingredients,
                  hint: l10n.ingredientHint,
                  multiline: false,
                  onSubmitted: (index) => _addLine(_ingredients, after: index),
                  onRemove: (index) => _removeLine(_ingredients, index),
                  onReorder: (a, b) => _reorder(_ingredients, a, b),
                ),
                _AddButton(
                  label: l10n.addIngredient,
                  onPressed: () => _addLine(_ingredients),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(child: _Heading(l10n.steps)),
                ),
                _LineList(
                  lines: _steps,
                  hint: l10n.stepHint,
                  multiline: true,
                  numbered: true,
                  onRemove: (index) => _removeLine(_steps, index),
                  onReorder: (a, b) => _reorder(_steps, a, b),
                ),
                _AddButton(
                  label: l10n.addStep,
                  onPressed: () => _addLine(_steps),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 48),
                  sliver: SliverList.list(
                    children: [
                      _Heading(l10n.sectionMore),
                      _TextArea(_tips, l10n.fieldTips),
                      const SizedBox(height: 12),
                      _TextArea(_notes, l10n.fieldNotes),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _source,
                        decoration: InputDecoration(
                          labelText: l10n.fieldSource,
                        ),
                      ),
                    ],
                  ),
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

class _NumberField extends StatelessWidget {
  const _NumberField(this.controller, this.label);

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _TextArea extends StatelessWidget {
  const _TextArea(this.controller, this.label);

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textCapitalization: TextCapitalization.sentences,
      minLines: 2,
      maxLines: null,
      decoration: InputDecoration(labelText: label, alignLabelWithHint: true),
    );
  }
}

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
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            RecipePhoto(photo: photo, decodeWidth: 1080, iconSize: 56),
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
    );
  }
}

class _LineList extends StatelessWidget {
  const _LineList({
    required this.lines,
    required this.hint,
    required this.multiline,
    required this.onRemove,
    required this.onReorder,
    this.onSubmitted,
    this.numbered = false,
  });

  final List<_Line> lines;
  final String hint;
  final bool multiline;
  final bool numbered;
  final void Function(int index)? onSubmitted;
  final void Function(int index) onRemove;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SliverReorderableList(
      itemCount: lines.length,
      onReorderItem: onReorder,
      itemBuilder: (context, index) {
        final line = lines[index];
        return Material(
          key: ValueKey(line.id),
          color: theme.colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      Icons.drag_indicator,
                      semanticLabel: l10n.reorder,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (numbered)
                  Padding(
                    padding: const EdgeInsets.only(top: 14, right: 8),
                    child: Text(
                      '${index + 1}.',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                Expanded(
                  child: TextField(
                    controller: line.controller,
                    focusNode: line.focusNode,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 1,
                    maxLines: multiline ? null : 1,
                    keyboardType: multiline
                        ? TextInputType.multiline
                        : TextInputType.text,
                    textInputAction: multiline
                        ? TextInputAction.newline
                        : TextInputAction.next,
                    onSubmitted: onSubmitted == null
                        ? null
                        : (_) => onSubmitted!(index),
                    decoration: InputDecoration(
                      hintText: numbered ? l10n.stepNumber(index + 1) : hint,
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.removeLine,
                  icon: const Icon(Icons.close),
                  onPressed: () => onRemove(index),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      sliver: SliverToBoxAdapter(
        child: Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.add),
            label: Text(label),
          ),
        ),
      ),
    );
  }
}
