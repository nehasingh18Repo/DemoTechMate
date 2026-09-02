import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:brightspeed_fiber_app/core/notifications/notification_payload.dart';
import 'package:brightspeed_fiber_app/core/notifications/notification_priority.dart';
import 'package:brightspeed_fiber_app/domain/entities/stored_notification.dart';

/// Local sqflite inbox for push notifications (read/unread + priority).
class NotificationLocalDataSource {
  NotificationLocalDataSource();

  static const _dbName = 'techx_notifications.db';
  static const _table = 'notifications';

  Database? _db;

  Future<Database> _open() async {
    final existing = _db;
    if (existing != null && existing.isOpen) {
      return existing;
    }
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);
    final database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            message_id TEXT,
            title TEXT NOT NULL,
            body TEXT NOT NULL,
            priority TEXT NOT NULL,
            is_read INTEGER NOT NULL DEFAULT 0,
            job_id TEXT,
            status TEXT,
            type TEXT,
            sound TEXT,
            created_at_ms INTEGER NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_notifications_priority_read '
          'ON $_table (priority, is_read, created_at_ms)',
        );
      },
    );
    _db = database;
    return database;
  }

  Future<StoredNotification> insert(NotificationPayload payload) async {
    final db = await _open();
    final messageId = payload.messageId?.trim();
    if (messageId != null && messageId.isNotEmpty) {
      final existing = await db.query(
        _table,
        where: 'message_id = ?',
        whereArgs: [messageId],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        return _fromRow(existing.first);
      }
    }

    final createdAt = DateTime.now().millisecondsSinceEpoch;
    final id = await db.insert(_table, {
      'message_id': payload.messageId,
      'title': payload.title,
      'body': payload.body,
      'priority': payload.priority.storageValue,
      'is_read': 0,
      'job_id': payload.jobId,
      'status': payload.status,
      'type': payload.type,
      'sound': payload.sound,
      'created_at_ms': createdAt,
    });
    return StoredNotification(
      id: id,
      title: payload.title,
      body: payload.body,
      priority: payload.priority,
      isRead: false,
      createdAtMs: createdAt,
      messageId: payload.messageId,
      jobId: payload.jobId,
      status: payload.status,
      type: payload.type,
      sound: payload.sound,
    );
  }

  Future<List<StoredNotification>> getUnreadByPriorities(
    List<NotificationPriority> priorities,
  ) async {
    if (priorities.isEmpty) {
      return const [];
    }
    final db = await _open();
    final placeholders = List.filled(priorities.length, '?').join(',');
    final rows = await db.query(
      _table,
      where: 'is_read = 0 AND priority IN ($placeholders)',
      whereArgs: priorities.map((p) => p.storageValue).toList(),
      orderBy: 'created_at_ms DESC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<void> markRead(int id) async {
    final db = await _open();
    await db.update(
      _table,
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markAllRead(Iterable<int> ids) async {
    final list = ids.toList();
    if (list.isEmpty) {
      return;
    }
    final db = await _open();
    final placeholders = List.filled(list.length, '?').join(',');
    await db.rawUpdate(
      'UPDATE $_table SET is_read = 1 WHERE id IN ($placeholders)',
      list,
    );
  }

  Future<void> markReadByMessageId(String? messageId) async {
    if (messageId == null || messageId.isEmpty) {
      return;
    }
    final db = await _open();
    await db.update(
      _table,
      {'is_read': 1},
      where: 'message_id = ?',
      whereArgs: [messageId],
    );
  }

  StoredNotification _fromRow(Map<String, Object?> row) {
    return StoredNotification(
      id: row['id'] as int,
      title: row['title'] as String? ?? '',
      body: row['body'] as String? ?? '',
      priority: NotificationPriority.fromStorage(row['priority'] as String?),
      isRead: (row['is_read'] as int? ?? 0) == 1,
      createdAtMs: row['created_at_ms'] as int? ?? 0,
      messageId: row['message_id'] as String?,
      jobId: row['job_id'] as String?,
      status: row['status'] as String?,
      type: row['type'] as String?,
      sound: row['sound'] as String?,
    );
  }
}
