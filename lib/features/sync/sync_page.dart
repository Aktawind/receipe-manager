import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'sync_providers.dart';

/// Réglages → Synchronisation Google Drive : explication et consentement avant
/// la connexion, puis état de la synchro, bouton « Synchroniser maintenant » et
/// déconnexion.
class SyncPage extends ConsumerWidget {
  const SyncPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(syncControllerProvider);
    final controller = ref.read(syncControllerProvider.notifier);
    final folder = ref.watch(syncFolderNameProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.syncTitle)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          if (!state.enabled) ...[
            Text(l10n.syncIntroTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(l10n.syncIntroBody(folder)),
            const SizedBox(height: 12),
            Text(l10n.syncPrivacy),
            const SizedBox(height: 12),
            Text(l10n.syncAutoNote),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const ValueKey('sync-connect'),
              onPressed: controller.connect,
              icon: const Icon(Icons.login),
              label: Text(l10n.syncConnect),
            ),
            if (state.error != null) ...[
              const SizedBox(height: 12),
              _Error(l10n.syncErrorDetail(state.error!)),
            ],
          ] else ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.account_circle_outlined),
              title: Text(l10n.syncConnectedAs(state.email ?? '')),
              subtitle: Text(_status(context, l10n, state)),
              trailing: state.phase == SyncPhase.syncing
                  ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            ),
            if (state.lastConflicts > 0) ...[
              const SizedBox(height: 8),
              Text(l10n.syncConflicts(state.lastConflicts)),
            ],
            if (state.error != null) ...[
              const SizedBox(height: 8),
              _Error(l10n.syncErrorDetail(state.error!)),
            ],
            const SizedBox(height: 16),
            if (state.phase == SyncPhase.signInRequired)
              FilledButton.icon(
                onPressed: controller.connect,
                icon: const Icon(Icons.login),
                label: Text(l10n.syncSignInAgain),
              )
            else
              FilledButton.icon(
                key: const ValueKey('sync-now'),
                onPressed: state.phase == SyncPhase.syncing
                    ? null
                    : controller.syncNow,
                icon: const Icon(Icons.sync),
                label: Text(l10n.syncNow),
              ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const ValueKey('sync-disconnect'),
              onPressed: () => _confirmDisconnect(context, controller),
              child: Text(l10n.syncDisconnect),
            ),
            const SizedBox(height: 16),
            Text(l10n.syncAutoNote, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }

  String _status(BuildContext context, AppLocalizations l10n, SyncState state) {
    switch (state.phase) {
      case SyncPhase.syncing:
        return l10n.syncStatusSyncing;
      case SyncPhase.error:
        return l10n.syncStatusError;
      case SyncPhase.signInRequired:
        return l10n.syncStatusSignIn;
      case SyncPhase.off:
      case SyncPhase.idle:
        final last = state.lastSync;
        if (last == null) return l10n.syncNever;
        final material = MaterialLocalizations.of(context);
        final date = material.formatMediumDate(last);
        final time = material.formatTimeOfDay(TimeOfDay.fromDateTime(last));
        return '${l10n.syncStatusIdle} · ${l10n.syncLastSync('$date $time')}';
    }
  }

  Future<void> _confirmDisconnect(
    BuildContext context,
    SyncController controller,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.syncDisconnectTitle),
        content: Text(l10n.syncDisconnectBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.syncDisconnect),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.disconnect();
  }
}

class _Error extends StatelessWidget {
  const _Error(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: scheme.error),
    );
  }
}
