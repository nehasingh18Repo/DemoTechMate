package com.infinite.techmate.techmate_app

import android.app.Application
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build

/**
 * Notification channels for FCM + local alerts.
 *
 * FCM default channel is HIGH + sound so Android shows an immediate heads-up
 * banner (title/body) when a push arrives in background / inactive.
 * Status-specific beeps use pending / assigned / completed / wifi channels.
 */
class TechMateApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        ensureNotificationChannels()
    }

    private fun ensureNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = getSystemService(NotificationManager::class.java) ?: return

        // Wipe every legacy / silent relay so heads-up settings apply fresh.
        for (id in ALL_LEGACY_CHANNELS) {
            manager.deleteNotificationChannel(id)
        }

        val audioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        // FCM auto-display channel — MUST be HIGH so banner shows immediately.
        createChannel(
            manager = manager,
            id = CHANNEL_ID,
            name = "Job Alerts",
            soundUri = rawSoundUri("pending_sound"),
            audioAttributes = audioAttributes,
            importance = NotificationManager.IMPORTANCE_HIGH,
        )
        createChannel(
            manager = manager,
            id = CHANNEL_PENDING,
            name = "Pending Job Alerts",
            soundUri = rawSoundUri("pending_sound"),
            audioAttributes = audioAttributes,
        )
        createChannel(
            manager = manager,
            id = CHANNEL_ASSIGNED,
            name = "Assigned Job Alerts",
            soundUri = rawSoundUri("assigned_sound"),
            audioAttributes = audioAttributes,
        )
        createChannel(
            manager = manager,
            id = CHANNEL_COMPLETED,
            name = "Completed Job Alerts",
            soundUri = rawSoundUri("completed_sound"),
            audioAttributes = audioAttributes,
        )
        createChannel(
            manager = manager,
            id = CHANNEL_WIFI,
            name = "WiFi Installation Alerts",
            soundUri = rawSoundUri("wifi_installation_sound"),
            audioAttributes = audioAttributes,
        )
    }

    private fun createChannel(
        manager: NotificationManager,
        id: String,
        name: String,
        soundUri: Uri?,
        audioAttributes: AudioAttributes,
        importance: Int = NotificationManager.IMPORTANCE_HIGH,
    ) {
        val channel = NotificationChannel(id, name, importance).apply {
            description = "Job push notifications"
            enableVibration(true)
            enableLights(true)
            setShowBadge(true)
            setSound(soundUri, if (soundUri == null) null else audioAttributes)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setBypassDnd(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun rawSoundUri(resourceName: String): Uri {
        return Uri.parse("android.resource://$packageName/raw/$resourceName")
    }

    companion object {
        const val CHANNEL_ID_LEGACY = "techx_jobs_heads_up"
        const val CHANNEL_ID_SILENT = "techx_jobs_fcm_relay"

        /** FCM default — high importance visible heads-up. */
        const val CHANNEL_ID = "techx_jobs_fcm_visible_v4"

        const val CHANNEL_PENDING = "techx_jobs_pending_v4"
        const val CHANNEL_ASSIGNED = "techx_jobs_assigned_v4"
        const val CHANNEL_COMPLETED = "techx_jobs_completed_v4"
        const val CHANNEL_WIFI = "techx_jobs_wifi_installation_v4"

        val ALL_LEGACY_CHANNELS = listOf(
            "techx_jobs",
            CHANNEL_ID_LEGACY,
            CHANNEL_ID_SILENT,
            CHANNEL_ID,
            "techx_jobs_pending",
            "techx_jobs_assigned",
            "techx_jobs_completed",
            "techx_jobs_wifi_installation",
            "techx_jobs_pending_v2",
            "techx_jobs_assigned_v2",
            "techx_jobs_completed_v2",
            "techx_jobs_wifi_installation_v2",
            "techx_jobs_pending_v3",
            "techx_jobs_assigned_v3",
            "techx_jobs_completed_v3",
            "techx_jobs_wifi_installation_v3",
            CHANNEL_PENDING,
            CHANNEL_ASSIGNED,
            CHANNEL_COMPLETED,
            CHANNEL_WIFI,
        )
    }
}
