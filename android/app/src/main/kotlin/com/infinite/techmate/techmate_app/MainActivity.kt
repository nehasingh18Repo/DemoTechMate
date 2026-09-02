package com.infinite.techmate.techmate_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import android.provider.Settings
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
     private val CHANNEL = "device_info"
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ensureVisibleFcmChannel()
    }

   override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "getAndroidId" -> {
                    val androidId = Settings.Secure.getString(
                        contentResolver,
                        Settings.Secure.ANDROID_ID
                    )

                    result.success(androidId)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    /** Keep FCM default channel HIGH so system banner can show title/body. */
    private fun ensureVisibleFcmChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        manager.deleteNotificationChannel(TechMateApplication.CHANNEL_ID_LEGACY)
        manager.deleteNotificationChannel(TechMateApplication.CHANNEL_ID_SILENT)
        manager.deleteNotificationChannel(TechMateApplication.CHANNEL_ID)

        val audio = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val sound = Uri.parse(
            "android.resource://$packageName/raw/pending_sound",
        )
        manager.createNotificationChannel(
            NotificationChannel(
                TechMateApplication.CHANNEL_ID,
                "Job Alerts",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Job push notification banners"
                enableVibration(true)
                enableLights(true)
                setShowBadge(true)
                setSound(sound, audio)
            },
        )
    }
}
