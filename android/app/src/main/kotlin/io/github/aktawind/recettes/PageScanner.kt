package io.github.aktawind.recettes

import android.app.Activity
import android.content.Intent
import android.content.IntentSender
import com.google.android.gms.common.moduleinstall.InstallStatusListener
import com.google.android.gms.common.moduleinstall.ModuleInstall
import com.google.android.gms.common.moduleinstall.ModuleInstallRequest
import com.google.android.gms.common.moduleinstall.ModuleInstallStatusUpdate
import com.google.mlkit.common.MlKitException
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
    /** Prévient l'app de l'avancement : « download:45 », « opening ». */
    var onStatus: ((String) -> Unit)? = null

    companion object {
        const val REQUEST_CODE = 0x5ca7
    }

    private var pending: MethodChannel.Result? = null

    fun scan(pageLimit: Int, result: MethodChannel.Result) {
        if (pending != null) {
            result.error("busy", "Un scan est déjà en cours", null)
            return
        }
        // Une exception imprévue (sans message) arrivait côté app comme un simple « error » :
        // on la rattrape pour en dire le type et l'endroit.
        try {
            start(pageLimit, result)
        } catch (e: Exception) {
            result.error("crash", describe(e), null)
        }
    }

    private fun start(pageLimit: Int, result: MethodChannel.Result) {
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
        onStatus?.invoke("download:0")
        val modules = ModuleInstall.getClient(activity)
        var done = false
        val listener = object : InstallStatusListener {
            override fun onInstallStatusUpdated(update: ModuleInstallStatusUpdate) {
                update.progressInfo?.let { progress ->
                    if (progress.totalBytesToDownload > 0) {
                        val percent =
                            (100 * progress.bytesDownloaded / progress.totalBytesToDownload).toInt()
                        onStatus?.invoke("download:$percent")
                    }
                }
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
                    result.error("download", describe(e), null)
                }
            }
    }

    private fun launch(scanner: GmsDocumentScanner, result: MethodChannel.Result) {
        onStatus?.invoke("opening")
        scanner.getStartScanIntent(activity)
            .addOnSuccessListener { sender ->
                pending = result
                try {
                    activity.startIntentSenderForResult(sender, REQUEST_CODE, null, 0, 0, 0)
                } catch (e: IntentSender.SendIntentException) {
                    pending = null
                    result.error("start", describe(e), null)
                }
            }
            .addOnFailureListener { e ->
                result.error("unavailable", describe(e), null)
            }
    }

    /** Le type de l'erreur, son code ML Kit et son message : de quoi savoir ce qui bloque. */
    private fun describe(e: Exception): String {
        val code = (e as? MlKitException)?.errorCode?.let { " code $it" } ?: ""
        val where = e.stackTrace.take(2).joinToString(" < ") { "${it.className}.${it.methodName}" }
        val cause = e.cause?.let { " (cause : ${it.javaClass.simpleName} ${it.message ?: ""})" } ?: ""
        return "${e.javaClass.name}$code : ${e.message ?: "sans message"}$cause — $where"
    }

    /** Résultat du scanner : les images des pages, ou `null` si on a annulé. */
    fun onActivityResult(resultCode: Int, data: Intent?) {
        val result = pending ?: return
        pending = null
        if (resultCode == Activity.RESULT_CANCELED) {
            result.success(null)
            return
        }
        if (resultCode != Activity.RESULT_OK) {
            result.error("result", "Le scanner a répondu $resultCode", null)
            return
        }
        val scanned = GmsDocumentScanningResult.fromActivityResultIntent(data)
        val pages = scanned?.pages?.mapNotNull { it.imageUri.path }
        result.success(if (pages.isNullOrEmpty()) null else pages)
    }
}
