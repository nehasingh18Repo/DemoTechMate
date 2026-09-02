
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:brightspeed_fiber_app/core/location/device_location.dart';
import 'package:brightspeed_fiber_app/core/location/android_device_id.dart';

/// Reads latitude/longitude using the device GPS / Google Fused Location.
class LocationService {
  const LocationService();

  /// Ensures GPS is on and location permission is granted.
  /// Throws [LocationException] on denial or disabled GPS.
  Future<void> ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationException(
        'Location services are disabled. Please enable GPS.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const LocationException('Location permission denied.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        'Location permission permanently denied. Enable it in Settings.',
      );
    }
  }



  Future<DeviceLocation> getCurrentLocation() async {
    await ensurePermission();

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );


    final timestamp = position.timestamp;
    final androidId = await AndroidDeviceId.getAndroidId();
    final location = DeviceLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: timestamp.isUtc ? timestamp : timestamp.toUtc(),
      uuid: androidId,
    );

    if (kDebugMode) {
      debugPrint(
  'Location: lat=${location.latitude}, '
  'lng=${location.longitude}, '
  'at=${location.dateTimeUtc}, '
  'uuid=$androidId',
);
    }

    return location;
  }
}

class LocationException implements Exception {
  const LocationException(this.message);

  final String message;

  @override
  String toString() => message;
}
