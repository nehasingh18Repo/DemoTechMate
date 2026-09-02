package com.infinite.techmate.techmate_app

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Posts a HIGH-importance heads-up banner (title + body + sound) so
 * background / inactive pushes are visible immediately on the home screen.
 */
class NotificationHelperPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private var appContext: Context? = null
    private var mediaPlayer: MediaPlayer? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        releasePlayer()
        appContext = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "cancelAll" -> {
                notificationManager()?.cancelAll()
                result.success(null)
            }
            "cancelSilentRelay" -> {
                cancelSilentAndLegacy()
                result.success(null)
            }
            "showHeadsUp" -> {
                val title = call.argument<String>("title") ?: "Job Notification"
                val body = call.argument<String>("body") ?: "You have a new job update."
                val channelId = call.argument<String>("channelId")
                    ?: TechMateApplication.CHANNEL_PENDING
                val soundName = call.argument<String>("soundName") ?: "pending_sound"
                val notificationId = call.argument<Int>("notificationId")
                    ?: (System.currentTimeMillis() % Int.MAX_VALUE).toInt().coerceAtLeast(1)
                val ok = showHeadsUp(title, body, channelId, soundName, notificationId)
                if (ok) {
                    result.success(notificationId)
                } else {
                    result.error("show_failed", "Unable to post heads-up banner", null)
                }
            }
            "playRawSound" -> {
                val name = call.argument<String>("name")
                val volume = (call.argument<Double>("volume") ?: 1.0).toFloat().coerceIn(0f, 1f)
                if (name.isNullOrBlank()) {
                    result.error("bad_args", "Missing sound name", null)
                    return
                }
                if (playRawSound(name, volume)) {
                    result.success(null)
                } else {
                    result.error("play_failed", "Unable to play $name", null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun notificationManager(): NotificationManager? {
        val context = appContext ?: return null
        return context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
    }

    private fun cancelSilentAndLegacy() {
        val manager = notificationManager() ?: return
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        for (statusBar in manager.activeNotifications) {
            when (statusBar.notification.channelId) {
                TechMateApplication.CHANNEL_ID_SILENT,
                TechMateApplication.CHANNEL_ID_LEGACY,
                "techx_jobs",
                -> manager.cancel(statusBar.tag, statusBar.id)
            }
        }
    }

    private fun showHeadsUp(
        title: String,
        body: String,
        channelId: String,
        soundName: String,
        notificationId: Int,
    ): Boolean {
        val context = appContext ?: return false
        return try {
            cancelSilentAndLegacy()

            val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
                ?: Intent(context, MainActivity::class.java)
            launch.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            val contentIntent = PendingIntent.getActivity(
                context,
                notificationId,
                launch,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

            val soundUri =
                Uri.parse("android.resource://${context.packageName}/raw/$soundName")
            val iconId = context.resources.getIdentifier(
                "ic_stat_notify",
                "drawable",
                context.packageName,
            )

            val notification = NotificationCompat.Builder(context, channelId)
                .setSmallIcon(if (iconId != 0) iconId else android.R.drawable.ic_dialog_info)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(
                    NotificationCompat.BigTextStyle()
                        .bigText(body)
                        .setBigContentTitle(title),
                )
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_MESSAGE)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setAutoCancel(true)
                .setOnlyAlertOnce(false)
                // Sound on the banner itself so heads-up + beep appear together.
                .setSound(soundUri)
                .setVibrate(longArrayOf(0, 400, 200, 400))
                .setContentIntent(contentIntent)
                .setTicker(title)
                .setWhen(System.currentTimeMillis())
                .setShowWhen(true)
                .build()

            NotificationManagerCompat.from(context).notify(notificationId, notification)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun playRawSound(resourceName: String, volume: Float = 1.0f): Boolean {
        val context = appContext ?: return false
        val resId = context.resources.getIdentifier(
            resourceName,
            "raw",
            context.packageName,
        )
        if (resId == 0) return false
        return try {
            releasePlayer()
            val player = MediaPlayer.create(context, resId) ?: return false
            player.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            player.setVolume(volume, volume)
            player.setOnCompletionListener { releasePlayer() }
            mediaPlayer = player
            player.start()
            true
        } catch (_: Exception) {
            releasePlayer()
            false
        }
    }

    private fun releasePlayer() {
        try {
            mediaPlayer?.setOnCompletionListener(null)
            mediaPlayer?.release()
        } catch (_: Exception) {
        } finally {
            mediaPlayer = null
        }
    }

    companion object {
        const val CHANNEL_NAME = "techmate/notifications"
    }
}
