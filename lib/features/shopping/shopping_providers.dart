import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_services.dart';
import '../../domain/shopping.dart';

/// Les listes de courses, la plus récemment modifiée d'abord.
final shoppingListsProvider = StreamProvider<List<ShoppingList>>(
  (ref) => ref.watch(shoppingRepositoryProvider).watchLists(),
);

final shoppingListProvider = StreamProvider.family<ShoppingList?, String>(
  (ref, id) => ref.watch(shoppingRepositoryProvider).watchList(id),
);

/// Les produits déjà achetés, du plus fréquent au moins fréquent
/// (suggestions à la saisie). Relu quand les listes changent.
final knownProductsProvider = FutureProvider<List<String>>((ref) {
  ref.watch(shoppingListsProvider);
  return ref.watch(shoppingRepositoryProvider).knownProducts();
});
