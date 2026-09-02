import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:brightspeed_fiber_app/core/constants/api_constants.dart';
import 'package:brightspeed_fiber_app/core/constants/storage_keys.dart';
import 'package:brightspeed_fiber_app/core/network/api_client.dart';
import 'package:brightspeed_fiber_app/core/network/auth_token_holder.dart';
import 'package:brightspeed_fiber_app/core/notifications/notification_coordinator.dart';
import 'package:brightspeed_fiber_app/core/notifications/notification_payload.dart';
import 'package:brightspeed_fiber_app/core/notifications/pending_alert_gate.dart';
import 'package:brightspeed_fiber_app/core/utils/job_status_mapper.dart';
import 'package:brightspeed_fiber_app/data/datasources/notification_local_datasource.dart';
import 'package:brightspeed_fiber_app/data/repositories/notification_repository_impl.dart';
import 'package:brightspeed_fiber_app/domain/entities/stored_notification.dart';
import 'package:brightspeed_fiber_app/domain/repositories/notification_repository.dart';

/// Persists inbox rows, runs medium/low background job updates, and opens the
/// high-priority ListView popup when the user taps a notification or opens
/// the app after receiving background pushes.
class NotificationInboxService {
  NotificationInboxService({
    NotificationRepository? repository,
    ApiClient? apiClient,
  })  : _repository = repository ??
            NotificationRepositoryImpl(NotificationLocalDataSource()),
        _apiClient = apiClient;

  final NotificationRepository _repository;
  final ApiClient? _apiClient;

  bool _presentInFlight = false;

  /// Set when the user opens the app by tapping a tray notification so a
  /// concurrent "manual open" resume check does not race / skip the ListView.
  bool openedFromNotificationTap = false;

  /// Works in the FCM background isolate (opens its own DB + token/API).
  static Future<NotificationInboxService> forBackgroundIsolate() async {
    return NotificationInboxService(
      repository: NotificationRepositoryImpl(NotificationLocalDataSource()),
    );
  }

  /// Save every push. Medium/low → silent job status API. High → stays unread
  /// until the user opens the high-priority popup.
  Future<StoredNotification> processIncoming(NotificationPayload payload) async {
    final stored = await _repository.saveIncoming(payload);
    if (kDebugMode) {
      debugPrint(
        'Inbox saved id=${stored.id} priority=${stored.priority.storageValue} '
        'jobId=${stored.jobId} status=${stored.status}',
      );
    }

    if (payload.priority.needsBackgroundTaskUpdate) {
      await _applyBackgroundTaskUpdate(stored);
    }
    return stored;
  }

  /// Foreground active: store locally and mark read so the original
  /// single title/body dialog UX is unchanged (no priority ListView here).
  Future<void> persistForForeground(NotificationPayload payload) async {
    final stored = await _repository.saveIncoming(payload);
    await _repository.markRead(stored.id);
    if (kDebugMode) {
      debugPrint(
        'Inbox foreground persist id=${stored.id} '
        'priority=${stored.priority.storageValue}',
      );
    }
  }

  /// User tapped a tray notification (background / terminated / local tap).
  /// Always shows ListView of unread high-priority items (no 5-min gate).
  Future<void> handleUserOpened(NotificationPayload? tapped) async {
    openedFromNotificationTap = true;

    if (tapped != null && tapped.priority.needsBackgroundTaskUpdate) {
      final stored = await _repository.saveIncoming(tapped);
      await _applyBackgroundTaskUpdate(stored);
    }

    // Ensure the tapped high-priority item exists as unread before listing.
    if (tapped != null && tapped.priority.needsPopup) {
      await _repository.saveIncoming(tapped);
    }

    // Flush any unread medium/low that arrived while the app was killed.
    final pendingTaskUpdates = await _repository.getUnreadMediumLowPriority();
    for (final item in pendingTaskUpdates) {
      await _applyBackgroundTaskUpdate(item);
    }

    await presentUnreadHighPriority(fallbackTapped: tapped, force: true);
  }

  /// Manual app open / resume — only shows the AlertDialog when:
  /// 1. The user has been away for at least 5 minutes, AND
  /// 2. There are **multiple** (≥ 2) unread high-priority notifications.
  ///
  /// Skipped entirely when the resume was caused by a notification tap.
  Future<void> presentUnreadHighPriorityOnManualOpen() async {
    if (openedFromNotificationTap) {
      if (kDebugMode) {
        debugPrint('Inbox manual-open skipped (opened from notification tap)');
      }
      openedFromNotificationTap = false;
      return;
    }
    if (_presentInFlight || NotificationCoordinator.isDialogVisible) {
      return;
    }

    // Evaluate gate before locking so a concurrent tray-tap can still present.
    final highUnreadPreview = await _repository.getUnreadHighPriority();
    final allowed = await PendingAlertGate.shouldShowManualOpenAlert(
      highUnreadPreview.length,
    );
    if (!allowed) {
      if (kDebugMode) {
        debugPrint(
          'Inbox manual-open alert skipped '
          '(count=${highUnreadPreview.length}, away gate failed or < 2 items)',
        );
      }
      // Still flush medium/low silently.
      final pendingTaskUpdates = await _repository.getUnreadMediumLowPriority();
      for (final item in pendingTaskUpdates) {
        await _applyBackgroundTaskUpdate(item);
      }
      return;
    }

    await presentUnreadHighPriority(force: false);
  }

  /// Show unread high-priority ListView.
  /// [force] is used for tray taps so a concurrent manual-open check cannot
  /// skip the dialog.
  Future<void> presentUnreadHighPriority({
    NotificationPayload? fallbackTapped,
    bool force = false,
  }) async {
    if (!force &&
        (_presentInFlight || NotificationCoordinator.isDialogVisible)) {
      if (kDebugMode) {
        debugPrint(
          'Inbox presentUnread skipped '
          '(inFlight=$_presentInFlight '
          'visible=${NotificationCoordinator.isDialogVisible})',
        );
      }
      return;
    }
    if (force && NotificationCoordinator.isDialogVisible) {
      // List already queued/showing — keep it.
      if (kDebugMode) {
        debugPrint('Inbox presentUnread force: dialog already visible');
      }
      return;
    }

    _presentInFlight = true;
    try {
      final pendingTaskUpdates = await _repository.getUnreadMediumLowPriority();
      for (final item in pendingTaskUpdates) {
        await _applyBackgroundTaskUpdate(item);
      }

      final highUnread = await _repository.getUnreadHighPriority();
      if (highUnread.isEmpty) {
        if (kDebugMode) {
          debugPrint('Inbox open: no unread high-priority notifications');
        }
        if (fallbackTapped != null && fallbackTapped.priority.needsPopup) {
          NotificationCoordinator.enqueueDialog(fallbackTapped);
        }
        return;
      }

      if (kDebugMode) {
        debugPrint(
          'Inbox presenting ${highUnread.length} unread high-priority item(s) '
          '(force=$force)',
        );
      }
      NotificationCoordinator.enqueueHighPriorityList(highUnread);
    } finally {
      _presentInFlight = false;
    }
  }

  Future<void> markHighPriorityListRead(List<StoredNotification> items) async {
    await _repository.markAllRead(items.map((e) => e.id));
  }

  Future<void> _applyBackgroundTaskUpdate(StoredNotification item) async {
    final jobId = item.jobIdAsInt;
    final status = item.status?.trim();
    if (jobId == null || status == null || status.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          'Inbox skip task update id=${item.id}: missing jobId/status',
        );
      }
      await _repository.markRead(item.id);
      return;
    }

    try {
      final client = await _resolveApiClient();
      final apiStatus = JobStatusMapper.toApi(JobStatusMapper.toDisplay(status));
      await client.patchJson(
        '${ApiConstants.jobById}/$jobId',
        body: {'status': apiStatus},
      );
      if (kDebugMode) {
        debugPrint(
          'Inbox background task update ok jobId=$jobId status=$apiStatus',
        );
      }
    } catch (error, stack) {
      if (kDebugMode) {
        debugPrint('Inbox background task update failed: $error\n$stack');
      }
    } finally {
      await _repository.markRead(item.id);
    }
  }

  Future<ApiClient> _resolveApiClient() async {
    final existing = _apiClient;
    if (existing != null) {
      return existing;
    }
    const secure = FlutterSecureStorage();
    final token = await secure.read(key: StorageKeys.authToken);
    final holder = AuthTokenHolder()..setToken(token);
    return ApiClient(tokenHolder: holder);
  }
}
