import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:brightspeed_fiber_app/core/notifications/app_lifecycle_tracker.dart';
import 'package:brightspeed_fiber_app/core/notifications/local_notification_service.dart';
import 'package:brightspeed_fiber_app/core/notifications/notification_coordinator.dart';
import 'package:brightspeed_fiber_app/core/notifications/notification_inbox_service.dart';
import 'package:brightspeed_fiber_app/core/notifications/notification_payload.dart';
import 'package:brightspeed_fiber_app/data/datasources/fcm_remote_datasource.dart';

/// Top-level background isolate handler (app in background / killed).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final payload = NotificationPayload.fromRemoteMessage(message);
  if (kDebugMode) {
    debugPrint('========== BACKGROUND FCM ==========');
    debugPrint('Message ID : ${message.messageId}');
    debugPrint('Data       : ${message.data}');
    debugPrint('Title      : ${message.notification?.title}');
    debugPrint('Body       : ${message.notification?.body}');
    debugPrint('STATUS     : ${payload.status}');
    debugPrint('TYPE       : ${payload.type}');
    debugPrint('PRIORITY   : ${payload.priority.storageValue}');
    debugPrint('SOUND KIND : ${payload.soundKind}');
  }

  try {
    final inbox = await NotificationInboxService.forBackgroundIsolate();
    await inbox.processIncoming(payload);
  } catch (error, stack) {
    if (kDebugMode) {
      debugPrint('Background inbox persist failed: $error\n$stack');
    }
  }

  // Same heads-up as inactive: banner + beep on home screen.
  try {
    await LocalNotificationService.showHeadsUpAlert(payload);
  } catch (error, stack) {
    if (kDebugMode) {
      debugPrint('Background local notification failed: $error\n$stack');
    }
    try {
      await LocalNotificationService.playStatusBeep(payload);
    } catch (_) {}
  }
}

class FcmService {
  FcmService({
    required FcmRemoteDataSource remoteDataSource,
    required NotificationInboxService inboxService,
  })  : _remoteDataSource = remoteDataSource,
        _inbox = inboxService;

  final FcmRemoteDataSource _remoteDataSource;
  final NotificationInboxService _inbox;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final AppLifecycleTracker _lifecycle = AppLifecycleTracker.instance;

  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedSub;
  StreamSubscription<String>? _onTokenRefreshSub;
  bool _initialized = false;
  int? _registeredUserId;
  String? _handledInitialMessageId;

  /// Payload deferred while lifecycle was inactive / paused / hidden.
  /// Kept for compatibility; high-priority background items use the inbox list.
  NotificationPayload? _deferredDialogPayload;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) {
      return;
    }

    if (Firebase.apps.isEmpty) {
      if (kDebugMode) {
        debugPrint('FCM initialize skipped: Firebase not ready.');
      }
      return;
    }

    await LocalNotificationService.initialize();
    LocalNotificationService.inboxService = _inbox;
    await _requestPermission();
    await _messaging.setAutoInitEnabled(true);

    // Prefer custom in-app dialog in active foreground (no OS banner duplicate).
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: true,
      sound: false,
    );

    _lifecycle.start(onResumed: _onAppResumed);

    // 1) Foreground / inactive — onMessage still fires while process is alive.
    _onMessageSub = FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // 2) Background — user tapped the system notification.
    _onMessageOpenedSub =
        FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationOpened);

    // 3) Terminated — app launched from a notification tap.
    await _handleInitialMessage();

    // Also check local-notification cold start (data-only path).
    final localLaunch = await LocalNotificationService.getLaunchPayload();
    if (localLaunch != null) {
      _enqueueOpenDeferred(localLaunch);
    }

    _onTokenRefreshSub = _messaging.onTokenRefresh.listen((token) async {
      final userId = _registeredUserId;
      if (userId == null || token.isEmpty) {
        return;
      }
      await _registerToken(userId: userId, token: token);
    });

    _initialized = true;
  }

  /// Called after login — POST /api/fcm/register with device token.
  Future<void> registerForUser(int userId) async {
    if (kIsWeb || Firebase.apps.isEmpty) {
      return;
    }
    await initialize();
    if (!_initialized) {
      return;
    }
    _registeredUserId = userId;

    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) {
      if (kDebugMode) {
        debugPrint('FCM token unavailable; skipping register.');
      }
      return;
    }

    if (kDebugMode) {
      debugPrint('FCM token: $token');
    }
    await _registerToken(userId: userId, token: token);
  }

  Future<void> _registerToken({
    required int userId,
    required String token,
  }) async {
    try {
      await _remoteDataSource.registerFcm(userId: userId, fcm: token);
      if (kDebugMode) {
        debugPrint('FCM registered for userId=$userId');
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('FCM register failed: $error');
      }
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    final payload = NotificationPayload.fromRemoteMessage(message);
    final inactive = _lifecycle.isInactiveOrBackground;

    if (kDebugMode) {
      debugPrint(
        'FCM foreground: ${message.notification?.title} '
        '${message.notification?.body} sound=${payload.soundKind} '
        'status=${payload.status} priority=${payload.priority.storageValue} '
        'lifecycle=${_lifecycle.state} inactive=$inactive',
      );
    }

    // Foreground active: beep + single title/body dialog (original UX).
    // Inactive / background process: keep unread + heads-up; ListView shows
    // when the user taps a notification (handleUserOpened).
    if (inactive) {
      unawaited(_showInactiveToast(payload));
      unawaited(_inbox.processIncoming(payload));
      return;
    }

    unawaited(_showForegroundToast(payload));
    unawaited(_inbox.persistForForeground(payload));
    NotificationCoordinator.enqueueDialog(payload);
  }

  Future<void> _showForegroundToast(NotificationPayload payload) async {
    try {
      // Same beep volume as background / inactive (shared playStatusBeep).
      await LocalNotificationService.show(payload, playBeep: true);
    } catch (error, stack) {
      if (kDebugMode) {
        debugPrint('Foreground local notification failed: $error\n$stack');
      }
      try {
        await LocalNotificationService.playStatusBeep(payload);
      } catch (_) {}
    }
  }

  Future<void> _showInactiveToast(NotificationPayload payload) async {
    try {
      // Same immediate heads-up banner + beep as background.
      await LocalNotificationService.showHeadsUpAlert(payload);
    } catch (error, stack) {
      if (kDebugMode) {
        debugPrint('Inactive local notification failed: $error\n$stack');
      }
      try {
        await LocalNotificationService.playStatusBeep(payload);
      } catch (_) {}
    }
  }

  void _onAppResumed() {
    final deferred = _deferredDialogPayload;
    _deferredDialogPayload = null;

    // If resume is from a tray tap, handleUserOpened owns the ListView —
    // do not run the manual-open 5-minute gate (it raced and blocked the alert).
    if (_inbox.openedFromNotificationTap) {
      if (kDebugMode) {
        debugPrint('FCM resume: skip manual-open (notification tap in progress)');
      }
    } else if (_registeredUserId != null) {
      // Manual open only: away ≥ 5 min + multiple unread high-priority.
      unawaited(_inbox.presentUnreadHighPriorityOnManualOpen());
    }

    if (deferred != null) {
      if (kDebugMode) {
        debugPrint(
          'FCM flush deferred single dialog after resume: '
          'status=${deferred.status} sound=${deferred.soundKind}',
        );
      }
      _enqueueDialogDeferred(deferred);
    }
  }

  void _onNotificationOpened(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('FCM opened (background): ${message.data}');
    }
    // Mark before resume handlers run so manual-open is suppressed.
    _inbox.openedFromNotificationTap = true;
    final payload = NotificationPayload.fromRemoteMessage(message);
    unawaited(_inbox.handleUserOpened(payload));
  }

  Future<void> _handleInitialMessage() async {
    final initial = await _messaging.getInitialMessage();
    if (initial == null) {
      return;
    }
    if (initial.messageId != null &&
        initial.messageId == _handledInitialMessageId) {
      return;
    }
    _handledInitialMessageId = initial.messageId;
    if (kDebugMode) {
      debugPrint('FCM opened (terminated): ${initial.data}');
    }
    _enqueueOpenDeferred(NotificationPayload.fromRemoteMessage(initial));
  }

  /// Inactive → resumed: same single-dialog UX as active foreground.
  void _enqueueDialogDeferred(NotificationPayload payload) {
    Future<void>.delayed(const Duration(milliseconds: 150), () {
      NotificationCoordinator.enqueueDialog(payload);
    });
  }

  /// Background / terminated tap → high-priority ListView path.
  void _enqueueOpenDeferred(NotificationPayload payload) {
    _inbox.openedFromNotificationTap = true;
    Future<void>.delayed(const Duration(milliseconds: 150), () {
      unawaited(_inbox.handleUserOpened(payload));
    });
  }

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    if (kDebugMode) {
      debugPrint('FCM permission: ${settings.authorizationStatus}');
    }

    if (!kIsWeb && Platform.isAndroid) {
      final status = await Permission.notification.request();
      if (kDebugMode) {
        debugPrint('Android notification permission: $status');
      }
    }
  }

  Future<void> dispose() async {
    _lifecycle.stop();
    _deferredDialogPayload = null;
    await _onMessageSub?.cancel();
    await _onMessageOpenedSub?.cancel();
    await _onTokenRefreshSub?.cancel();
  }
}
