import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:brightspeed_fiber_app/core/utils/job_status_mapper.dart';
import 'package:brightspeed_fiber_app/data/models/job_model.dart';
import 'package:brightspeed_fiber_app/domain/entities/job.dart';
import 'package:brightspeed_fiber_app/domain/entities/job_outbox_event.dart';

/// SQLite cache + transactional FIFO outbox for offline job status updates.
class JobsLocalDataSource {
  JobsLocalDataSource();

  static const _dbName = 'techmate_jobs.db';
  static const _workTable = 'work_details';
  static const _outboxTable = 'outbox_events';
  static const _auditTable = 'sync_audit_log';

  Database? _db;

  Future<Database> _open() async {
    final existing = _db;
    if (existing != null && existing.isOpen) {
      return existing;
    }

    final path = p.join(await getDatabasesPath(), _dbName);
    final database = await openDatabase(
      path,
      version: 2,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE $_outboxTable '
            'ADD COLUMN created_offline INTEGER NOT NULL DEFAULT 1',
          );
        }
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_workTable (
            user_id INTEGER NOT NULL,
            job_id INTEGER NOT NULL,
            job_json TEXT NOT NULL,
            status TEXT NOT NULL,
            version INTEGER NOT NULL,
            updated_at_ms INTEGER NOT NULL,
            PRIMARY KEY (user_id, job_id)
          )
        ''');
        await db.execute('''
          CREATE TABLE $_outboxTable (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            transaction_id TEXT NOT NULL UNIQUE,
            user_id INTEGER NOT NULL,
            job_id INTEGER NOT NULL,
            status TEXT NOT NULL,
            version INTEGER NOT NULL,
            created_at_ms INTEGER NOT NULL,
            sync_status TEXT NOT NULL,
            retry_count INTEGER NOT NULL DEFAULT 0,
            last_error TEXT,
            created_offline INTEGER NOT NULL DEFAULT 1
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_job_outbox_fifo '
          'ON $_outboxTable (sync_status, created_at_ms, id)',
        );
        await db.execute('''
          CREATE TABLE $_auditTable (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            outbox_event_id INTEGER NOT NULL,
            transaction_id TEXT NOT NULL,
            error_message TEXT NOT NULL,
            retry_count INTEGER NOT NULL,
            created_at_ms INTEGER NOT NULL
          )
        ''');
      },
    );
    _db = database;
    return database;
  }

  /// Caches server jobs for offline reads without overwriting optimistic jobs
  /// that still have pending outbox events.
  Future<void> cacheJobs(int userId, List<JobModel> jobs) async {
    await _applyServerJobs(
      userId,
      jobs,
      flushSyncedOutbox: false,
    );
  }

  /// After sync completes and Jobs API returns, replaces all cached job rows
  /// with the server payload and removes every outbox row for the user.
  Future<void> applyServerJobsAndFlushSyncedStatusData(
    int userId,
    List<JobModel> jobs,
  ) async {
    final db = await _open();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.delete(
        _outboxTable,
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      for (final job in jobs) {
        await txn.insert(
          _workTable,
          {
            'user_id': userId,
            'job_id': job.id,
            'job_json': jsonEncode(job.toJson()),
            'status': JobStatusMapper.toApi(job.status),
            'version': _jobVersion(job.version),
            'updated_at_ms': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> _applyServerJobs(
    int userId,
    List<JobModel> jobs, {
    required bool flushSyncedOutbox,
  }) async {
    final db = await _open();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      if (flushSyncedOutbox) {
        await txn.delete(
          _outboxTable,
          where: 'user_id = ? AND sync_status IN (?, ?)',
          whereArgs: [userId, 'SUCCESS', 'FAILED'],
        );
      }

      for (final job in jobs) {
        final pending = Sqflite.firstIntValue(
              await txn.rawQuery(
                'SELECT COUNT(*) FROM $_outboxTable '
                'WHERE user_id = ? AND job_id = ? '
                "AND sync_status IN ('PENDING', 'PROCESSING', 'FAILED')",
                [userId, job.id],
              ),
            ) ??
            0;
        if (pending > 0) {
          continue;
        }
        await txn.insert(
          _workTable,
          {
            'user_id': userId,
            'job_id': job.id,
            'job_json': jsonEncode(job.toJson()),
            'status': JobStatusMapper.toApi(job.status),
            'version': _jobVersion(job.version),
            'updated_at_ms': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<JobModel>> getJobs(int userId) async {
    final db = await _open();
    final rows = await db.query(
      _workTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'updated_at_ms ASC, job_id ASC',
    );
    final models = rows.map((row) {
      final apiJobId = row['job_id'] as int;
      final json = _canonicalizeStoredJobJson(
        jsonDecode(row['job_json'] as String) as Map<String, dynamic>,
        apiJobId: apiJobId,
      );
      json['status'] = row['status'];
      json['version'] = _jobVersion(row['version'] as int?);
      return JobModel.fromJson(json);
    }).toList();
    return JobModel.withCardNumbers(models);
  }

  /// Cached job payloads for offline reads. Job details come from [job_json];
  /// status prefers the latest unsynced outbox value, then [work_details.status],
  /// then the cached API status in [job_json].
  Future<List<JobModel>> getJobsWithResolvedStatusForOffline(int userId) async {
    final db = await _open();
    final latestOutbox = await latestOutboxStatusByJob(userId);
    final rows = await db.query(
      _workTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'updated_at_ms ASC, job_id ASC',
    );
    final models = rows.map((row) {
      final apiJobId = row['job_id'] as int;
      final json = _canonicalizeStoredJobJson(
        jsonDecode(row['job_json'] as String) as Map<String, dynamic>,
        apiJobId: apiJobId,
      );
      final apiStatus = json['status']?.toString();
      final dbStatus = row['status'] as String?;
      json['status'] = _resolveOfflineStatus(
        dbStatus: latestOutbox[apiJobId] ?? dbStatus,
        apiStatus: apiStatus,
      );
      json['version'] = _jobVersion(row['version'] as int?);
      return JobModel.fromJson(json);
    }).toList();
    return JobModel.withCardNumbers(models);
  }

  /// Atomically updates the UI state and appends one FIFO outbox event.
  ///
  /// The event and local work row keep the version last read from the server.
  Future<bool> enqueueStatusUpdate({
    required int userId,
    required Job job,
    required String apiStatus,
    required String transactionId,
    required bool createdOffline,
  }) async {
    final apiJobId = job.id;
    if (apiJobId <= 0) {
      throw StateError(
        'Cannot save status for job "${job.name}" without a valid API job id',
      );
    }

    final db = await _open();
    return db.transaction((txn) async {
      final rows = await txn.query(
        _workTable,
        where: 'user_id = ? AND job_id = ?',
        whereArgs: [userId, apiJobId],
        limit: 1,
      );

      final normalizedTarget = _normalizeApiStatus(apiStatus);
      final pendingRows = await txn.query(
        _outboxTable,
        where:
            'user_id = ? AND job_id = ? AND sync_status IN (?, ?, ?)',
        whereArgs: [userId, apiJobId, 'PENDING', 'PROCESSING', 'FAILED'],
        orderBy: 'created_at_ms DESC, id DESC',
        limit: 1,
      );
      final latestOutboxStatus = pendingRows.isEmpty
          ? null
          : pendingRows.first['status'] as String?;
      final dbStatus =
          rows.isEmpty ? null : rows.first['status'] as String?;
      final effectiveStatus =
          latestOutboxStatus ?? dbStatus ?? JobStatusMapper.toApi(job.status);

      if (_normalizeApiStatus(effectiveStatus) == normalizedTarget) {
        return false;
      }

      final currentVersion = _jobVersion(
        rows.isEmpty
            ? job.version
            : (rows.first['version'] as int? ?? job.version),
      );
      final now = DateTime.now().millisecondsSinceEpoch;
      final jobJson = rows.isEmpty
          ? _jobToJson(job, status: apiStatus, version: currentVersion)
          : _canonicalizeStoredJobJson(
              jsonDecode(rows.first['job_json'] as String)
                  as Map<String, dynamic>,
              apiJobId: apiJobId,
            )
        ..['status'] = apiStatus
        ..['version'] = currentVersion;

      await txn.insert(
        _workTable,
        {
          'user_id': userId,
          'job_id': apiJobId,
          'job_json': jsonEncode(jobJson),
          'status': apiStatus,
          'version': currentVersion,
          'updated_at_ms': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(_outboxTable, {
        'transaction_id': transactionId,
        'user_id': userId,
        'job_id': apiJobId,
        'status': apiStatus,
        'version': currentVersion,
        'created_at_ms': now,
        'sync_status': 'PENDING',
        'retry_count': 0,
        'created_offline': createdOffline ? 1 : 0,
      });
      return true;
    });
  }

  /// Lets a new online session retry events that previously exhausted retries.
  Future<void> requeueFailedEvents(int userId) async {
    final db = await _open();
    await db.update(
      _outboxTable,
      {
        'sync_status': 'PENDING',
        'retry_count': 0,
        'last_error': null,
      },
      where: "user_id = ? AND sync_status = 'FAILED'",
      whereArgs: [userId],
    );
  }

  Future<void> recoverInterruptedEvents(int userId) async {
    final db = await _open();
    await db.update(
      _outboxTable,
      {'sync_status': 'PENDING'},
      where: "user_id = ? AND sync_status = 'PROCESSING'",
      whereArgs: [userId],
    );
  }

  Future<JobOutboxEvent?> getOldestPending(int userId) async {
    final db = await _open();
    final rows = await db.query(
      _outboxTable,
      where: "user_id = ? AND sync_status = 'PENDING'",
      whereArgs: [userId],
      orderBy: 'created_at_ms ASC, id ASC',
      limit: 1,
    );
    return rows.isEmpty ? null : _eventFromRow(rows.first);
  }

  Future<JobOutboxEvent?> getOldestFailed(int userId) async {
    final db = await _open();
    final rows = await db.query(
      _outboxTable,
      where: "user_id = ? AND sync_status = 'FAILED'",
      whereArgs: [userId],
      orderBy: 'created_at_ms ASC, id ASC',
      limit: 1,
    );
    return rows.isEmpty ? null : _eventFromRow(rows.first);
  }

  Future<void> markProcessing(int id) async {
    final db = await _open();
    await db.update(
      _outboxTable,
      {'sync_status': 'PROCESSING'},
      where: "id = ? AND sync_status = 'PENDING'",
      whereArgs: [id],
    );
  }

  Future<void> markSuccess(int id) async {
    final db = await _open();
    await db.update(
      _outboxTable,
      {'sync_status': 'SUCCESS', 'last_error': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> markRetryOrFailed(
    JobOutboxEvent event,
    String errorMessage,
  ) async {
    final db = await _open();
    final retryCount = event.retryCount + 1;
    final failed = retryCount >= 3;
    await db.transaction((txn) async {
      await txn.update(
        _outboxTable,
        {
          'sync_status': failed ? 'FAILED' : 'PENDING',
          'retry_count': retryCount,
          'last_error': errorMessage,
        },
        where: 'id = ?',
        whereArgs: [event.id],
      );
      if (failed) {
        await txn.insert(_auditTable, {
          'outbox_event_id': event.id,
          'transaction_id': event.transactionId,
          'error_message': errorMessage,
          'retry_count': retryCount,
          'created_at_ms': DateTime.now().millisecondsSinceEpoch,
        });
      }
    });
    return retryCount;
  }

  Future<int> pendingCount(int userId) async {
    final db = await _open();
    return Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM $_outboxTable '
            'WHERE user_id = ? '
            "AND sync_status IN ('PENDING', 'PROCESSING', 'FAILED')",
            [userId],
          ),
        ) ??
        0;
  }

  /// Latest unsynced status per job — last write wins for offline UI display.
  Future<Map<int, String>> latestOutboxStatusByJob(int userId) async {
    final db = await _open();
    final rows = await db.query(
      _outboxTable,
      columns: ['job_id', 'status'],
      where: 'user_id = ? AND sync_status IN (?, ?, ?)',
      whereArgs: [userId, 'PENDING', 'PROCESSING', 'FAILED'],
      orderBy: 'created_at_ms ASC, id ASC',
    );
    final latest = <int, String>{};
    for (final row in rows) {
      final jobId = row['job_id'] as int?;
      final status = row['status'] as String?;
      if (jobId != null && _isValidDbStatus(status)) {
        latest[jobId] = status!.trim();
      }
    }
    return latest;
  }

  Future<void> clearFinishedEvents(int userId) async {
    final db = await _open();
    await db.delete(
      _outboxTable,
      where: 'user_id = ? AND sync_status IN (?, ?)',
      whereArgs: [userId, 'SUCCESS', 'FAILED'],
    );
  }

  JobOutboxEvent _eventFromRow(Map<String, Object?> row) {
    return JobOutboxEvent(
      id: row['id'] as int,
      transactionId: row['transaction_id'] as String,
      userId: row['user_id'] as int,
      jobId: row['job_id'] as int,
      status: row['status'] as String,
      version: _jobVersion(row['version'] as int?),
      createdAtMs: row['created_at_ms'] as int,
      syncStatus: JobOutboxStatus.values.byName(
        (row['sync_status'] as String).toLowerCase(),
      ),
      retryCount: row['retry_count'] as int,
      lastError: row['last_error'] as String?,
      createdOffline: (row['created_offline'] as int? ?? 1) == 1,
    );
  }

  Map<String, dynamic> _jobToJson(
    Job job, {
    required String status,
    required int version,
  }) {
    return _canonicalizeStoredJobJson(
      {
        'name': job.name,
        'description': job.description,
        'index': job.index,
        'total': job.total,
        'phone': job.phone,
        'address': job.address,
        'serviceType': job.serviceType,
        'orderNumber': job.orderNumber,
        'techServiceAction': job.techServiceAction,
        'jobTimeframe': job.jobTimeframe,
        'dueDate': job.dueDate,
        'circuitId': job.circuitId,
        'dispatchJobType': job.dispatchJobType,
        'migratingFrom': job.migratingFrom,
        'dispatchTask': job.dispatchTask,
        'status': status,
        'brand': job.brand,
        'speed': job.speed,
        'technicianName': job.technicianName,
        'assignedByName': job.assignedBy,
        'version': version,
        'displayJobId': job.jobId,
      },
      apiJobId: job.id,
    );
  }

  /// Keeps the persisted JSON aligned with the DB primary key [apiJobId].
  Map<String, dynamic> _canonicalizeStoredJobJson(
    Map<String, dynamic> json, {
    required int apiJobId,
  }) {
    final normalized = Map<String, dynamic>.from(json);
    normalized['id'] = apiJobId;
    normalized['jobId'] = apiJobId;
    if (JobModel.parseDisplayJobId(normalized).isEmpty) {
      normalized['displayJobId'] = apiJobId.toString();
    } else if (normalized['displayJobId'] == null ||
        normalized['displayJobId'].toString().trim().isEmpty) {
      normalized['displayJobId'] = JobModel.parseDisplayJobId(normalized);
    }
    return normalized;
  }

  static int _jobVersion(int? value) {
    if (value == null || value < 1) {
      return 1;
    }
    return value;
  }

  static String _resolveOfflineStatus({
    required String? dbStatus,
    required String? apiStatus,
  }) {
    if (_isValidDbStatus(dbStatus)) {
      return dbStatus!.trim();
    }
    return apiStatus?.trim() ?? '';
  }

  static bool _isValidDbStatus(String? status) {
    return status != null && status.trim().isNotEmpty;
  }

  static String _normalizeApiStatus(String? status) {
    if (!_isValidDbStatus(status)) {
      return '';
    }
    return JobStatusMapper.toApi(JobStatusMapper.toDisplay(status!.trim()));
  }
}
