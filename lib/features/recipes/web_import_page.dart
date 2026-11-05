import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/durations.dart';
import '../../data/app_services.dart';
import '../../data/import/page_scanner.dart';
import '../../data/import/text_recipe.dart';
import '../../data/import/web_import.dart';
import '../../data/import/web_recipe.dart';
import '../../domain/ingredient_text.dart';
import '../../domain/step_text.dart';
import '../../l10n/app_localizations.dart';

/// Photographie et lit les pages de livres. Remplacé dans les tests.
final pageScannerProvider = Provider<PageScanner>(
  (ref) => const MlKitPageScanner(),
);

/// Télécharge et lit les pages de recettes. Remplacé dans les tests.
final webImporterProvider = Provider<WebImporter>((ref) {
  final importer = WebImporter();
  ref.onDispose(importer.close);
  return importer;
});

/// Importer une recette : depuis une adresse web (saisie, collée ou partagée
/// depuis le navigateur) ou depuis un texte collé (réponse d'une IA, message).
/// Lecture, aperçu, puis import et correction dans l'éditeur.
class WebImportPage extends ConsumerStatefulWidget {
  const WebImportPage({super.key, this.initialUrl, this.initialText});

  /// L'adresse partagée depuis une autre app ; vide pour la saisir.
  final String? initialUrl;

  /// Un texte partagé depuis une autre app (sans adresse) : la recette elle-même.
  final String? initialText;

  @override
  ConsumerState<WebImportPage> createState() => _WebImportPageState();
}

class _WebImportPageState extends ConsumerState<WebImportPage> {
  final _url = TextEditingController();
  final _text = TextEditingController();
  var _textMode = false;
  var _photoMode = false;
  var _scanning = false;

  /// Le scanner de Google s'ouvre (ou se télécharge), avec l'avancement du
  /// téléchargement s'il y en a un.
  var _opening = false;
  int? _downloadPercent;
  PageScanError? _scanError;
  var _scanErrorDetail = '';
  var _loading = false;
  var _saving = false;
  WebRecipe? _recipe;
  WebImportError? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialUrl;
    final text = widget.initialText;
    if (initial != null && initial.isNotEmpty) {
      _url.text = initial;
      WidgetsBinding.instance.addPostFrameCallback((_) => _read());
    } else if (text != null && text.trim().isNotEmpty) {
      _textMode = true;
      _text.text = text;
      WidgetsBinding.instance.addPostFrameCallback((_) => _readText());
    } else {
      _pasteFromClipboard();
    }
  }

  @override
  void dispose() {
    _url.dispose();
    _text.dispose();
    super.dispose();
  }

  /// Ce que contient le presse-papiers est proposé d'office : une adresse, ou
  /// le texte d'une recette (copié depuis une IA, par exemple).
  Future<void> _pasteFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final clip = data?.text ?? '';
      if (!mounted || clip.trim().isEmpty) return;
      final url = findUrl(clip);
      if (looksLikeRecipeText(clip)) {
        setState(() {
          _textMode = true;
          if (_text.text.isEmpty) _text.text = clip;
        });
      } else if (url != null && _url.text.isEmpty) {
        setState(() => _url.text = url.toString());
      }
    } on PlatformException {
      // Presse-papiers inaccessible : on saisit à la main.
    }
  }

  /// Scanner une ou plusieurs pages, en lire le texte, puis le montrer dans
  /// l'onglet « Texte » (pour corriger une erreur de lecture) et l'analyser.
  Future<void> _scan({bool? camera}) async {
    final scanner = ref.read(pageScannerProvider);
    setState(() {
      _scanError = null;
      _recipe = null;
      _error = null;
    });
    setState(() {
      _opening = camera == null;
      _downloadPercent = null;
    });
    try {
      final images = camera == null
          ? await scanner.scan(
              onDownload: (percent) {
                if (mounted) setState(() => _downloadPercent = percent);
              },
            )
          : await scanner.pick(camera: camera);
      if (mounted) setState(() => _opening = false);
      if (images == null || !mounted) return;
      setState(() => _scanning = true);
      final text = await scanner.read(images);
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _photoMode = false;
        _textMode = true;
        _text.text = text;
      });
      _readText();
    } on PageScanException catch (e) {
      if (mounted) {
        setState(() {
          _scanning = false;
          _opening = false;
          _scanError = e.error;
          _scanErrorDetail = e.detail;
        });
      }
    }
  }

  void _readText() {
    FocusScope.of(context).unfocus();
    final recipe = TextRecipeParser.parse(_text.text);
    setState(() {
      _recipe = recipe.ingredients.isEmpty && recipe.steps.isEmpty
          ? null
          : recipe;
      _error = _recipe == null ? WebImportError.noRecipe : null;
    });
  }

  Future<void> _read() async {
    final url = findUrl(_url.text.trim()) ?? Uri.tryParse(_url.text.trim());
    if (url == null || !url.hasScheme || url.host.isEmpty) {
      setState(() {
        _error = WebImportError.invalidUrl;
        _recipe = null;
      });
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _recipe = null;
    });
    try {
      final recipe = await ref.read(webImporterProvider).fetch(url);
      if (mounted) setState(() => _recipe = recipe);
    } on WebImportException catch (e) {
      if (mounted) setState(() => _error = e.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _import() async {
    final web = _recipe;
    if (web == null) return;
    setState(() => _saving = true);
    final repository = ref.read(recipeRepositoryProvider);
    final photo = await ref
        .read(webImporterProvider)
        .downloadPhoto(web.imageUrl, ref.read(photoStoreProvider));
    final created = await repository.create();
    final saved = await repository.save(
      applyWebRecipe(created, web, photo: photo),
    );
    if (!mounted) return;
    // La fiche, puis l'éditeur par-dessus pour corriger ce qui doit l'être.
    context.go('/recettes/${saved.id}');
    unawaited(context.push('/recettes/${saved.id}/modifier'));
  }

  /// Le site ne donne rien de lisible : on crée la recette à la main, avec
  /// l'adresse en source.
  Future<void> _createByHand() async {
    final repository = ref.read(recipeRepositoryProvider);
    final created = await repository.create();
    final url = _url.text.trim();
    if (_textMode) {
      await repository.save(created.copyWith(notes: _text.text.trim()));
    } else if (url.isNotEmpty) {
      await repository.save(created.copyWith(source: url));
    }
    if (!mounted) return;
    context.pushReplacement('/recettes/${created.id}/modifier?nouvelle=1');
  }

  String _errorText(AppLocalizations l10n, WebImportError error) =>
      switch (error) {
        WebImportError.invalidUrl => l10n.webImportInvalidUrl,
        WebImportError.network => l10n.webImportNetwork,
        WebImportError.http => l10n.webImportHttp,
        WebImportError.noRecipe =>
          _textMode ? l10n.textImportNothing : l10n.webImportNoRecipe,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final recipe = _recipe;
    final error = _error;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.webImportTitle)),
      bottomNavigationBar: recipe == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  key: const ValueKey('web-import-save'),
                  onPressed: _saving ? null : _import,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download),
                  label: Text(l10n.webImportSave),
                ),
              ),
            ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          SegmentedButton<int>(
            segments: [
              ButtonSegment(
                value: 0,
                icon: const Icon(Icons.public),
                label: Text(
                  l10n.importModeWeb,
                  key: const ValueKey('import-mode-web'),
                ),
              ),
              ButtonSegment(
                value: 1,
                icon: const Icon(Icons.notes),
                label: Text(
                  l10n.importModeText,
                  key: const ValueKey('import-mode-text'),
                ),
              ),
              ButtonSegment(
                value: 2,
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(
                  l10n.importModePhoto,
                  key: const ValueKey('import-mode-photo'),
                ),
              ),
            ],
            showSelectedIcon: false,
            selected: {
              _photoMode
                  ? 2
                  : _textMode
                  ? 1
                  : 0,
            },
            onSelectionChanged: (selection) => setState(() {
              _photoMode = selection.first == 2;
              _textMode = selection.first == 1;
              _recipe = null;
              _error = null;
              _scanError = null;
            }),
          ),
          const SizedBox(height: 16),
          if (_photoMode) ...[
            Text(l10n.photoImportHelp, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('photo-import-scan'),
              onPressed: _scanning ? null : _scan,
              icon: const Icon(Icons.document_scanner_outlined),
              label: Text(l10n.photoImportScan),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('photo-import-camera'),
                    onPressed: _scanning ? null : () => _scan(camera: true),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text(l10n.photoImportCamera),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('photo-import-gallery'),
                    onPressed: _scanning ? null : () => _scan(camera: false),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(l10n.photoImportGallery),
                  ),
                ),
              ],
            ),
            if (_opening)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  key: const ValueKey('photo-import-opening'),
                  children: [
                    if (_downloadPercent case final percent?) ...[
                      LinearProgressIndicator(value: percent / 100),
                      const SizedBox(height: 8),
                      Text(l10n.photoImportDownloading(percent)),
                    ] else ...[
                      const CircularProgressIndicator(),
                      const SizedBox(height: 8),
                      Text(l10n.photoImportOpeningShort),
                    ],
                  ],
                ),
              ),
            if (_scanning)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(l10n.photoImportReading),
                  ],
                ),
              ),
            if (_scanError case final scanError?) ...[
              const SizedBox(height: 16),
              Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scanError == PageScanError.noText
                            ? l10n.photoImportNoText
                            : l10n.photoImportUnavailable,
                        key: const ValueKey('photo-import-error'),
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                      if (_scanErrorDetail.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        SelectableText(
                          l10n.photoImportDetail(_scanErrorDetail),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ] else if (_textMode) ...[
            TextField(
              key: const ValueKey('text-import-field'),
              controller: _text,
              minLines: 8,
              maxLines: 16,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                labelText: l10n.textImportField,
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: l10n.webImportPaste,
                  icon: const Icon(Icons.content_paste),
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    final clip = data?.text ?? '';
                    if (clip.isNotEmpty) setState(() => _text.text = clip);
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              key: const ValueKey('text-import-read'),
              onPressed: _readText,
              icon: const Icon(Icons.auto_fix_high),
              label: Text(l10n.textImportRead),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.textImportHelp,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ] else ...[
            TextField(
              key: const ValueKey('web-import-url'),
              controller: _url,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: l10n.webImportUrl,
                hintText: 'https://…',
                suffixIcon: IconButton(
                  tooltip: l10n.webImportPaste,
                  icon: const Icon(Icons.content_paste),
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    final url = findUrl(data?.text ?? '');
                    if (url != null) setState(() => _url.text = url.toString());
                  },
                ),
              ),
              onSubmitted: (_) => _read(),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              key: const ValueKey('web-import-read'),
              onPressed: _loading ? null : _read,
              icon: const Icon(Icons.travel_explore),
              label: Text(l10n.webImportRead),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.webImportHelp,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (error != null) ...[
            const SizedBox(height: 24),
            Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _errorText(l10n, error),
                      key: const ValueKey('web-import-error'),
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      key: const ValueKey('web-import-by-hand'),
                      onPressed: _createByHand,
                      icon: const Icon(Icons.edit_note),
                      label: Text(l10n.webImportByHand),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (recipe != null) ...[
            const SizedBox(height: 24),
            _Preview(recipe: recipe),
          ],
        ],
      ),
    );
  }
}

/// Ce qui sera importé, tel que l'app l'a compris.
class _Preview extends StatelessWidget {
  const _Preview({required this.recipe});

  final WebRecipe recipe;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final ingredients = IngredientText.parseList(recipe.ingredients.join('\n'));
    final steps = StepText.parse(recipe.steps.join('\n'));
    final facts = [
      if (recipe.servings case final s?)
        recipe.servingsUnit.isEmpty
            ? l10n.personsShort(s)
            : '$s ${recipe.servingsUnit}',
      if (recipe.prepMinutes case final m?)
        '${l10n.prepTime} ${formatMinutes(l10n, m)}',
      if (recipe.cookMinutes case final m?)
        '${l10n.cookTime} ${formatMinutes(l10n, m)}',
    ];
    final image = recipe.imageUrl;

    return Column(
      key: const ValueKey('web-import-preview'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (image != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 1,
              child: Image.network(
                image.toString(),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => ColoredBox(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.image_not_supported_outlined),
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          recipe.title.isEmpty ? l10n.untitledRecipe : recipe.title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        if (facts.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(facts.join(' · '), style: muted),
        ],
        const SizedBox(height: 4),
        if (recipe.source case final source?) Text(source.host, style: muted),
        const SizedBox(height: 16),
        Text(
          l10n.webImportIngredientsCount(ingredients.length),
          style: theme.textTheme.titleMedium,
        ),
        for (final line in ingredients)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              line.isSection ? line.name : '• ${IngredientText.format(line)}',
              style: line.isSection
                  ? theme.textTheme.titleSmall
                  : theme.textTheme.bodyMedium,
            ),
          ),
        const SizedBox(height: 16),
        Text(
          l10n.webImportStepsCount(steps.length),
          style: theme.textTheme.titleMedium,
        ),
        for (final (index, step) in steps.indexed)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${index + 1}. ${step.title.isEmpty ? '' : '${step.title} — '}${step.text}',
              style: theme.textTheme.bodyMedium,
            ),
          ),
      ],
    );
  }
}
