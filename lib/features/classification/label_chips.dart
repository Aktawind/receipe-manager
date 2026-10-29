import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/label.dart';
import 'label_style.dart';
import 'labels_providers.dart';

/// Le classement d'une recette sous forme de pastilles : catégories (avec leur
/// parent : « Plats › Viandes »), saisons, étiquettes, collections…
class RecipeLabelChips extends ConsumerWidget {
  const RecipeLabelChips({super.key, required this.labelIds, this.onTap});

  final List<String> labelIds;

  /// Appelé quand on touche une pastille (filtrer par cet élément).
  final ValueChanged<Label>? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final all = ref.watch(labelsProvider).value ?? const <Label>[];
    final byId = {for (final l in all) l.id: l};
    final shown = [
      for (final l in all)
        if (labelIds.contains(l.id)) l,
    ];
    if (shown.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final label in shown)
          () {
            final color = labelColor(scheme, label.color);
            final onColor = label.color == 'butter' || label.color == 'caramel'
                ? scheme.onTertiary
                : (color == null ? scheme.onSurface : scheme.onPrimary);
            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap == null ? null : () => onTap!(label),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color ?? scheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (label.icon.isNotEmpty) ...[
                      Icon(
                        labelIconData(label.icon, label.kind.icon),
                        size: 16,
                        color: onColor,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      labelPath(label, byId),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: onColor,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }(),
      ],
    );
  }
}
