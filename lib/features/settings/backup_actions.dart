import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/app_services.dart';
import '../../data/backup/backup_format.dart';
import '../../data/backup/backup_service.dart';
import '../../l10n/app_localizations.dart';

/// Accès aux fichiers du système (sélecteur, partage). Remplaçable en test.
abstract class FileGateway {
  /// Enregistre [bytes] à l'endroit choisi par l'utilisateur. `false` si annulé.
  Future<bool> save(String fileName, Uint8List bytes);

  Future<void> share(String fileName, Uint8List bytes);

  /// Contenu du fichier choisi, ou `null` si annulé.
  Future<Uint8List?> pickZip();
}

class SystemFileGateway implements FileGateway {
  const SystemFileGateway();

  @override
  Future<bool> save(String fileName, Uint8List bytes) async {
    final uri = await FilePicker.saveFile(fileName: fileName, bytes: bytes);
    return uri != null;
  }

  @override
  Future<void> share(String fileName, Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path, mimeType: 'application/zip')]),
    );
  }

  @override
  Future<Uint8List?> pickZip() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (files.isEmpty) return null;
    return files.first.xFile.readAsBytes();
  }
}

final fileGatewayProvider = Provider<FileGateway>(
  (ref) => const SystemFileGateway(),
);

/// Les actions « Exporter », « Partager » et « Importer » des réglages.
class BackupActions {
  BackupActions(this.context, this.ref);

  final BuildContext context;
  final WidgetRef ref;

  AppLocalizations get _l10n => AppLocalizations.of(context);

  void _snack(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<void> export() async {
    final service = ref.read(backupServiceProvider);
    try {
      final bytes = Uint8List.fromList(await service.exportZip());
      final saved = await ref
          .read(fileGatewayProvider)
          .save(service.exportFileName(), bytes);
      if (saved && context.mounted) _snack(_l10n.backupSaved);
    } on Object catch (error) {
      if (context.mounted) _snack(_l10n.backupFailed('$error'));
    }
  }

  Future<void> share() async {
    final service = ref.read(backupServiceProvider);
    try {
      final bytes = Uint8List.fromList(await service.exportZip());
      await ref
          .read(fileGatewayProvider)
          .share(service.exportFileName(), bytes);
    } on Object catch (error) {
      if (context.mounted) _snack(_l10n.backupFailed('$error'));
    }
  }

  Future<void> import() async {
    final service = ref.read(backupServiceProvider);
    final bytes = await ref.read(fileGatewayProvider).pickZip();
    if (bytes == null || !context.mounted) return;

    final BackupContents contents;
    try {
      contents = service.readZip(bytes);
    } on BackupFormatException catch (error) {
      _snack(switch (error.error) {
        BackupError.notABackup => _l10n.importErrorNotABackup,
        BackupError.newerVersion => _l10n.importErrorNewerVersion,
        BackupError.invalid => _l10n.importErrorInvalid,
        BackupError.missingPhoto => _l10n.importErrorMissingPhoto,
      });
      return;
    }

    final mode = await _chooseMode(contents.recipes.length);
    if (mode == null || !context.mounted) return;
    if (mode == ImportMode.replace && !await _confirmReplace()) return;

    try {
      final result = await service.import(contents, mode);
      if (context.mounted) {
        _snack(
          _l10n.importDone(result.added, result.updated, result.unchanged),
        );
      }
    } on Object catch (error) {
      if (context.mounted) _snack(_l10n.importFailed('$error'));
    }
  }

  Future<ImportMode?> _chooseMode(int count) {
    return showDialog<ImportMode>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        final theme = Theme.of(context);
        return AlertDialog(
          title: Text(l10n.importTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.importSummary(count)),
                const SizedBox(height: 16),
                Text(l10n.importMerge, style: theme.textTheme.titleSmall),
                Text(l10n.importMergeHelp),
                const SizedBox(height: 12),
                Text(l10n.importReplace, style: theme.textTheme.titleSmall),
                Text(l10n.importReplaceHelp),
                const SizedBox(height: 16),
                Text(l10n.importSafetyNote, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, ImportMode.replace),
              child: Text(l10n.importReplace),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, ImportMode.merge),
              child: Text(l10n.importMerge),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _confirmReplace() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          content: Text(l10n.importReplaceConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.continueLabel),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }
}
