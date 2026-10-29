import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/settings/theme_mode_controller.dart';
import '../../l10n/app_localizations.dart';
import '../recipes/recipe_providers.dart';
import 'backup_actions.dart';
import 'recipe_keeper_actions.dart';

final _packageInfoProvider = FutureProvider<PackageInfo>(
  (ref) => PackageInfo.fromPlatform(),
);

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final info = ref.watch(_packageInfoProvider).value;
    final trashCount = ref.watch(trashProvider).value?.length ?? 0;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSettings)),
      body: ListView(
        children: [
          _SectionTitle(l10n.settingsAppearance),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(l10n.settingsTheme),
            trailing: DropdownButton<ThemeMode>(
              value: themeMode,
              underline: const SizedBox.shrink(),
              borderRadius: BorderRadius.circular(12),
              items: [
                DropdownMenuItem(
                  value: ThemeMode.system,
                  child: Text(l10n.themeSystem),
                ),
                DropdownMenuItem(
                  value: ThemeMode.light,
                  child: Text(l10n.themeLight),
                ),
                DropdownMenuItem(
                  value: ThemeMode.dark,
                  child: Text(l10n.themeDark),
                ),
              ],
              onChanged: (mode) {
                if (mode != null) {
                  ref.read(themeModeProvider.notifier).set(mode);
                }
              },
            ),
          ),
          _SectionTitle(l10n.settingsData),
          ListTile(
            leading: const Icon(Icons.save_alt),
            title: Text(l10n.exportBackup),
            subtitle: Text(l10n.exportBackupSubtitle),
            onTap: () => BackupActions(context, ref).export(),
          ),
          ListTile(
            leading: const Icon(Icons.share_outlined),
            title: Text(l10n.shareBackup),
            subtitle: Text(l10n.shareBackupSubtitle),
            onTap: () => BackupActions(context, ref).share(),
          ),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: Text(l10n.importBackup),
            subtitle: Text(l10n.importBackupSubtitle),
            onTap: () => BackupActions(context, ref).import(),
          ),
          ListTile(
            leading: const Icon(Icons.restaurant_menu),
            title: Text(l10n.importRecipeKeeper),
            subtitle: Text(l10n.importRecipeKeeperSubtitle),
            onTap: () => RecipeKeeperActions(context, ref).import(),
          ),
          ListTile(
            leading: const Icon(Icons.kitchen_outlined),
            title: Text(l10n.equipmentTitle),
            subtitle: Text(l10n.equipmentSubtitle),
            onTap: () => context.push('/reglages/materiel'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: Text(l10n.trash),
            subtitle: Text(l10n.trashSubtitle),
            trailing: trashCount == 0 ? null : Badge.count(count: trashCount),
            onTap: () => context.push('/reglages/corbeille'),
          ),
          _SectionTitle(l10n.settingsAbout),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.appTitle),
            subtitle: info == null
                ? null
                : Text(l10n.aboutVersion(info.version, info.buildNumber)),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
