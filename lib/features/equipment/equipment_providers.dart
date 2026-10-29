import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_services.dart';
import '../../domain/equipment.dart';

/// La liste commune du matériel, triée par nom.
final equipmentProvider = StreamProvider<List<EquipmentItem>>(
  (ref) => ref.watch(equipmentRepositoryProvider).watchAll(),
);

/// Nombre de recettes qui utilisent chaque matériel.
final equipmentUsageProvider = StreamProvider<Map<String, int>>(
  (ref) => ref.watch(equipmentRepositoryProvider).watchUsage(),
);
