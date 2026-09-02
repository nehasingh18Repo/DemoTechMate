import 'package:brightspeed_fiber_app/core/notifications/notification_priority.dart';

/// Persisted push notification row (local sqflite inbox).
class StoredNotification {
  const StoredNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.priority,
    required this.isRead,
    required this.createdAtMs,
    this.messageId,
    this.jobId,
    this.status,
    this.type,
    this.sound,
  });

  final int id;
  final String title;
  final String body;
  final NotificationPriority priority;
  final bool isRead;
  final int createdAtMs;
  final String? messageId;
  final String? jobId;
  final String? status;
  final String? type;
  final String? sound;

  int? get jobIdAsInt {
    final raw = jobId?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return int.tryParse(raw);
  }

  StoredNotification copyWith({bool? isRead}) {
    return StoredNotification(
      id: id,
      title: title,
      body: body,
      priority: priority,
      isRead: isRead ?? this.isRead,
      createdAtMs: createdAtMs,
      messageId: messageId,
      jobId: jobId,
      status: status,
      type: type,
      sound: sound,
    );
  }
}
