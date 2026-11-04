package io.github.aktawind.recettes

import android.app.Activity
import android.content.Intent
import android.content.IntentSender
import com.google.android.gms.common.moduleinstall.InstallStatusListener
import com.google.android.gms.common.moduleinstall.ModuleInstall
import com.google.android.gms.common.moduleinstall.ModuleInstallRequest
import com.google.android.gms.common.moduleinstall.ModuleInstallStatusUpdate
import com.google.mlkit.vision.documentscanner.GmsDocumentScanner
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult
import io.flutter.plugin.common.MethodChannel

/**
 * Scanner de pages de Google Play (cadrage, redressement, plusieurs pages, galerie).
 *
 * Le scanner est un module des services Google Play, téléchargé à la première utilisation :
 * on vérifie qu'il est là, on le demande sinon, puis on ouvre le scanner. Les erreurs sont
 * renvoyées avec leur message, pour qu'on sache ce qui bloque.
 */
class PageScanner(private val activity: Activity) {
    companion object {
        const val REQUEST_CODE = 0x5ca7
    }

    private var pending: MethodChannel.Result? = null

    fun scan(pageLimit: Int, result: MethodChannel.Result) {
        if (pending != null) {
            result.error("busy", "Un scan est déjà en cours", null)
            return
        }
        val options = GmsDocumentScannerOptions.Builder()
            .setGalleryImportAllowed(true)
            .setPageLimit(pageLimit)
            .setResultFormats(GmsDocumentScannerOptions.RESULT_FORMAT_JPEG)
            .setScannerMode(GmsDocumentScannerOptions.SCANNER_MODE_FULL)
            .build()
        val scanner = GmsDocumentScanning.getClient(options)
        val modules = ModuleInstall.getClient(activity)
        modules.areModulesAvailable(scanner)
            .addOnSuccessListener { response ->
                if (response.areModulesAvailable()) {
                    launch(scanner, result)
                } else {
                    install(scanner, result)
                }
            }
            // Vérification impossible : on tente quand même d'ouvrir le scanner.
            .addOnFailureListener { launch(scanner, result) }
    }

    private fun install(scanner: GmsDocumentScanner, result: MethodChannel.Result) {
        val modules = ModuleInstall.getClient(activity)
        var done = false
        val listener = object : InstallStatusListener {
            override fun onInstallStatusUpdated(update: ModuleInstallStatusUpdate) {
                when (update.installState) {
                    ModuleInstallStatusUpdate.InstallState.STATE_COMPLETED -> {
                        modules.unregisterListener(this)
                        if (!done) {
                            done = true
                            launch(scanner, result)
                        }
                    }
                    ModuleInstallStatusUpdate.InstallState.STATE_FAILED,
                    ModuleInstallStatusUpdate.InstallState.STATE_CANCELED -> {
                        modules.unregisterListener(this)
                        if (!done) {
                            done = true
                            result.error(
                                "download",
                                "Téléchargement du scanner impossible (code ${update.errorCode})",
                                null,
                            )
                        }
                    }
                    else -> {}
                }
            }
        }
        val request = ModuleInstallRequest.newBuilder()
            .addApi(scanner)
            .setListener(listener)
            .build()
        modules.installModules(request)
            .addOnSuccessListener { response ->
                if (response.areModulesAlreadyInstalled() && !done) {
                    done = true
                    modules.unregisterListener(listener)
                    launch(scanner, result)
                }
            }
            .addOnFailureListener { e ->
                if (!done) {
                    done = true
                    result.error("download", e.message ?: e.javaClass.simpleName, null)
                }
            }
    }

    private fun launch(scanner: GmsDocumentScanner, result: MethodChannel.Result) {
        scanner.getStartScanIntent(activity)
            .addOnSuccessListener { sender ->
                pending = result
                try {
                    activity.startIntentSenderForResult(sender, REQUEST_CODE, null, 0, 0, 0)
                } catch (e: IntentSender.SendIntentException) {
                    pending = null
                    result.error("start", e.message ?: "SendIntentException", null)
                }
            }
            .addOnFailureListener { e ->
                result.error("unavailable", e.message ?: e.javaClass.simpleName, null)
            }
    }

    /** Résultat du scanner : les images des pages, ou `null` si on a annulé. */
    fun onActivityResult(resultCode: Int, data: Intent?) {
        val result = pending ?: return
        pending = null
        if (resultCode != Activity.RESULT_OK) {
            result.success(null)
            return
        }
        val scanned = GmsDocumentScanningResult.fromActivityResultIntent(data)
        val pages = scanned?.pages?.mapNotNull { it.imageUri.path }
        result.success(if (pages.isNullOrEmpty()) null else pages)
    }
}
