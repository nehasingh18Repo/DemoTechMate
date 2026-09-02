import 'package:brightspeed_fiber_app/core/location/device_location.dart';

/// Offline-queued GPS fix waiting to be POSTed when the network returns.
class PendingLocation {
  const PendingLocation({
    required this.id,
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.uuid,
  });

  final int id;
  final int userId;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String? uuid;

  DeviceLocation toDeviceLocation() {
    return DeviceLocation(
      latitude: latitude,
      longitude: longitude,
      timestamp: timestamp,
      uuid: uuid,
    );
  }
}
