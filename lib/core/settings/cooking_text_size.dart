import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme_mode_controller.dart';

/// La taille du texte du mode cuisine (Réglages → Apparence).
enum CookingTextSize {
  small(17),
  medium(20),
  large(23),
  extraLarge(27);

  const CookingTextSize(this.fontSize);

  final double fontSize;
}

final cookingTextSizeProvider =
    NotifierProvider<CookingTextSizeController, CookingTextSize>(
      CookingTextSizeController.new,
    );

class CookingTextSizeController extends Notifier<CookingTextSize> {
  static const _key = 'cooking_text_size';

  @override
  CookingTextSize build() {
    final stored = ref.watch(sharedPreferencesProvider).getString(_key);
    return CookingTextSize.values.asNameMap()[stored] ?? CookingTextSize.medium;
  }

  Future<void> set(CookingTextSize size) async {
    state = size;
    await ref.read(sharedPreferencesProvider).setString(_key, size.name);
  }
}
