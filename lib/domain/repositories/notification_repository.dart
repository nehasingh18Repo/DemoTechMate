import 'package:brightspeed_fiber_app/core/notifications/notification_payload.dart';
import 'package:brightspeed_fiber_app/domain/entities/stored_notification.dart';

abstract class NotificationRepository {
  Future<StoredNotification> saveIncoming(NotificationPayload payload);

  Future<List<StoredNotification>> getUnreadHighPriority();

  Future<List<StoredNotification>> getUnreadMediumLowPriority();

  Future<void> markRead(int id);

  Future<void> markAllRead(Iterable<int> ids);

  Future<void> markReadByMessageId(String? messageId);
}
