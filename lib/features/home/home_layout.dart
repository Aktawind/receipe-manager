import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/theme_mode_controller.dart';
import '../../domain/home_picks.dart';

/// L'ordre des rubriques de l'accueil et celles qui sont affichées (propre à
/// l'appareil, comme l'affichage de la liste).
final homeLayoutProvider = NotifierProvider<HomeLayoutController, HomeLayout>(
  HomeLayoutController.new,
);

class HomeLayoutController extends Notifier<HomeLayout> {
  static const _key = 'home_sections';

  @override
  HomeLayout build() => HomePicks.parseLayout(
    ref.watch(sharedPreferencesProvider).getStringList(_key),
  );

  Future<void> set(HomeLayout layout) async {
    state = layout;
    await ref
        .read(sharedPreferencesProvider)
        .setStringList(_key, HomePicks.encodeLayout(layout));
  }

  Future<void> toggle(HomeSection section, bool shown) => set([
    for (final e in state)
      e.section == section ? (section: section, shown: shown) : e,
  ]);

  Future<void> move(int from, int to) {
    final next = [...state];
    next.insert(to, next.removeAt(from));
    return set(next);
  }

  Future<void> reset() => set(HomePicks.defaultLayout());
}
