import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:brightspeed_fiber_app/core/constants/storage_keys.dart';

/// Decides when the unread high-priority AlertDialog may appear on a
/// **manual** app open (not a notification tray tap).
///
/// Rules:
/// - User must have been away (app in background) for at least [awayThreshold]
/// - There must be **multiple** (≥ 2) unread high-priority notifications
class PendingAlertGate {
  PendingAlertGate._();

  static const Duration awayThreshold = Duration(minutes: 5);
  static const int minHighPriorityCount = 2;

  /// Call when the app enters background / paused / hidden.
  static Future<void> markWentToBackground() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt(StorageKeys.lastAppBackgroundMs, now);
    if (kDebugMode) {
      debugPrint('PendingAlertGate: marked background at $now');
    }
  }

  /// True when the user has not had the app open for [awayThreshold].
  static Future<bool> hasBeenAwayLongEnough() async {
    final prefs = await SharedPreferences.getInstance();
    final leftAt = prefs.getInt(StorageKeys.lastAppBackgroundMs);
    if (leftAt == null) {
      if (kDebugMode) {
        debugPrint('PendingAlertGate: no background timestamp — skip alert');
      }
      return false;
    }
    final awayMs = DateTime.now().millisecondsSinceEpoch - leftAt;
    final enough = awayMs >= awayThreshold.inMilliseconds;
    if (kDebugMode) {
      debugPrint(
        'PendingAlertGate: away=${awayMs}ms '
        'threshold=${awayThreshold.inMilliseconds}ms enough=$enough',
      );
    }
    return enough;
  }

  /// Manual-open eligibility: away ≥ 5 minutes AND multiple unread highs.
  static Future<bool> shouldShowManualOpenAlert(int unreadHighCount) async {
    if (unreadHighCount < minHighPriorityCount) {
      if (kDebugMode) {
        debugPrint(
          'PendingAlertGate: skip — need ≥$minHighPriorityCount '
          'high-priority, got $unreadHighCount',
        );
      }
      return false;
    }
    return hasBeenAwayLongEnough();
  }
}
