import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/logging/error_log.dart';
import '../../core/platform/export_actions.dart';
import '../../l10n/app_localizations.dart';

/// Réglages → À propos → Journal des erreurs : ce qui a échoué dans l'app,
/// le plus récent d'abord ; à envoyer en texte pour signaler un problème.
class ErrorLogPage extends ConsumerStatefulWidget {
  const ErrorLogPage({super.key});

  @override
  ConsumerState<ErrorLogPage> createState() => _ErrorLogPageState();
}

class _ErrorLogPageState extends ConsumerState<ErrorLogPage> {
  late var _entries = ErrorLog.current.read();

  Future<void> _clear() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.errorLogClearConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const ValueKey('error-log-clear-ok'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.errorLogClear),
          ),
        ],
      ),
    );
    if (ok != true) return;
    ErrorLog.current.clear();
    setState(() => _entries = ErrorLog.current.read());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.errorLogTitle),
        actions: [
          if (_entries.isNotEmpty) ...[
            IconButton(
              key: const ValueKey('error-log-share'),
              tooltip: l10n.errorLogShare,
              icon: const Icon(Icons.share_outlined),
              onPressed: () => ref
                  .read(exportActionsProvider)
                  .shareText(
                    ErrorLog.text(_entries, header: l10n.errorLogTitle),
                    subject: l10n.errorLogTitle,
                  ),
            ),
            IconButton(
              key: const ValueKey('error-log-clear'),
              tooltip: l10n.errorLogClear,
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: _clear,
            ),
          ],
        ],
      ),
      body: _entries.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.errorLogEmpty, textAlign: TextAlign.center),
              ),
            )
          : ListView.separated(
              // Marge du bas : barre de navigation Android.
              padding: EdgeInsets.only(
                bottom: 16 + MediaQuery.paddingOf(context).bottom,
              ),
              itemCount: _entries.length + 1,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      l10n.errorLogHint,
                      style: theme.textTheme.bodySmall,
                    ),
                  );
                }
                final e = _entries[i - 1];
                return ExpansionTile(
                  title: Text(
                    e.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${DateFormat.yMMMd(locale).add_Hm().format(e.at.toLocal())}'
                    ' · ${e.where}',
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: SelectableText(
                        [e.message, if (e.stack.isNotEmpty) e.stack].join('\n'),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
