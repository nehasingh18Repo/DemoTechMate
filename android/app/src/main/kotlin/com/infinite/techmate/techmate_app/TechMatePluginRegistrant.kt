// Copyright (c) TechMate — durable registrant for app-local Android plugins.
// GeneratedPluginRegistrant may be rewritten by Flutter tooling; MainActivity and
// the FCM background FlutterEngine both call [registerWith] so cancelAll works.

package com.infinite.techmate.techmate_app

import io.flutter.embedding.engine.FlutterEngine

object TechMatePluginRegistrant {
    @JvmStatic
    fun registerWith(flutterEngine: FlutterEngine) {
        try {
            flutterEngine.plugins.add(NotificationHelperPlugin())
        } catch (_: Exception) {
            // Already registered on this engine.
        }
    }
}
