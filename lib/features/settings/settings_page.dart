import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/settings/kitchen_settings.dart';
import '../../core/settings/theme_mode_controller.dart';
import '../../domain/unit_conversion.dart';
import '../../l10n/app_localizations.dart';
import '../recipes/recipe_providers.dart';
import '../sync/sync_page.dart';
import '../sync/sync_providers.dart';
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
    final sync = ref.watch(syncControllerProvider);
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
          _SectionTitle(l10n.settingsKitchen),
          _ChoiceTile<UnitSystem>(
            key: const ValueKey('setting-units'),
            icon: Icons.scale_outlined,
            title: l10n.settingsUnits,
            value: ref.watch(unitSystemProvider),
            choices: {
              UnitSystem.recipe: l10n.unitsRecipe,
              UnitSystem.metric: l10n.unitsMetric,
              UnitSystem.imperial: l10n.unitsImperial,
            },
            onChanged: (v) => ref.read(unitSystemProvider.notifier).set(v),
          ),
          _ChoiceTile<TemperatureUnit>(
            key: const ValueKey('setting-temperature'),
            icon: Icons.thermostat_outlined,
            title: l10n.settingsTemperature,
            value: ref.watch(temperatureUnitProvider),
            choices: {
              TemperatureUnit.recipe: l10n.temperatureRecipe,
              TemperatureUnit.celsius: l10n.temperatureCelsius,
              TemperatureUnit.fahrenheit: l10n.temperatureFahrenheit,
            },
            onChanged: (v) => ref.read(temperatureUnitProvider.notifier).set(v),
          ),
          _ChoiceTile<int?>(
            key: const ValueKey('setting-servings'),
            icon: Icons.people_outline,
            title: l10n.settingsDefaultServings,
            subtitle: l10n.settingsDefaultServingsSubtitle,
            value: ref.watch(defaultServingsProvider),
            choices: {
              null: l10n.defaultServingsNone,
              for (final n in const [1, 2, 3, 4, 5, 6, 8, 10, 12])
                n: l10n.personsShort(n),
            },
            onChanged: (v) => ref.read(defaultServingsProvider.notifier).set(v),
          ),
          _SectionTitle(l10n.settingsData),
          ListTile(
            leading: const Icon(Icons.save_alt),
            title: Text(l10n.exportBackup),
            subtitle: Text(l10n.exportBackupSubtitle),
            onTap: () => BackupActions(context, ref).export(),
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
            leading: sync.enabled
                ? AccountAvatar(state: sync, radius: 16)
                : const Icon(Icons.cloud_sync_outlined),
            title: Text(l10n.syncTitle),
            subtitle: Text(
              sync.email == null
                  ? l10n.syncSubtitle
                  : l10n.syncSubtitleOn(sync.email!),
            ),
            onTap: () => context.push('/reglages/synchronisation'),
          ),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: Text(l10n.classificationTitle),
            subtitle: Text(l10n.classificationSubtitle),
            onTap: () => context.push('/reglages/classement'),
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

/// Un réglage à choix : le choix actuel sous le titre, la liste dans un
/// dialogue (les libellés longs ne tiennent pas dans un menu à droite).
class _ChoiceTile<T> extends StatelessWidget {
  const _ChoiceTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.choices,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final T value;
  final Map<T, String> choices;
  final ValueChanged<T> onChanged;

  Future<void> _pick(BuildContext context) async {
    final picked = await showDialog<(T,)>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(title),
        children: [
          RadioGroup<T>(
            groupValue: value,
            onChanged: (v) => Navigator.pop(context, (v as T,)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in choices.entries)
                  RadioListTile<T>(
                    key: ValueKey('choice-${entry.key}'),
                    value: entry.key,
                    title: Text(entry.value),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (picked != null) onChanged(picked.$1);
  }

  @override
  Widget build(BuildContext context) {
    final current = choices[value] ?? '';
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle == null ? current : '$current · $subtitle'),
      onTap: () => _pick(context),
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
