import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/sync/drive_backup.dart';
import '../../data/sync/sync_remote.dart';
import '../../l10n/app_localizations.dart';
import 'sync_providers.dart';

String _date(BuildContext context, DateTime moment) {
  final material = MaterialLocalizations.of(context);
  final local = moment.toLocal();
  return '${material.formatMediumDate(local)} '
      '${material.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}

/// Réglages → Synchronisation : les sauvegardes dans Drive (fréquence,
/// « Sauvegarder maintenant », restauration).
class BackupSection extends ConsumerWidget {
  const BackupSection({super.key});

  String _frequencyName(AppLocalizations l10n, BackupFrequency frequency) =>
      switch (frequency) {
        BackupFrequency.off => l10n.driveBackupOff,
        BackupFrequency.daily => l10n.driveBackupDaily,
        BackupFrequency.weekly => l10n.driveBackupWeekly,
        BackupFrequency.monthly => l10n.driveBackupMonthly,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(syncControllerProvider);
    final controller = ref.read(syncControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        Text(l10n.driveBackupTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          l10n.driveBackupExplain(DriveBackupService.keep),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.driveBackupFrequency),
          trailing: DropdownButton<BackupFrequency>(
            key: const ValueKey('backup-frequency'),
            value: state.backupFrequency,
            underline: const SizedBox.shrink(),
            items: [
              for (final frequency in BackupFrequency.values)
                DropdownMenuItem(
                  value: frequency,
                  child: Text(_frequencyName(l10n, frequency)),
                ),
            ],
            onChanged: (value) {
              if (value != null) controller.setBackupFrequency(value);
            },
          ),
        ),
        Text(
          state.lastBackup == null
              ? l10n.driveBackupNever
              : l10n.driveBackupLast(_date(context, state.lastBackup!)),
        ),
        if (state.backupError != null) ...[
          const SizedBox(height: 4),
          Text(
            l10n.syncErrorDetail(state.backupError!),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              key: const ValueKey('backup-now'),
              onPressed: state.backupBusy ? null : () => _backup(context, ref),
              icon: state.backupBusy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(l10n.driveBackupNow),
            ),
            OutlinedButton.icon(
              key: const ValueKey('backup-restore'),
              onPressed: state.backupBusy ? null : () => _restore(context, ref),
              icon: const Icon(Icons.settings_backup_restore),
              label: Text(l10n.driveBackupRestore),
            ),
          ],
        ),
        const Divider(height: 32),
        TextButton.icon(
          key: const ValueKey('drive-delete'),
          onPressed: () => _deleteData(context, ref),
          style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
          icon: const Icon(Icons.delete_outline),
          label: Text(l10n.driveDeleteData),
        ),
      ],
    );
  }

  Future<void> _deleteData(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final folder = ref.read(syncFolderNameProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.driveDeleteTitle),
        content: Text(l10n.driveDeleteBody(folder)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.driveDeleteAction),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(syncControllerProvider.notifier).deleteDriveData();
      messenger.showSnackBar(
        SnackBar(persist: false, content: Text(l10n.driveDeleted)),
      );
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(
          persist: false,
          content: Text(l10n.driveBackupRestoreFailed('$error')),
        ),
      );
    }
  }

  Future<void> _backup(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final ok = await ref.read(syncControllerProvider.notifier).backupNow();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          persist: false,
          content: Text(ok ? l10n.driveBackupDone : l10n.driveBackupFailed),
        ),
      );
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(syncControllerProvider.notifier);

    final List<RemoteBackup> backups;
    try {
      backups = await controller.listBackups();
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(
          persist: false,
          content: Text(l10n.driveBackupRestoreFailed('$error')),
        ),
      );
      return;
    }
    if (!context.mounted) return;

    final picked = await showDialog<RemoteBackup>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.driveBackupPick),
        children: [
          if (backups.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(l10n.driveBackupNone),
            ),
          for (final backup in backups)
            ListTile(
              leading: const Icon(Icons.history),
              title: Text(_date(context, backup.createdAt)),
              onTap: () => Navigator.pop(context, backup),
            ),
        ],
      ),
    );
    if (picked == null || !context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.driveBackupConfirmTitle),
        content: Text(
          l10n.driveBackupConfirmBody(_date(context, picked.createdAt)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.driveBackupRestoreAction),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final result = await controller.restoreBackup(picked);
      final extra = result.missingPhotos == 0
          ? ''
          : ' ${l10n.driveBackupMissingPhotos(result.missingPhotos)}';
      messenger.showSnackBar(
        SnackBar(
          persist: false,
          content: Text('${l10n.driveBackupRestored(result.recipes)}$extra'),
        ),
      );
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(
          persist: false,
          content: Text(l10n.driveBackupRestoreFailed('$error')),
        ),
      );
    }
  }
}
