package io.github.aktawind.recettes

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

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
}
