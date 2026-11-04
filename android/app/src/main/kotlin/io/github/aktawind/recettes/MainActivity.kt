package io.github.aktawind.recettes

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    /** Texte partagé depuis une autre app (adresse d'une recette), pas encore lu. */
    private var sharedText: String? = null
    private var shareChannel: MethodChannel? = null
    private val pageScanner = PageScanner(this)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // Partage Android (« Partager » → Recettes) : l'app lit le texte partagé
        // au démarrage, puis est prévenue des partages suivants.
        sharedText = sharedTextOf(intent)
        shareChannel = MethodChannel(messenger, "recettes/share").also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "takeShared" -> {
                        result.success(sharedText)
                        sharedText = null
                    }
                    else -> result.notImplemented()
                }
            }
        }

        // Mode cuisine : garder l'écran allumé tant qu'il est ouvert.
        MethodChannel(messenger, "recettes/screen").setMethodCallHandler { call, result ->
            when (call.method) {
                "keepOn" -> {
                    if (call.arguments == true) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // Scanner de pages de Google Play (PageScanner).
        MethodChannel(messenger, "recettes/scanner").setMethodCallHandler { call, result ->
            when (call.method) {
                "scan" -> pageScanner.scan(call.argument<Int>("pageLimit") ?: 5, result)
                else -> result.notImplemented()
            }
        }

        // Minuteurs : alarmes et notifications (TimerAlarms).
        MethodChannel(messenger, "recettes/timers").setMethodCallHandler { call, result ->
            when (call.method) {
                "schedule" -> {
                    TimerAlarms.schedule(
                        applicationContext,
                        call.argument<Int>("id")!!,
                        call.argument<Number>("at")!!.toLong(),
                        call.argument<String>("title") ?: "",
                        call.argument<String>("body") ?: "",
                        call.argument<String>("channelName") ?: "",
                    )
                    result.success(null)
                }
                "cancel" -> {
                    TimerAlarms.cancel(applicationContext, call.argument<Int>("id")!!)
                    result.success(null)
                }
                "requestPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                        checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                        PackageManager.PERMISSION_GRANTED
                    ) {
                        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 41)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == PageScanner.REQUEST_CODE) pageScanner.onActivityResult(resultCode, data)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val text = sharedTextOf(intent) ?: return
        val channel = shareChannel
        if (channel == null) {
            sharedText = text
        } else {
            channel.invokeMethod("shared", text)
        }
    }

    private fun sharedTextOf(intent: Intent?): String? {
        if (intent?.action != Intent.ACTION_SEND) return null
        return intent.getStringExtra(Intent.EXTRA_TEXT)?.takeIf { it.isNotBlank() }
    }
}
