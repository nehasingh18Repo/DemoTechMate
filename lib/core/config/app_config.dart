import 'dart:io';

import 'package:flutter/foundation.dart';


class AppConfig {
  AppConfig._();

  static const String _baseUrlOverrideKey = 'API_BASE_URL';
  static const String _featureFlagBaseUrlOverrideKey = 'FEATURE_API_BASE_URL';

  /// Override at build/run time: `--dart-define=API_BASE_URL=http://192.168.1.10:8080`
  static String get apiBaseUrl => _resolveBaseUrl(
        overrideKey: _baseUrlOverrideKey,
        port: 8080,
      );

  /// Feature-flag service runs on a separate port (8081).
  /// Override: `--dart-define=FEATURE_API_BASE_URL=http://192.168.1.10:8081`
  static String get featureFlagApiBaseUrl => _resolveBaseUrl(
        overrideKey: _featureFlagBaseUrlOverrideKey,
        port: 8080,
      );

  static String _resolveBaseUrl({
    required String overrideKey,
    required int port,
  }) {
    const apiOverride = String.fromEnvironment(_baseUrlOverrideKey);
    const featureOverride = String.fromEnvironment(_featureFlagBaseUrlOverrideKey);
    final override = overrideKey == _featureFlagBaseUrlOverrideKey
        ? featureOverride
        : apiOverride;
    if (override.isNotEmpty) {
      return _normalize(override);
    }

    if (kIsWeb) {
      return 'http://localhost:$port';
      //return 'http://8.231.216.90:9090';
    }

    if (Platform.isAndroid) {
      // Android emulator maps host machine localhost to 10.0.2.2
      return 'http://10.0.2.2:$port';
      //return 'http://8.231.216.90:9090';
    }

    // iOS simulator and desktop can reach localhost directly
    return 'http://8.231.216.90:9090';
  }

  static String _normalize(String value) {
    var url = value.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }
}
