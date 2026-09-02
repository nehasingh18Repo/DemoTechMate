import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:brightspeed_fiber_app/core/error/exceptions.dart';
import 'package:brightspeed_fiber_app/core/network/connectivity_status_service.dart';
import 'package:brightspeed_fiber_app/data/datasources/jobs_local_datasource.dart';
import 'package:brightspeed_fiber_app/data/datasources/jobs_remote_datasource.dart';

enum JobsSyncState { idle, queued, syncing, success, failed }

class _QueuedJobsSyncStatus {
  const _QueuedJobsSyncStatus(this.state, this.message);

  final JobsSyncState state;
  final String message;
}

/// Foreground sync engine for the SQLite job outbox.
///
/// Events are processed one at a time in creation order. Each event carries a
/// UUID transaction id, making retries safe when a server response is lost.
class JobsSyncService extends ChangeNotifier {
  JobsSyncService({
    required JobsLocalDataSource localDataSource,
    required JobsRemoteDataSource remoteDataSource,
    required ConnectivityStatusService connectivityStatusService,
  })  : _local = localDataSource,
        _remote = remoteDataSource,
        _connectivity = connectivityStatusService;

  final JobsLocalDataSource _local;
  final JobsRemoteDataSource _remote;
  final ConnectivityStatusService _connectivity;

  // Every yellow-banner message stays visible for at least 1 second.
  static const _minimumStatusVisibleDuration = Duration(seconds: 1);

  int? _userId;
  bool _started = false;
  bool _syncing = false;
  bool _wasOnline = true;

  int _completionGeneration = 0;

  JobsSyncState _state = JobsSyncState.idle;
  String? _message;
  String? _lastSuccessMessage;

  JobsSyncState _locationState = JobsSyncState.idle;
  String? _locationMessage;

  final List<_QueuedJobsSyncStatus> _statusQueue = [];

  DateTime? _lastStatusShownAt;
  Timer? _statusTimer;

  bool get isOnline => _connectivity.isOnline;

  JobsSyncState get state => _state;

  String? get message => _message;

  JobsSyncState get locationState => _locationState;

  String? get locationMessage => _locationMessage;

  bool get isSyncing => _syncing;

  int get completionGeneration => _completionGeneration;

  Future<int> pendingOutboxCount() async {
    final userId = _userId;
    if (userId == null) {
      return 0;
    }
    return _local.pendingCount(userId);
  }

  Future<void> start(int userId) async {
    _userId = userId;

    final online = _connectivity.isOnline;
    final isFirstStart = !_started;

    if (!_started) {
      _connectivity.addListener(_onConnectivityChanged);
      _started = true;
      _wasOnline = online;
    }

    // Failed events are deliberately not requeued here: start() also runs on
    // every list refresh, and retrying from there would loop forever.
    await _local.recoverInterruptedEvents(userId);

    // Only set the connectivity banner on first start — tab switches and job
    // reloads call start() too and must not overwrite the current message.
    if (isFirstStart) {
      _showConnectivityBanner(online: online);
    } else if (online &&
        !_syncing &&
        _state != JobsSyncState.idle) {
      _showConnectivityBanner(online: true);
    }
  }

  void stop() {
    _userId = null;
    _state = JobsSyncState.idle;
    _message = null;
    _lastSuccessMessage = null;

    _locationState = JobsSyncState.idle;
    _locationMessage = null;

    _clearStatusQueue();

    _lastStatusShownAt = null;

    notifyListeners();
  }

  void notifyQueued(String displayStatus) {
    final online = _connectivity.isOnline;

    _setStatus(
      JobsSyncState.queued,
      online
          ? '$displayStatus saved — updating on server...'
          : '$displayStatus saved offline — waiting to sync',
    );

    // Online status picks use PATCH immediately. /api/jobs/sync (offline
    // outbox) runs only after offline → online in [_onConnectivityChanged].
    if (online) {
      unawaited(syncPending());
    }
  }

  /// Yellow-banner updates for offline location flush (single or batch).
  void reportLocationSync(JobsSyncState state, String message) {
    debugPrint('LOCATION_SYNC banner [$state] $message');

    _locationState = state;
    _locationMessage = message;

    notifyListeners();
  }

  void _onConnectivityChanged() {
    final userId = _userId;

    if (userId == null) {
      return;
    }

    final online = _connectivity.isOnline;

    // True only when the network changes from OFFLINE -> ONLINE.
    final cameOnline = online && !_wasOnline;

    debugPrint(
      'CONNECTIVITY CHANGED -> '
      'cameOnline: $cameOnline, '
      'online: $online, '
      'wasOnline: $_wasOnline, '
      'syncing: $_syncing',
    );

    // Always update previous state.
    _wasOnline = online;

    if (!online) {
      _refreshOfflineBanner();
      return;
    }

    if (cameOnline) {
      debugPrint(
        'JOBS_SYNC connectivity restored — '
        'starting FIFO /api/jobs/sync',
      );

      _clearStatusQueue();
      _setStatus(
        JobsSyncState.queued,
        'You are online. Syncing your changes...',
      );

      unawaited(_syncAfterReconnect(userId));
    }
  }

  Future<void> _syncAfterReconnect(int userId) async {
    await _local.recoverInterruptedEvents(userId);

    await _local.requeueFailedEvents(userId);

    await syncPending();
  }

  Future<void> syncPending({bool requestJobsRefresh = true}) async {
    final userId = _userId;

    if (userId == null || _syncing || !_connectivity.isOnline) {
      return;
    }

    _syncing = true;
    _lastSuccessMessage = null;

    var successCount = 0;
    var failedCount = 0;

    try {
      while (_connectivity.isOnline) {
        final event = await _local.getOldestPending(userId);

        if (event == null) {
          // Queue drained — caller or listener refreshes jobs after this returns.
          if (_connectivity.isOnline && requestJobsRefresh) {
            debugPrint(
              'JOBS_SYNC queue empty — $successCount synced, '
              '$failedCount failed — requesting jobs list refresh',
            );

            _completionGeneration++;
          }

          _clearStatusQueue();
          _showConnectivityBanner(online: _connectivity.isOnline);

          return;
        }

        await _local.markProcessing(event.id);

        final payload = event.toApiJson();

        debugPrint(
          'JOBS_SYNC FIFO sending $payload '
          '(createdOffline=${event.createdOffline})',
        );

        // _setStatus(
        //   JobsSyncState.syncing,
        //   event.createdOffline
        //       ? 'Calling /api/jobs/sync — jobId ${event.jobId}, '
        //           '${event.status}, version ${event.version}'
        //       : 'Updating job ${event.jobId} to ${event.status}',
        // );

        try {
          final response = await _remote.syncStatus(event);

          await _local.markSuccess(event.id);

          successCount++;

          _lastSuccessMessage =
              _successMessage(response, event.jobId, event.status);

          debugPrint(
            'JOBS_SYNC FIFO success txn=${event.transactionId} '
            'jobId=${event.jobId} response=$response',
          );

          _setStatus(
            JobsSyncState.syncing,
            'Sync success for job ${event.jobId}: $_lastSuccessMessage',
          );
        } catch (error) {
          final message = _errorMessage(error);

          debugPrint(
            'JOBS_SYNC FIFO failure txn=${event.transactionId} '
            'jobId=${event.jobId} error=$message',
          );

          final attempts =
              await _local.markRetryOrFailed(event, message);

          if (attempts >= 3) {
            // Give up on this event but keep draining the queue, so the jobs
            // list refresh still runs once every event has been attempted.
            failedCount++;

            // _setStatus(
            //   JobsSyncState.syncing,
            //   'Job ${event.jobId} failed after 3 attempts: $message. '
            //   'Continuing with the queue',
            // );

            continue;
          }

          // _setStatus(
          //   JobsSyncState.syncing,
          //   'Sync failed for job ${event.jobId}: $message. '
          //   'Retry $attempts of 2',
          // );

          _setStatus(
            JobsSyncState.syncing,
            'Sync failed for job ${event.jobId}: $message.',
          );

          if (!_connectivity.isOnline) {
            return;
          }

          await Future<void>.delayed(
            Duration(seconds: attempts),
          );
        }
      }
    } finally {
      _syncing = false;

      notifyListeners();
    }
  }

  String _successMessage(
    dynamic response,
    int jobId,
    String status,
  ) {
    if (response is Map<String, dynamic>) {
      final parts = <String>[];

      void addField(String label, Object? value) {
        final text = value?.toString().trim();

        if (text != null && text.isNotEmpty) {
          parts.add('$label: $text');
        }
      }

      addField(
        'code',
        _firstValue(
          response,
          const ['code', 'statusCode'],
        ),
      );

      addField(
        'message',
        _firstValue(
          response,
          const ['message', 'result'],
        ),
      );

      addField(
        'current status',
        _firstValue(
          response,
          const [
            'currentStatus',
            'current_status',
            'status',
          ],
        ),
      );

      addField(
        'geolocation response',
        _firstValue(
          response,
          const [
            'geolocationResponse',
            'geoLocationResponse',
            'geolocation_response',
            'locationResponse',
            'location_response',
          ],
        ),
      );

      if (parts.isNotEmpty) {
        return parts.join(', ');
      }
    }

    if (response is String && response.trim().isNotEmpty) {
      return response.trim();
    }

    return 'Job $jobId status '
        '${status.replaceAll('_', ' ')} synced';
  }

  Object? _firstValue(
    Map<String, dynamic> response,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = response[key];

      if (value != null) {
        return value;
      }
    }

    return null;
  }

  String _errorMessage(Object error) {
    if (error is ServerException) {
      return error.message;
    }

    return error.toString();
  }

  void _refreshOfflineBanner() {
    _showConnectivityBanner(online: false);
  }

  /// Resets the banner after sync + jobs API refresh completes.
  void completeSyncCycle() {
    _clearStatusQueue();
    _state = JobsSyncState.idle;
    _message = 'You are online';
    _lastStatusShownAt = DateTime.now();
    notifyListeners();
  }

  void _showConnectivityBanner({
    required bool online,
  }) {
    if (online) {
      _setStatus(JobsSyncState.idle, 'You are online');
      return;
    }

    _setStatus(
      JobsSyncState.queued,
      'You are offline. Changes will sync when you are back online',
    );
  }

  /// Queues banner updates so each message stays visible for at least 1 second.
  void _setStatus(
    JobsSyncState state,
    String message,
  ) {
    debugPrint(
      'JOBS_SYNC banner queued [$state] $message',
    );

    final now = DateTime.now();

    final lastShownAt = _lastStatusShownAt;

    if (lastShownAt == null ||
        now.difference(lastShownAt) >=
            _minimumStatusVisibleDuration) {
      _showStatus(state, message);
      return;
    }

    _statusQueue.add(
      _QueuedJobsSyncStatus(
        state,
        message,
      ),
    );

    _scheduleNextStatus();
  }

  void _showStatus(
    JobsSyncState state,
    String message,
  ) {
    debugPrint(
      'JOBS_SYNC banner [$state] $message',
    );

    _state = state;
    _message = message;
    _lastStatusShownAt = DateTime.now();

    notifyListeners();

    _scheduleNextStatus();
  }

  void _clearStatusQueue() {
    _statusQueue.clear();

    _statusTimer?.cancel();
    _statusTimer = null;
  }

  void _scheduleNextStatus() {
    if (_statusTimer != null ||
        _statusQueue.isEmpty) {
      return;
    }

    final lastShownAt = _lastStatusShownAt;

    final delay = lastShownAt == null
        ? Duration.zero
        : _minimumStatusVisibleDuration -
            DateTime.now().difference(lastShownAt);

    _statusTimer = Timer(
      delay.isNegative ? Duration.zero : delay,
      () {
        _statusTimer = null;

        if (_statusQueue.isEmpty) {
          return;
        }

        final next = _statusQueue.removeAt(0);

        _showStatus(
          next.state,
          next.message,
        );
      },
    );
  }

  @override
  void dispose() {
    if (_started) {
      _connectivity.removeListener(
        _onConnectivityChanged,
      );
    }

    _statusTimer?.cancel();

    super.dispose();
  }
}