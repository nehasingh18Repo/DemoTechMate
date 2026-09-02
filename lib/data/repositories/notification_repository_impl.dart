import 'package:brightspeed_fiber_app/core/notifications/notification_payload.dart';
import 'package:brightspeed_fiber_app/core/notifications/notification_priority.dart';
import 'package:brightspeed_fiber_app/data/datasources/notification_local_datasource.dart';
import 'package:brightspeed_fiber_app/domain/entities/stored_notification.dart';
import 'package:brightspeed_fiber_app/domain/repositories/notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl(this._local);

  final NotificationLocalDataSource _local;

  @override
  Future<StoredNotification> saveIncoming(NotificationPayload payload) {
    return _local.insert(payload);
  }

  @override
  Future<List<StoredNotification>> getUnreadHighPriority() {
    return _local.getUnreadByPriorities(const [NotificationPriority.high]);
  }

  @override
  Future<List<StoredNotification>> getUnreadMediumLowPriority() {
    return _local.getUnreadByPriorities(const [
      NotificationPriority.medium,
      NotificationPriority.low,
    ]);
  }

  @override
  Future<void> markRead(int id) => _local.markRead(id);

  @override
  Future<void> markAllRead(Iterable<int> ids) => _local.markAllRead(ids);

  @override
  Future<void> markReadByMessageId(String? messageId) {
    return _local.markReadByMessageId(messageId);
  }
}
