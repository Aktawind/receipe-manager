import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/logging/error_log.dart';
import '../../core/settings/theme_mode_controller.dart';
import '../../data/app_services.dart';
import '../../l10n/app_localizations.dart';
import '../sync/sync_providers.dart';
import 'backup_actions.dart';

/// Réglages → Confidentialité : ce que l'app garde et où, ce qui passe par
/// Internet ; exporter ou supprimer toutes ses données.
class PrivacyPage extends ConsumerWidget {
  const PrivacyPage({super.key});

  Future<void> _deleteAll(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final synced = ref.read(syncControllerProvider).enabled;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    // 1re confirmation : ce qui va partir, et le dossier Drive en option.
    final drive = await showDialog<bool>(
      context: context,
      builder: (context) => _DeleteDialog(synced: synced),
    );
    if (drive == null || !context.mounted) return;
    // 2e confirmation : on ne revient pas en arrière.
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteAllLastTitle),
        content: Text(l10n.deleteAllLastText),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const ValueKey('delete-all-confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.deleteAllConfirm),
          ),
        ],
      ),
    );
    if (sure != true) return;
    final services = ref.read(appServicesProvider);
    final sync = ref.read(syncControllerProvider.notifier);
    var driveFailed = false;
    if (synced) {
      try {
        if (drive) {
          await sync.deleteDriveData();
        } else {
          await sync.disconnect();
        }
      } on Object catch (error, stack) {
        driveFailed = true;
        ErrorLog.current.add('Suppression du dossier Drive', error, stack);
        await sync.disconnect();
      }
    }
    await services.wipeAll(ref.read(sharedPreferencesProvider));
    router.go('/accueil');
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            driveFailed ? l10n.deleteAllDoneDriveFailed : l10n.deleteAllDone,
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    Widget section(IconData icon, String title, String text) => ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title, style: theme.textTheme.titleSmall),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(text),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.privacyTitle)),
      body: ListView(
        // Marge du bas : barre de navigation Android.
        padding: EdgeInsets.only(
          top: 8,
          bottom: 24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          section(
            Icons.phone_android_outlined,
            l10n.privacyDeviceTitle,
            l10n.privacyDeviceText,
          ),
          section(
            Icons.cloud_outlined,
            l10n.privacyDriveTitle,
            l10n.privacyDriveText,
          ),
          section(
            Icons.public_outlined,
            l10n.privacyInternetTitle,
            l10n.privacyInternetText,
          ),
          section(
            Icons.mic_none_outlined,
            l10n.privacyPermissionsTitle,
            l10n.privacyPermissionsText,
          ),
          section(
            Icons.block_outlined,
            l10n.privacyNeverTitle,
            l10n.privacyNeverText,
          ),
          const Divider(height: 32),
          ListTile(
            key: const ValueKey('privacy-export'),
            leading: const Icon(Icons.download_outlined),
            title: Text(l10n.privacyExport),
            subtitle: Text(l10n.privacyExportText),
            onTap: () => BackupActions(context, ref).export(),
          ),
          ListTile(
            key: const ValueKey('privacy-delete-all'),
            leading: Icon(
              Icons.delete_forever_outlined,
              color: theme.colorScheme.error,
            ),
            title: Text(
              l10n.deleteAllTitle,
              style: TextStyle(color: theme.colorScheme.error),
            ),
            subtitle: Text(l10n.deleteAllSubtitle),
            onTap: () => _deleteAll(context, ref),
          ),
        ],
      ),
    );
  }
}

/// La première confirmation ; renvoie `true` s'il faut aussi supprimer le
/// dossier Drive, `false` sinon, `null` si on annule.
class _DeleteDialog extends StatefulWidget {
  const _DeleteDialog({required this.synced});

  final bool synced;

  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> {
  var _drive = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.deleteAllTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.deleteAllText),
          if (widget.synced)
            CheckboxListTile(
              key: const ValueKey('delete-all-drive'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _drive,
              title: Text(l10n.deleteAllDrive),
              subtitle: Text(l10n.deleteAllDriveHint),
              onChanged: (on) => setState(() => _drive = on ?? false),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const ValueKey('delete-all-next'),
          onPressed: () => Navigator.pop(context, widget.synced && _drive),
          child: Text(l10n.deleteAllNext),
        ),
      ],
    );
  }
}
