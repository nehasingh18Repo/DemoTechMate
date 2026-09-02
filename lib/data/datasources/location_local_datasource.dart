import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:brightspeed_fiber_app/core/location/device_location.dart';
import 'package:brightspeed_fiber_app/domain/entities/pending_location.dart';

/// Local sqflite queue for location points captured while offline.
class LocationLocalDataSource {
  LocationLocalDataSource();

  static const _dbName = 'techmate_pending_locations.db';
  static const _table = 'pending_locations';

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
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            date_time_utc TEXT NOT NULL,
            created_at_ms INTEGER NOT NULL,
            uuid TEXT
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_pending_locations_user_created '
          'ON $_table (user_id, created_at_ms)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE $_table ADD COLUMN uuid TEXT',
      );
    }
      
  },
    );
    _db = database;
    return database;
  }

  /// Persist one offline fix (lat, lng, timestamp).
  Future<PendingLocation> enqueue({
    required int userId,
    required DeviceLocation location,
  }) async {
    final db = await _open();
    final createdAt = DateTime.now().millisecondsSinceEpoch;
    final id = await db.insert(_table, {
      'user_id': userId,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'date_time_utc': location.dateTimeUtc,
      'created_at_ms': createdAt,
      'uuid': location.uuid,
    });
    return PendingLocation(
      id: id,
      userId: userId,
      latitude: location.latitude,
      longitude: location.longitude,
      timestamp: location.timestamp.toUtc(),
      uuid: location.uuid,
    );
  }

  /// Oldest-first pending rows for [userId].
  Future<List<PendingLocation>> getPending(int userId) async {
    final db = await _open();
    final rows = await db.query(
      _table,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at_ms ASC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<void> deleteById(int id) async {
    final db = await _open();
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearForUser(int userId) async {
    final db = await _open();
    await db.delete(_table, where: 'user_id = ?', whereArgs: [userId]);
  }

  Future<int> pendingCount(int userId) async {
    final db = await _open();
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM $_table WHERE user_id = ?',
      [userId],
    );
    return (result.first['c'] as int?) ?? 0;
  }

  PendingLocation _fromRow(Map<String, Object?> row) {
    final dateTimeRaw = row['date_time_utc'] as String?;
    DateTime timestamp;
    if (dateTimeRaw != null && dateTimeRaw.isNotEmpty) {
      timestamp = DateTime.tryParse(dateTimeRaw)?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(
            (row['created_at_ms'] as int?) ?? 0,
            isUtc: true,
          );
    } else {
      timestamp = DateTime.fromMillisecondsSinceEpoch(
        (row['created_at_ms'] as int?) ?? 0,
        isUtc: true,
      );
    }
    return PendingLocation(
      id: row['id'] as int,
      userId: row['user_id'] as int,
      latitude: (row['latitude'] as num).toDouble(),
      longitude: (row['longitude'] as num).toDouble(),
      timestamp: timestamp,
       uuid: row['uuid'] as String?,
    );
  }
}
