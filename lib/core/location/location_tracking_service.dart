import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:brightspeed_fiber_app/core/location/device_location.dart';
import 'package:brightspeed_fiber_app/core/sync/jobs_sync_service.dart';
import 'package:brightspeed_fiber_app/core/utils/result.dart';
import 'package:brightspeed_fiber_app/domain/entities/pending_location.dart';
import 'package:brightspeed_fiber_app/domain/repositories/location_repository.dart';
import 'package:geolocator/geolocator.dart';

/// Periodically captures GPS and syncs to POST /api/location/user/{userId}.
///
/// Online:
///   Sends the current location to the API.
///
/// Offline:
///   Stores the location in local DB.
///
/// Connectivity restored:
///   Sends queued locations using batch API.
///
/// GPS disabled:
///   Notifies UI so that the app can show a location-off popup.
///
/// GPS enabled again:
///   Notifies UI so the popup can be dismissed and tracking continues.
class LocationTrackingService {
  LocationTrackingService({
    required LocationRepository locationRepository,
    JobsSyncService? jobsSyncService,
    Connectivity? connectivity,
    this.interval = const Duration(minutes: 1),
    this.maxRetries = 1,
  })  : _repository = locationRepository,
        _jobsSyncService = jobsSyncService,
        _connectivity = connectivity ?? Connectivity();

  final LocationRepository _repository;
  final JobsSyncService? _jobsSyncService;
  final Connectivity _connectivity;

  final Duration interval;
  final int maxRetries;

  // Location API timer.
  Timer? _timer;

  // GPS status checking timer (fallback if the service-status stream is quiet).
  Timer? _gpsTimer;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<ServiceStatus>? _gpsServiceStatusSub;

  int? _userId;

  bool _tickInFlight = false;
  bool _flushInFlight = false;
  bool _started = false;
  bool _wasOffline = false;

  // Prevent popup from appearing repeatedly while GPS remains off.
  bool _gpsPopupShown = false;
  bool _permissionRequested = false;

  /// App/UI provides this callback.
  ///
  /// When GPS is OFF, LocationTrackingService calls this callback.
  VoidCallback? onGpsDisabled;

  /// App/UI provides this callback.
  ///
  /// When GPS turns ON again, LocationTrackingService calls this callback
  /// so a visible location-off dialog can be dismissed.
  VoidCallback? onGpsEnabled;

  bool get isRunning => _started && _userId != null;

  /// Start location tracking for logged-in user.
  Future<void> start(int userId) async {
    debugPrint('LOCATION: start() called userId=$userId');

    // Already running for same user.
    if (_started && _userId == userId) {
      _log('already running for userId=$userId');
      return;
    }

    await stop();

    _userId = userId;
    _started = true;

    _log(
      'started for userId=$userId '
      'interval=${interval.inMinutes}m',
    );

    // ----------------------------------------------------------
    // CONNECTIVITY LISTENER
    // ----------------------------------------------------------

    _connectivitySub =
        _connectivity.onConnectivityChanged.listen((results) {
      final online =
          results.any((r) => r != ConnectivityResult.none);

      if (online && _wasOffline) {
        _log('connectivity restored — flushing offline queue');
        // _reportBanner(
        //   JobsSyncState.queued,
        //   'App is online — syncing queued locations',
        // );
        unawaited(flushPendingQueue());
      }

      _wasOffline = !online;
    });

    // ----------------------------------------------------------
    // INITIAL LOCATION SYNC
    // ----------------------------------------------------------

    _wasOffline = !(await _repository.isOnline());

    await _prepareLocationAccess();

    unawaited(flushPendingQueue());

    unawaited(_tick());

    // ----------------------------------------------------------
    // LOCATION API TIMER
    // ----------------------------------------------------------

    _timer = Timer.periodic(
      interval,
      (_) => unawaited(_tick()),
    );

    // ----------------------------------------------------------
    // GPS CHECK TIMER
    //
    // This checks Android GPS/Location Service every 5 seconds.
    // It is separate from the 1-minute location API timer.
    // ----------------------------------------------------------

    _gpsTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(checkGpsAndNotify()),
    );

    _listenToGpsServiceStatus();

    // Check GPS immediately after login/session restore.
    unawaited(checkGpsAndNotify());
  }

  /// Stop location tracking.
  Future<void> stop() async {
    await _connectivitySub?.cancel();
    _connectivitySub = null;

    // Stop location API timer.
    _timer?.cancel();
    _timer = null;

    // Stop GPS checker timer.
    _gpsTimer?.cancel();
    _gpsTimer = null;

    await _gpsServiceStatusSub?.cancel();
    _gpsServiceStatusSub = null;

    _userId = null;

    _started = false;

    _tickInFlight = false;
    _flushInFlight = false;

    if (_gpsPopupShown) {
      onGpsEnabled?.call();
    }
    _gpsPopupShown = false;
    _permissionRequested = false;

    _log('stopped');
  }

  // ==========================================================
  // GPS
  // ==========================================================

  /// Returns true if the device Location/GPS service is enabled.
  Future<bool> isGpsEnabled() async {
    return Geolocator.isLocationServiceEnabled();
  }

  /// True when the OS location toggle is off or the app cannot use location.
  Future<bool> shouldPromptForGps() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return true;
    }

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.deniedForever) {
      return true;
    }
    if (permission == LocationPermission.denied && _permissionRequested) {
      return true;
    }
    return false;
  }

  /// Requests runtime permission once so [shouldPromptForGps] can distinguish
  /// "not asked yet" from "user denied".
  Future<void> _prepareLocationAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.denied) {
      return;
    }

    _permissionRequested = true;
    await Geolocator.requestPermission();
  }

  /// Re-checks GPS after [AppLifecycleState.resumed] (e.g. returning from Settings).
  Future<void> handleAppResumed() async {
    if (!_started) {
      return;
    }

    _log('app resumed — rechecking GPS');
    await checkGpsAndNotify();
    unawaited(flushPendingQueue());

    if (await Geolocator.isLocationServiceEnabled()) {
      unawaited(_tick());
    }
  }

  /// Lets the UI show the GPS-off popup again after dismiss.
  void resetGpsDisabledPrompt() {
    _gpsPopupShown = false;
  }

  void _listenToGpsServiceStatus() {
    unawaited(_gpsServiceStatusSub?.cancel());
    try {
      _gpsServiceStatusSub =
          Geolocator.getServiceStatusStream().listen(
        (status) {
          _log('GPS service status stream: $status');
          unawaited(checkGpsAndNotify());
        },
        onError: (Object error) {
          _log('GPS service status stream error: $error');
        },
      );
    } catch (error) {
      _log('GPS service status stream unavailable: $error');
    }
  }

  /// Checks GPS status and notifies UI when GPS is disabled or re-enabled.
  ///
  /// Called on a timer, from the service-status stream, on capture, and on resume.
  Future<void> checkGpsAndNotify() async {
    if (!_started) {
      return;
    }

    final needsPrompt = await shouldPromptForGps();

    _log('GPS check: needsPrompt=$needsPrompt');

    if (needsPrompt) {
      if (onGpsDisabled == null) {
        _log('location/GPS unavailable but onGpsDisabled is not wired');
        return;
      }

      _gpsPopupShown = true;
      _log('location/GPS unavailable — notifying UI');

      onGpsDisabled!.call();
      return;
    }

    if (_gpsPopupShown) {
      _gpsPopupShown = false;
      _log('location/GPS available again — notifying UI and continuing tracking');
      onGpsEnabled?.call();
      unawaited(_tick());
    }
  }

  /// Opens the platform Location/GPS settings screen.
  ///
  /// Android: system location settings.
  /// iOS: app settings (system Location Services has no public URL).
  Future<void> openGpsSettings() async {
    _log('Opening Location Settings');
    await Geolocator.openLocationSettings();
  }

  // ==========================================================
  // LOCATION SYNC
  // ==========================================================

  /// Force one location capture.
  ///
  /// Online  -> API
  /// Offline -> local DB
  Future<Result<DeviceLocation>> syncOnce(int userId) {
    return _captureAndHandle(userId);
  }

  /// Periodic location tick.
  Future<void> _tick() async {
    final userId = _userId;

    if (!_started || userId == null || _tickInFlight) {
      return;
    }

    _tickInFlight = true;

    try {
      // First try to send queued offline locations.
      await flushPendingQueue();

      // Capture and send current location.
      await _captureAndHandle(userId);
    } finally {
      _tickInFlight = false;
    }
  }

  // ==========================================================
  // OFFLINE QUEUE
  // ==========================================================

  /// Sends all pending offline locations using batch API.
  Future<void> flushPendingQueue() async {
    final userId = _userId;

    if (!_started || userId == null || _flushInFlight) {
      return;
    }

    if (!await _repository.isOnline()) {
      _log('flush skipped — still offline');
      return;
    }

    _flushInFlight = true;

    try {
      final pendingResult =
          await _repository.getPendingLocations(userId);

      switch (pendingResult) {
        case ErrorResult(:final failure):
          _log(
            'flush read failed: ${failure.message}',
          );
          // _reportBanner(
          //   JobsSyncState.failed,
          //   'Location queue read failed: ${failure.message}',
          // );
          return;

        case Success(:final data):
          if (data.isEmpty) {
            return;
          }

          if (data.length == 1) {
            final item = data.first;
            _log(
              'flushing 1 offline location via location API',
            );
            // _reportBanner(
            //   JobsSyncState.syncing,
            //   'Calling location API for queued lat/long',
            // );
            final syncOk = await _syncWithRetry(
              userId: userId,
              location: item.toDeviceLocation(),
              reportBanner: true,
            );
            if (!syncOk) {
              _log('single location flush failed — will retry later');
              // _reportBanner(
              //   JobsSyncState.failed,
              //   'Location API failed — will retry later',
              // );
              return;
            }
            await _repository.deletePendingLocation(item.id);
            _log('single location flush ok — cleared queued location');
            return;
          }

          _log(
            'flushing ${data.length} offline location(s) '
            'via batch API',
          );
          // _reportBanner(
          //   JobsSyncState.syncing,
          //   'Calling location batch API for ${data.length} lat/longs',
          // );

          final batchOk = await _syncBatchWithRetry(
            userId: userId,
            locations: data,
          );

          if (!batchOk) {
            _log(
              'batch flush failed — will retry later',
            );
            // _reportBanner(
            //   JobsSyncState.failed,
            //   'Location batch API failed — will retry later',
            // );
            return;
          }

          await _repository.clearPendingLocations(userId);

          _log(
            'batch flush ok — '
            'cleared ${data.length} queued location(s)',
          );
      }
    } finally {
      _flushInFlight = false;
    }
  }

  // ==========================================================
  // CAPTURE LOCATION
  // ==========================================================

  Future<Result<DeviceLocation>> _captureAndHandle(
    int userId,
  ) async {
    final needsPrompt = await shouldPromptForGps();

    _log(
      'capture: needsPrompt=$needsPrompt',
    );

    if (needsPrompt) {
      _log(
        'capture skipped because location/GPS is unavailable',
      );

      if (onGpsDisabled != null) {
        _gpsPopupShown = true;
        onGpsDisabled!.call();
      }

      final locationResult =
          await _repository.getCurrentLocation();

      return locationResult;
    }

    final locationResult =
        await _repository.getCurrentLocation();

    switch (locationResult) {
      case ErrorResult(:final failure):
        _log(
          'capture failed: ${failure.message}',
        );

        return locationResult;

      case Success(:final data):
        final online =
            await _repository.isOnline();

        if (!online) {
          return _storeOffline(
            userId: userId,
            location: data,
          );
        }

        return _sendOnline(
          userId: userId,
          location: data,
        );
    }
  }

  // ==========================================================
  // ONLINE API
  // ==========================================================

  Future<Result<DeviceLocation>> _sendOnline({
    required int userId,
    required DeviceLocation location,
  }) async {
    final syncOk = await _syncWithRetry(
      userId: userId,
      location: location,
    );

    if (syncOk) {
      _log(
        'synced online '
        'userId=$userId '
        'location=${location.locationString} '
        'at=${location.dateTimeUtc} '
        'uuid=${location.uuid}',
      );

      return Success(location);
    }

    // API failed -> store locally.
    _log(
      'online sync failed — queuing offline',
    );

    return _storeOffline(
      userId: userId,
      location: location,
    );
  }

  // ==========================================================
  // STORE OFFLINE
  // ==========================================================

  Future<Result<DeviceLocation>> _storeOffline({
    required int userId,
    required DeviceLocation location,
  }) async {
    final enqueue =
        await _repository.enqueueOfflineLocation(
      userId: userId,
      location: location,
    );

    switch (enqueue) {
      case Success(:final data):
        _log(
          'queued offline '
          'id=${data.id} '
          'userId=$userId '
          'location=${location.locationString} '
          'at=${location.dateTimeUtc} '
          'uuid=${location.uuid}',
        );
        // _reportBanner(
        //   JobsSyncState.queued,
        //   'Location saved offline — waiting to sync',
        // );

        return Success(location);

      case ErrorResult(:final failure):
        _log(
          'offline queue failed: ${failure.message}',
        );

        return ErrorResult(failure);
    }
  }

  // ==========================================================
  // SINGLE LOCATION RETRY
  // ==========================================================

  Future<bool> _syncWithRetry({
    required int userId,
    required DeviceLocation location,
    bool reportBanner = false,
  }) async {
    for (
      var attempt = 1;
      attempt <= maxRetries;
      attempt++
    ) {
      final result =
          await _repository.syncLocation(
        userId: userId,
        location: location,
      );

      switch (result) {
        case Success(:final data):
          if (reportBanner) {
            // _reportBanner(
            //   JobsSyncState.success,
            //   data.isEmpty ? 'Location synced' : data,
            // );
          }
          return true;

        case ErrorResult(:final failure):
          _log(
            'sync attempt '
            '$attempt/$maxRetries failed: '
            '${failure.message}',
          );
          if (reportBanner) {
            // _reportBanner(
            //   JobsSyncState.syncing,
            //   'Location API failed: ${failure.message}',
            // );
          }

          if (attempt < maxRetries) {
            await Future<void>.delayed(
              Duration(seconds: 2 * attempt),
            );
          }
      }
    }

    return false;
  }

  // ==========================================================
  // BATCH RETRY
  // ==========================================================

  Future<bool> _syncBatchWithRetry({
    required int userId,
    required List<PendingLocation> locations,
  }) async {
    for (
      var attempt = 1;
      attempt <= maxRetries;
      attempt++
    ) {
      final result =
          await _repository.syncPendingLocationsBatch(
        userId: userId,
        locations: locations,
      );

      switch (result) {
        case Success(:final data):
          // _reportBanner(
          //   JobsSyncState.success,
          //   data.isEmpty
          //       ? '${locations.length} locations synced'
          //       : data,
          // );
          return true;

        case ErrorResult(:final failure):
          _log(
            'batch sync attempt '
            '$attempt/$maxRetries failed: '
            '${failure.message}',
          );
          // _reportBanner(
          //   JobsSyncState.syncing,
          //   'Location batch API failed: ${failure.message}',
          // );

          if (attempt < maxRetries) {
            await Future<void>.delayed(
              Duration(seconds: 2 * attempt),
            );
          }
      }
    }

    return false;
  }

  void _reportBanner(JobsSyncState state, String message) {
    _jobsSyncService?.reportLocationSync(state, message);
  }

  // ==========================================================
  // LOG
  // ==========================================================

  void _log(String message) {
    if (kDebugMode) {
      debugPrint(
        'LocationTracking: $message',
      );
    }
  }
}