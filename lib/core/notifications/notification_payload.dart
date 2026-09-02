import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:brightspeed_fiber_app/core/notifications/notification_priority.dart';
import 'package:brightspeed_fiber_app/core/notifications/notification_sound.dart';
import 'package:brightspeed_fiber_app/domain/entities/stored_notification.dart';

/// Normalized FCM / local-notification payload used across all app states.
class NotificationPayload {
  const NotificationPayload({
    required this.title,
    required this.body,
    this.jobId,
    this.messageId,
    this.status,
    this.type,
    this.sound,
    this.priority = NotificationPriority.high,
  });

  final String title;
  final String body;
  final String? jobId;
  final String? messageId;

  /// Job / notification status from FCM data (e.g. Pending, Assigned, Completed).
  final String? status;

  /// Notification category / service type (e.g. WiFi Installation).
  final String? type;

  /// Optional explicit sound name from FCM data.
  final String? sound;

  /// Urgency: high → popup list; medium/low → silent background task update.
  final NotificationPriority priority;

  NotificationSoundKind get soundKind => NotificationSound.resolve(
        status: status,
        type: type,
        sound: sound,
      );

  factory NotificationPayload.fromRemoteMessage(RemoteMessage message) {
    final data = message.data;
    final notification = message.notification;

    final jobId = _firstNonEmpty([
      data['jobId'],
      data['job_id'],
      data['id'],
    ]);

    final title = _firstNonEmpty([
          notification?.title,
          data['title'],
          data['Title'],
        ]) ??
        'Job Notification';

    final body = _firstNonEmpty([
          notification?.body,
          data['body'],
          data['message'],
          data['subtitle'],
        ]) ??
        'You have a new job update.';

    String? status = _firstNonEmpty([
      data['status'],
      data['jobStatus'],
      data['job_status'],
      data['Status'],
    ]);

    if (status == null || status.isEmpty) {
      final match = RegExp(r'updated to\s+([A-Z_]+)', caseSensitive: false)
          .firstMatch(body);
      status = match?.group(1);
    }

    return NotificationPayload(
      title: title,
      body: body,
      jobId: jobId,
      messageId: message.messageId,
      status: status,
      type: _firstNonEmpty([
        data['type'],
        data['notificationType'],
        data['notification_type'],
        data['category'],
        data['serviceType'],
        data['service_type'],
        data['jobType'],
        data['job_type'],
      ]),
      sound: _firstNonEmpty([
        data['sound'],
        data['notification_sound'],
        data['notificationSound'],
        notification?.android?.sound,
        notification?.apple?.sound,
      ]),
      priority: NotificationPriority.fromRaw(
        _firstNonEmpty([
          data['priority'],
          data['Priority'],
          data['notification_priority'],
          data['notificationPriority'],
          data['urgency'],
        ]),
      ),
    );
  }

  factory NotificationPayload.fromLocalMap(Map<String, dynamic> data) {
    return NotificationPayload(
      title: _firstNonEmpty([data['title'], data['Title']]) ?? 'Job Notification',
      body: _firstNonEmpty([
            data['body'],
            data['message'],
            data['subtitle'],
          ]) ??
          'You have a new job update.',
      jobId: _firstNonEmpty([data['jobId'], data['job_id'], data['id']]),
      messageId: _firstNonEmpty([data['messageId'], data['message_id']]),
      status: _firstNonEmpty([
        data['status'],
        data['jobStatus'],
        data['job_status'],
        data['Status'],
      ]),
      type: _firstNonEmpty([
        data['type'],
        data['notificationType'],
        data['notification_type'],
        data['category'],
        data['serviceType'],
        data['service_type'],
        data['jobType'],
        data['job_type'],
      ]),
      sound: _firstNonEmpty([
        data['sound'],
        data['notification_sound'],
        data['notificationSound'],
      ]),
      priority: NotificationPriority.fromRaw(
        _firstNonEmpty([
          data['priority'],
          data['Priority'],
          data['notification_priority'],
          data['notificationPriority'],
          data['urgency'],
        ]),
      ),
    );
  }

  /// Rebuild a payload from a persisted inbox row (for list-item navigation).
  factory NotificationPayload.fromStored(StoredNotification item) {
    return NotificationPayload(
      title: item.title,
      body: item.body,
      jobId: item.jobId,
      messageId: item.messageId,
      status: item.status,
      type: item.type,
      sound: item.sound,
      priority: item.priority,
    );
  }

  Map<String, String> toLocalPayload() {
    return {
      'title': title,
      'body': body,
      if (jobId != null) 'jobId': jobId!,
      if (messageId != null) 'messageId': messageId!,
      if (status != null) 'status': status!,
      if (type != null) 'type': type!,
      if (sound != null) 'sound': sound!,
      'priority': priority.storageValue,
    };
  }

  static String? _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }
}
