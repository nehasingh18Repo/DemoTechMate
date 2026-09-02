import 'package:flutter/foundation.dart';
import 'package:brightspeed_fiber_app/core/notifications/notification_payload.dart';
import 'package:brightspeed_fiber_app/domain/entities/stored_notification.dart';

/// Coordinates notification UI (dialog) and post-confirm navigation.
///
/// High priority: [enqueueHighPriorityList] → ListView popup (title + message).
/// Medium / low: no popup (handled via background task API in inbox service).
class NotificationCoordinator {
  NotificationCoordinator._();

  /// Legacy single-payload dialog (kept for compatibility; prefer list).
  static final ValueNotifier<NotificationPayload?> pendingDialog =
      ValueNotifier<NotificationPayload?>(null);

  /// Unread high-priority inbox rows for the ListView popup.
  static final ValueNotifier<List<StoredNotification>?> pendingHighPriorityList =
      ValueNotifier<List<StoredNotification>?>(null);

  /// Bumped once when user taps OK — HomePage navigates + refreshes jobs.
  static final ValueNotifier<int> openJobsSignal = ValueNotifier<int>(0);

  static bool _dialogVisible = false;
  static String? _lastNavigationMessageId;

  static bool get isDialogVisible => _dialogVisible;

  /// Queue high-priority ListView popup (replaces single-item dialog).
  static void enqueueHighPriorityList(List<StoredNotification> items) {
    if (items.isEmpty) {
      return;
    }
    if (_dialogVisible && pendingHighPriorityList.value != null) {
      // Merge newly arrived high items into the pending list.
      final existing = pendingHighPriorityList.value ?? const [];
      final byId = <int, StoredNotification>{
        for (final item in existing) item.id: item,
        for (final item in items) item.id: item,
      };
      pendingHighPriorityList.value = byId.values.toList()
        ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
      return;
    }
    _dialogVisible = true;
    pendingDialog.value = null;
    pendingHighPriorityList.value = List<StoredNotification>.from(items);
  }

  /// Queue a notification dialog (deduped by messageId) — wraps as one-item list
  /// when possible via [enqueueHighPriorityList] callers.
  static void enqueueDialog(NotificationPayload payload) {
    if (_dialogVisible &&
        (pendingDialog.value != null || pendingHighPriorityList.value != null)) {
      if (kDebugMode) {
        debugPrint('Notification dialog skipped (already visible)');
      }
      return;
    }
    _dialogVisible = true;
    pendingHighPriorityList.value = null;
    pendingDialog.value = payload;
  }

  /// Cancel: close dialog, stay on current screen.
  static void dismissDialog() {
    _dialogVisible = false;
    pendingDialog.value = null;
    pendingHighPriorityList.value = null;
  }

  /// OK: close dialog, then navigate to Job Card once and refresh.
  static void confirmOpenJobs([NotificationPayload? payload]) {
    final id = payload?.messageId;
    dismissDialog();

    if (id != null && id == _lastNavigationMessageId) {
      if (kDebugMode) {
        debugPrint('Job navigation skipped (duplicate): $id');
      }
      return;
    }

    _lastNavigationMessageId = id;
    openJobsSignal.value = openJobsSignal.value + 1;
  }

  /// Backward-compatible alias used by older call sites.
  static void openJobs() {
    openJobsSignal.value = openJobsSignal.value + 1;
  }
}

/// Kept for existing imports; delegates to [NotificationCoordinator].
class NotificationNavigator {
  NotificationNavigator._();

  static ValueNotifier<int> get openJobsSignal =>
      NotificationCoordinator.openJobsSignal;

  static void openJobs() => NotificationCoordinator.openJobs();
}
