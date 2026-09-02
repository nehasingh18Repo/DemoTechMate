/// Device coordinates from Google Play Services / system GPS (via Geolocator).
class DeviceLocation {
  const DeviceLocation({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
     this.uuid,
  });

  final double latitude;
  final double longitude;

  /// UTC timestamp when the fix was obtained.
  final DateTime timestamp;
    final String? uuid;

  /// API body format: `"lat, lng"`.
  String get locationString => '$latitude, $longitude';

  /// ISO-8601 UTC string, e.g. `2026-08-04T16:59:00Z`.
  String get dateTimeUtc {
    final utc = timestamp.toUtc();
    final y = utc.year.toString().padLeft(4, '0');
    final m = utc.month.toString().padLeft(2, '0');
    final d = utc.day.toString().padLeft(2, '0');
    final h = utc.hour.toString().padLeft(2, '0');
    final min = utc.minute.toString().padLeft(2, '0');
    final s = utc.second.toString().padLeft(2, '0');
    return '$y-$m-${d}T$h:$min:${s}Z';
  }
}
