import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Le lecteur de code-barres de Google Play (canal `recettes/barcode`,
/// `BarcodeScanner.kt`). Remplacé dans les tests.
abstract class BarcodeScanner {
  /// Le code lu, ou `null` si on annule.
  Future<String?> scan();
}

class AndroidBarcodeScanner implements BarcodeScanner {
  static const _channel = MethodChannel('recettes/barcode');

  @override
  Future<String?> scan() => _channel.invokeMethod<String>('scan');
}

final barcodeScannerProvider = Provider<BarcodeScanner>(
  (ref) => AndroidBarcodeScanner(),
);
