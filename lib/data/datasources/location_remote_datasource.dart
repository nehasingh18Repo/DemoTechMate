import 'package:brightspeed_fiber_app/core/constants/api_constants.dart';
import 'package:brightspeed_fiber_app/core/location/device_location.dart';
import 'package:brightspeed_fiber_app/core/network/api_client.dart';
import 'package:brightspeed_fiber_app/domain/entities/pending_location.dart';

class LocationRemoteDataSource {
  const LocationRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  /// Single online fix:
  /// POST /api/location/user/{userId}
  /// Body: { "location": "lat, lng", "dateTime": "ISO-8601Z" }
  Future<dynamic> sendUserLocation({
    required int userId,
    required DeviceLocation location,
  }) {
    return _apiClient.postFlexible(
      '${ApiConstants.locationUserUpdate}/$userId',
      body: {
        'location': location.locationString,
        'dateTime': location.dateTimeUtc,
        'uuid': location.uuid,
      },
    );
  }

  /// Offline queue flush (batch):
  /// POST /api/location/user/{userId}
  /// Body: { "userLocationRequests": [ { requestId, location, dateTime }, ... ] }
  Future<dynamic> sendUserLocationsBatch({
    required int userId,
    required List<PendingLocation> locations,
  }) {
    final requests = <Map<String, dynamic>>[];
    for (var i = 0; i < locations.length; i++) {
      final item = locations[i];
      final device = item.toDeviceLocation();
      requests.add({
        'requestId': 'Req-${item.id}',
        'location': device.locationString,
        'dateTime': device.dateTimeUtc,
        'uuid': item.uuid,
      });
    }

    return _apiClient.postFlexible(
      '${ApiConstants.locationUserUpdate}/$userId',
      body: {
        'userLocationRequests': requests,
      },
    );
  }

  /// Legacy one-shot inventory endpoint (kept for compatibility).
  @Deprecated('Use sendUserLocation')
  Future<void> sendLocation({
    required int userId,
    required double latitude,
    required double longitude,
  }) async {
    await sendUserLocation(
      userId: userId,
      location: DeviceLocation(
        latitude: latitude,
        longitude: longitude,
        timestamp: DateTime.now().toUtc(),
        uuid: null,
      ),
    );
  }
}
