import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_services.dart';
import '../../domain/book.dart';

/// Les livres de cuisine, par titre.
final booksProvider = StreamProvider<List<Book>>(
  (ref) => ref.watch(recipeRepositoryProvider).watchBooks(),
);

/// Un livre, d'après son identifiant ; `null` s'il n'existe plus.
final bookProvider = Provider.family<Book?, String>(
  (ref, id) => [
    for (final b in ref.watch(booksProvider).value ?? const <Book>[])
      if (b.id == id) b,
  ].firstOrNull,
);
