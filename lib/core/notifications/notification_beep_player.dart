import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:brightspeed_fiber_app/core/notifications/notification_sound.dart';

/// Plays status-specific beep from Flutter assets.
///
/// Same volume is used for foreground, inactive, and background.
class NotificationBeepPlayer {
  NotificationBeepPlayer._();

  /// Shared loudness for every app state (0.0 – 1.0).
  static const double volume = 1.0;

  static final AudioPlayer _player = AudioPlayer();
  static bool _configured = false;

  static Future<void> _ensureConfigured() async {
    if (_configured) {
      return;
    }
    await AudioPlayer.global.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.notificationRingtone,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {
            AVAudioSessionOptions.mixWithOthers,
            AVAudioSessionOptions.duckOthers,
          },
        ),
      ),
    );
    await _player.setReleaseMode(ReleaseMode.stop);
    _configured = true;
  }

  static Future<void> play(NotificationSoundKind kind) async {
    final raw = NotificationSound.androidRawName(kind);
    if (raw == null) {
      return;
    }
    try {
      await _ensureConfigured();
      await _player.stop();
      await _player.setVolume(volume);
      await _player.play(AssetSource('sounds/$raw.mp3'), volume: volume);
      if (kDebugMode) {
        debugPrint(
          'NotificationBeepPlayer played volume=$volume: sounds/$raw.mp3',
        );
      }
    } catch (error, stack) {
      if (kDebugMode) {
        debugPrint('NotificationBeepPlayer failed: $error\n$stack');
      }
      rethrow;
    }
  }
}
