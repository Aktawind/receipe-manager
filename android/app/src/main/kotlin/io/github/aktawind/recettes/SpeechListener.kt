package io.github.aktawind.recettes

import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.plugin.common.MethodChannel

/**
 * Dictée continue des courses : chaque phrase comprise est envoyée à l'app
 * (« result »), puis l'écoute reprend, jusqu'à [stop]. Les silences et les
 * phrases non comprises relancent simplement l'écoute.
 *
 * Événements vers Dart (canal `recettes/speech`) : `listening`, `partial`
 * (texte en cours), `result` (une phrase), `stopped` (raison : `user`,
 * `unavailable`, `permission`, `error:<code>`).
 */
class SpeechListener(private val activity: MainActivity, private val channel: MethodChannel) {
    private var recognizer: SpeechRecognizer? = null
    private var active = false

    fun start() {
        if (!SpeechRecognizer.isRecognitionAvailable(activity)) {
            channel.invokeMethod("stopped", "unavailable")
            return
        }
        active = true
        val current = recognizer ?: SpeechRecognizer.createSpeechRecognizer(activity).also {
            it.setRecognitionListener(listener)
            recognizer = it
        }
        listen(current)
    }

    fun stop(reason: String = "user") {
        val wasListening = active || recognizer != null
        active = false
        recognizer?.cancel()
        recognizer?.destroy()
        recognizer = null
        // Un refus du micro arrive avant toute écoute : l'app doit le savoir.
        if (wasListening || reason != "user") channel.invokeMethod("stopped", reason)
    }

    private fun listen(target: SpeechRecognizer) {
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "fr-FR")
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
        }
        try {
            target.startListening(intent)
        } catch (e: RuntimeException) {
            stop("error:${e.javaClass.simpleName}")
        }
    }

    private fun again() {
        val current = recognizer
        if (active && current != null) listen(current)
    }

    private val listener = object : RecognitionListener {
        override fun onReadyForSpeech(params: Bundle?) {
            channel.invokeMethod("listening", null)
        }

        override fun onPartialResults(partialResults: Bundle?) {
            val text = partialResults
                ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                ?.firstOrNull()
            if (!text.isNullOrBlank()) channel.invokeMethod("partial", text)
        }

        override fun onResults(results: Bundle?) {
            val text = results
                ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                ?.firstOrNull()
            if (!text.isNullOrBlank()) channel.invokeMethod("result", text)
            again()
        }

        override fun onError(error: Int) {
            when (error) {
                // Silence, phrase non comprise, reconnaissance encore occupée :
                // on écoute à nouveau.
                SpeechRecognizer.ERROR_NO_MATCH,
                SpeechRecognizer.ERROR_SPEECH_TIMEOUT,
                SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> again()
                SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> stop("permission")
                else -> stop("error:$error")
            }
        }

        override fun onBeginningOfSpeech() {}
        override fun onRmsChanged(rmsdB: Float) {}
        override fun onBufferReceived(buffer: ByteArray?) {}
        override fun onEndOfSpeech() {}
        override fun onEvent(eventType: Int, params: Bundle?) {}
    }
}
