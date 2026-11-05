package io.github.aktawind.recettes

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.os.CancellationSignal
import android.os.ParcelFileDescriptor
import android.print.PageRange
import android.print.PrintAttributes
import android.print.PrintDocumentAdapter
import android.print.PrintDocumentInfo
import android.print.PrintManager
import java.io.File
import java.io.FileOutputStream

/**
 * Sorties de l'app vers les autres : partager un texte (messagerie, mail) et
 * imprimer un PDF — le gestionnaire d'impression d'Android propose aussi
 * « Enregistrer au format PDF ».
 */
object ExportActions {
    fun shareText(activity: Activity, text: String, subject: String) {
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, text)
            if (subject.isNotEmpty()) putExtra(Intent.EXTRA_SUBJECT, subject)
        }
        activity.startActivity(Intent.createChooser(send, subject.ifEmpty { null }))
    }

    fun printPdf(activity: Activity, path: String, name: String) {
        val manager = activity.getSystemService(Activity.PRINT_SERVICE) as PrintManager
        val attributes = PrintAttributes.Builder()
            .setMediaSize(PrintAttributes.MediaSize.ISO_A4)
            .build()
        manager.print(name, PdfAdapter(File(path), name), attributes)
    }

    /** Remet le PDF déjà prêt (une page A4) au gestionnaire d'impression. */
    private class PdfAdapter(private val file: File, private val name: String) :
        PrintDocumentAdapter() {
        override fun onLayout(
            oldAttributes: PrintAttributes?,
            newAttributes: PrintAttributes,
            cancellationSignal: CancellationSignal?,
            callback: LayoutResultCallback,
            extras: Bundle?,
        ) {
            if (cancellationSignal?.isCanceled == true) {
                callback.onLayoutCancelled()
                return
            }
            val info = PrintDocumentInfo.Builder("$name.pdf")
                .setContentType(PrintDocumentInfo.CONTENT_TYPE_DOCUMENT)
                .setPageCount(1)
                .build()
            callback.onLayoutFinished(info, oldAttributes != newAttributes)
        }

        override fun onWrite(
            pages: Array<out PageRange>,
            destination: ParcelFileDescriptor,
            cancellationSignal: CancellationSignal?,
            callback: WriteResultCallback,
        ) {
            try {
                file.inputStream().use { input ->
                    FileOutputStream(destination.fileDescriptor).use { output ->
                        input.copyTo(output)
                    }
                }
                callback.onWriteFinished(arrayOf(PageRange.ALL_PAGES))
            } catch (e: Exception) {
                callback.onWriteFailed(e.message)
            }
        }
    }
}
