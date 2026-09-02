import 'package:brightspeed_fiber_app/core/location/device_location.dart';
import 'package:brightspeed_fiber_app/core/utils/result.dart';
import 'package:brightspeed_fiber_app/domain/entities/pending_location.dart';

/// Contract for reading device location and syncing it to the backend.
abstract class LocationRepository {
  Future<Result<DeviceLocation>> getCurrentLocation();

  /// POST /api/location/user/{userId} (online path).
  /// Returns the API response body as text when present.
  Future<Result<String>> syncLocation({
    required int userId,
    required DeviceLocation location,
  });

  /// Persist lat/lng/timestamp locally while offline.
  Future<Result<PendingLocation>> enqueueOfflineLocation({
    required int userId,
    required DeviceLocation location,
  });

  /// Pending offline rows for [userId], oldest first.
  Future<Result<List<PendingLocation>>> getPendingLocations(int userId);

  /// Remove a successfully synced offline row.
  Future<Result<void>> deletePendingLocation(int id);

  /// Remove all offline rows for [userId] after a successful batch sync.
  Future<Result<void>> clearPendingLocations(int userId);

  /// Flush offline queue via batch API:
  /// `{ "userLocationRequests": [ ... ] }`.
  Future<Result<String>> syncPendingLocationsBatch({
    required int userId,
    required List<PendingLocation> locations,
  });

  /// True when the device currently has network connectivity.
  Future<bool> isOnline();
}
