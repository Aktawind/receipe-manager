import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_services.dart';
import '../../data/backup/backup_service.dart';
import '../../data/import/recipe_keeper_importer.dart';
import '../../l10n/app_localizations.dart';
import 'backup_actions.dart';

RecipeKeeperExport _readExport(List<int> bytes) =>
    RecipeKeeperImporter.read(bytes);

/// L'action « Importer depuis Recipe Keeper » des réglages : choix du fichier,
/// aperçu de ce qui va être fait, import, puis rapport.
class RecipeKeeperActions {
  RecipeKeeperActions(this.context, this.ref);

  final BuildContext context;
  final WidgetRef ref;

  AppLocalizations get _l10n => AppLocalizations.of(context);

  void _snack(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<void> import() async {
    final service = ref.read(backupServiceProvider);
    final bytes = await ref.read(fileGatewayProvider).pickZip();
    if (bytes == null || !context.mounted) return;

    // La lecture d'un export complet (des centaines de photos) prend un
    // moment : un indicateur évite de croire que l'app est figée.
    final navigator = Navigator.of(context, rootNavigator: true);
    unawaited(_showProgress(_l10n.rkReading));
    final RecipeKeeperExport export;
    try {
      export = await compute(_readExport, bytes);
    } on FormatException {
      navigator.pop();
      if (context.mounted) _snack(_l10n.rkNotAnExport);
      return;
    } on Object catch (error) {
      navigator.pop();
      if (context.mounted) _snack(_l10n.importFailed('$error'));
      return;
    }
    final preview = await service.previewRecipeKeeper(export.recipes);
    navigator.pop();
    if (!context.mounted) return;

    if (!await _confirm(preview, export.issues.length)) return;
    if (!context.mounted) return;

    try {
      final result = await service.import(
        BackupContents(export.recipes, export.photos),
        ImportMode.addMissing,
      );
      if (context.mounted) {
        await _report(result, preview.sameTitle, export.issues);
      }
    } on Object catch (error) {
      if (context.mounted) _snack(_l10n.importFailed('$error'));
    }
  }

  Future<void> _showProgress(String message) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 24),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirm(RecipeKeeperPreview preview, int issueCount) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l10n.importRecipeKeeper),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.rkPreviewFound(preview.found)),
                const SizedBox(height: 8),
                Text(l10n.rkPreviewToAdd(preview.toAdd)),
                if (preview.alreadyPresent > 0) ...[
                  const SizedBox(height: 8),
                  Text(l10n.rkPreviewPresent(preview.alreadyPresent)),
                ],
                if (preview.sameTitle.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(l10n.rkPreviewSameTitle(preview.sameTitle.length)),
                ],
                if (issueCount > 0) ...[
                  const SizedBox(height: 8),
                  Text(l10n.rkPreviewIssues(issueCount)),
                ],
                const SizedBox(height: 16),
                Text(
                  l10n.importSafetyNote,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: preview.toAdd == 0
                  ? null
                  : () => Navigator.pop(context, true),
              child: Text(l10n.rkImportAction),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<void> _report(
    ImportResult result,
    List<String> sameTitle,
    List<ImportIssue> issues,
  ) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        final theme = Theme.of(context);
        Widget section(String title, Iterable<String> lines) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleSmall),
            for (final line in lines) Text('• $line'),
          ],
        );
        return AlertDialog(
          title: Text(l10n.rkDoneTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.rkDoneAdded(result.added)),
                if (result.unchanged > 0)
                  Text(l10n.rkDoneSkipped(result.unchanged)),
                if (sameTitle.isNotEmpty)
                  section(l10n.rkDoneSameTitle, sameTitle),
                if (issues.isNotEmpty)
                  section(l10n.rkDoneIssues, issues.map((i) => '$i')),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.close),
            ),
          ],
        );
      },
    );
  }
}
