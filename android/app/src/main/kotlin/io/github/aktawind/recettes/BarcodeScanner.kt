package io.github.aktawind.recettes

import android.app.Activity
import com.google.android.gms.common.moduleinstall.ModuleInstall
import com.google.android.gms.common.moduleinstall.ModuleInstallRequest
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.codescanner.GmsBarcodeScanner
import com.google.mlkit.vision.codescanner.GmsBarcodeScannerOptions
import com.google.mlkit.vision.codescanner.GmsBarcodeScanning
import io.flutter.plugin.common.MethodChannel

/**
 * Lecteur de code-barres de Google Play (le code ISBN au dos d'un livre).
 *
 * Comme le scanner de pages, c'est un module des services Google Play,
 * téléchargé à la première utilisation. Renvoie le code lu, `null` si on
 * annule, ou une erreur avec son message.
 */
class BarcodeScanner(private val activity: Activity) {
    fun scan(result: MethodChannel.Result) {
        try {
            val options = GmsBarcodeScannerOptions.Builder()
                .setBarcodeFormats(
                    Barcode.FORMAT_EAN_13,
                    Barcode.FORMAT_EAN_8,
                    Barcode.FORMAT_UPC_A,
                )
                .enableAutoZoom()
                .build()
            val scanner = GmsBarcodeScanning.getClient(activity, options)
            ModuleInstall.getClient(activity)
                .areModulesAvailable(scanner)
                .addOnSuccessListener { response ->
                    if (response.areModulesAvailable()) {
                        launch(scanner, result)
                    } else {
                        install(scanner, result)
                    }
                }
                .addOnFailureListener { e -> result.error("module", e.message ?: "$e", null) }
        } catch (e: Exception) {
            result.error("crash", "${e.javaClass.simpleName}: ${e.message}", null)
        }
    }

    private fun install(scanner: GmsBarcodeScanner, result: MethodChannel.Result) {
        val request = ModuleInstallRequest.newBuilder().addApi(scanner).build()
        ModuleInstall.getClient(activity)
            .installModules(request)
            .addOnSuccessListener { launch(scanner, result) }
            .addOnFailureListener { e -> result.error("install", e.message ?: "$e", null) }
    }

    private fun launch(scanner: GmsBarcodeScanner, result: MethodChannel.Result) {
        scanner.startScan()
            .addOnSuccessListener { barcode -> result.success(barcode.rawValue) }
            .addOnCanceledListener { result.success(null) }
            .addOnFailureListener { e -> result.error("scan", e.message ?: "$e", null) }
    }
}
