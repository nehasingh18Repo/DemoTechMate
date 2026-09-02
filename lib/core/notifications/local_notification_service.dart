import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:brightspeed_fiber_app/core/notifications/notification_beep_player.dart';
import 'package:brightspeed_fiber_app/core/notifications/notification_coordinator.dart';
import 'package:brightspeed_fiber_app/core/notifications/notification_inbox_service.dart';
import 'package:brightspeed_fiber_app/core/notifications/notification_payload.dart';
import 'package:brightspeed_fiber_app/core/notifications/notification_sound.dart';

/// Local notifications helper (Android heads-up toast + tap handling).
class LocalNotificationService {
  LocalNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const MethodChannel _nativeChannel =
      MethodChannel('techmate/notifications');

  static bool _initialized = false;
  static int _notificationId = 1000;

  /// Set from DI so tray taps use the same inbox (high list / med-low API).
  static NotificationInboxService? inboxService;

  static Future<void> initialize() async {
    if (_initialized || kIsWeb) {
      return;
    }

    const androidInit = AndroidInitializationSettings('@drawable/ic_stat_notify');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final granted = await _plugin.initialize(
      settings: const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    if (kDebugMode) {
      debugPrint('LocalNotificationService initialize: $granted');
    }

    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.deleteNotificationChannel(channelId: 'techx_jobs');
      await android?.deleteNotificationChannel(
        channelId: NotificationSound.legacyDefaultChannelId,
      );
      for (final legacyId in NotificationSound.legacyStatusChannelIds) {
        await android?.deleteNotificationChannel(channelId: legacyId);
      }
      await android?.deleteNotificationChannel(
        channelId: NotificationSound.silentRelayChannelId,
      );
      await android?.createNotificationChannel(
        AndroidNotificationChannel(
          NotificationSound.defaultChannelId,
          'Job Alerts',
          description: 'Job push notification banners',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
          showBadge: true,
          sound: RawResourceAndroidNotificationSound(NotificationSound.pendingFile),
        ),
      );
      for (final kind in NotificationSoundKind.values) {
        if (kind == NotificationSoundKind.systemDefault) {
          continue;
        }
        await android?.createNotificationChannel(_channelFor(kind));
      }
      await android?.requestNotificationsPermission();
    }

    _initialized = true;
  }

  /// Cancels only silent FCM relay tray entries (keeps our status notification).
  static Future<void> cancelSilentRelayNotifications() async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }
    try {
      await _nativeChannel.invokeMethod<void>('cancelSilentRelay');
    } catch (error) {
      if (kDebugMode) {
        debugPrint('cancelSilentRelayNotifications failed: $error');
      }
    }
  }

  /// Cancels all tray notifications. Prefer [cancelSilentRelayNotifications].
  static Future<void> cancelSystemNotifications() async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }
    try {
      await _nativeChannel.invokeMethod<void>('cancelAll');
    } catch (error) {
      if (kDebugMode) {
        debugPrint('cancelSystemNotifications failed: $error');
      }
      try {
        await _plugin.cancelAll();
      } catch (_) {}
    }
  }

  /// Explicit status beep at the same volume for every app state.
  static Future<void> playStatusBeep(NotificationPayload payload) async {
    final kind = payload.soundKind;
    try {
      await NotificationBeepPlayer.play(kind);
      return;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Asset beep failed, trying native: $error');
      }
    }

    if (Platform.isAndroid) {
      final raw = NotificationSound.androidRawName(kind);
      if (raw != null) {
        try {
          await _nativeChannel.invokeMethod<void>('playRawSound', {
            'name': raw,
            'volume': NotificationBeepPlayer.volume,
          });
        } catch (error) {
          if (kDebugMode) {
            debugPrint('Native playRawSound failed: $error');
          }
        }
      }
    }
  }

  /// Background / inactive: native heads-up banner (title + body + sound)
  /// immediately, then status beep, then Flutter tray as backup.
  static Future<void> showHeadsUpAlert(NotificationPayload payload) async {
    await initialize();

    final kind = payload.soundKind;
    final title =
        payload.title.trim().isEmpty ? 'Job Notification' : payload.title.trim();
    final body = payload.body.trim().isEmpty
        ? 'You have a new job update.'
        : payload.body.trim();
    final channelId = NotificationSound.channelId(kind);
    final soundName =
        NotificationSound.androidRawName(kind) ?? NotificationSound.pendingFile;
    final id = _notificationIdFor(payload);

    if (kDebugMode) {
      debugPrint(
        'showHeadsUpAlert title=$title channel=$channelId sound=$soundName',
      );
    }

    // 1) Native Android banner FIRST (most reliable for home-screen heads-up).
    var nativeBannerShown = false;
    if (Platform.isAndroid) {
      try {
        await _nativeChannel.invokeMethod<int>('showHeadsUp', {
          'title': title,
          'body': body,
          'channelId': channelId,
          'soundName': soundName,
          'notificationId': id,
        });
        nativeBannerShown = true;
      } catch (error) {
        if (kDebugMode) {
          debugPrint('Native showHeadsUp failed: $error');
        }
      }
    }

    // 2) Status beep — always when native banner missing; also on Android as
    //    loudness boost so beep is heard with the banner.
    try {
      await playStatusBeep(payload);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('playStatusBeep failed: $error');
      }
    }

    // 3) Flutter tray (tap payload). On Android after native banner, skip
    //    channel sound to avoid a second system chime.
    try {
      await show(
        payload,
        playBeep: false,
        requestPermission: false,
        forceHeadsUp: true,
        playChannelSound: !nativeBannerShown,
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Flutter show backup failed: $error');
      }
    }

    await cancelSilentRelayNotifications();
  }

  /// Shows tray (title + body) as an immediate heads-up, then plays status beep.
  ///
  /// [forceHeadsUp] uses alarm category + full-screen intent flags so the
  /// banner appears on the home screen for inactive / background as well.
  static Future<void> show(
    NotificationPayload payload, {
    bool playBeep = true,
    bool requestPermission = true,
    bool forceHeadsUp = false,
    bool playChannelSound = true,
  }) async {
    if (kIsWeb) {
      return;
    }
    if (!_initialized) {
      await initialize();
    }

    if (Platform.isAndroid) {
      try {
        final status = await Permission.notification.status;
        if (!status.isGranted && requestPermission) {
          final requested = await Permission.notification.request();
          if (kDebugMode) {
            debugPrint('Notification permission request: $requested');
          }
        }
      } catch (error) {
        if (kDebugMode) {
          debugPrint('Notification permission check failed: $error');
        }
      }
    }

    final kind = payload.soundKind;
    final channel = _channelFor(kind);
    final androidSound = NotificationSound.androidRawName(kind);
    final iosSound = NotificationSound.iosSoundFile(kind);
    final title =
        payload.title.trim().isEmpty ? 'Job Notification' : payload.title.trim();
    final body = payload.body.trim().isEmpty
        ? 'You have a new job update.'
        : payload.body.trim();

    if (kDebugMode) {
      debugPrint('========== Notification Debug ==========');
      debugPrint('STATUS      : ${payload.status}');
      debugPrint('TYPE        : ${payload.type}');
      debugPrint('SOUND KIND  : $kind');
      debugPrint('CHANNEL ID  : ${channel.id}');
      debugPrint('TITLE       : $title');
      debugPrint('BODY        : $body');
      debugPrint('PLAY BEEP   : $playBeep');
      debugPrint('=======================================');
    }

    // Channel sound + vibration required for Android heads-up on home screen.
    // forceHeadsUp adds alarm category / fullScreenIntent for inactive+background.
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: Importance.max,
        priority: Priority.max,
        icon: '@drawable/ic_stat_notify',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        playSound: playChannelSound,
        sound: !playChannelSound || androidSound == null
            ? null
            : RawResourceAndroidNotificationSound(androidSound),
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 400, 200, 400]),
        category: forceHeadsUp
            ? AndroidNotificationCategory.alarm
            : AndroidNotificationCategory.message,
        visibility: NotificationVisibility.public,
        channelShowBadge: true,
        autoCancel: true,
        onlyAlertOnce: false,
        fullScreenIntent: forceHeadsUp,
        ticker: title,
        audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText: 'TechMate',
        ),
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: playChannelSound,
        sound: playChannelSound ? iosSound : null,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );

    // 1) Post heads-up banner with title + message immediately.
    final id = _notificationIdFor(payload);
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: jsonEncode(payload.toLocalPayload()),
    );

    if (kDebugMode) {
      debugPrint('Local notification heads-up shown id=$id title=$title');
    }

    // 2) Extra loudness via shared beep player.
    if (playBeep) {
      try {
        await playStatusBeep(payload);
      } catch (error) {
        if (kDebugMode) {
          debugPrint('playStatusBeep after tray failed: $error');
        }
      }
    }
  }

  static int _notificationIdFor(NotificationPayload payload) {
    final key = payload.jobId ?? payload.messageId;
    if (key == null || key.isEmpty) {
      return _notificationId++;
    }
    return key.hashCode & 0x7fffffff;
  }

  static Future<NotificationPayload?> getLaunchPayload() async {
    if (!_initialized) {
      await initialize();
    }
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) {
      return null;
    }
    final raw = details?.notificationResponse?.payload;
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return NotificationPayload.fromLocalMap(map);
    } catch (_) {
      return null;
    }
  }

  static AndroidNotificationChannel _channelFor(NotificationSoundKind kind) {
    final androidSound = NotificationSound.androidRawName(kind);
    return AndroidNotificationChannel(
      NotificationSound.channelId(kind),
      NotificationSound.channelName(kind),
      description: 'Job push notifications',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
      sound: androidSound == null
          ? null
          : RawResourceAndroidNotificationSound(androidSound),
    );
  }

  static void _onNotificationResponse(NotificationResponse response) {
    final raw = response.payload;
    if (raw == null || raw.isEmpty) {
      return;
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final payload = NotificationPayload.fromLocalMap(map);
      final inbox = inboxService;
      if (inbox != null) {
        inbox.openedFromNotificationTap = true;
        // ignore: discarded_futures
        inbox.handleUserOpened(payload);
      } else {
        NotificationCoordinator.enqueueDialog(payload);
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Local notification payload parse failed: $error');
      }
    }
  }
}
