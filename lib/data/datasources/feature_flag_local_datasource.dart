import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:brightspeed_fiber_app/domain/entities/feature_flags.dart';

class FeatureFlagLocalDataSource {
  const FeatureFlagLocalDataSource();

  static const assetPath = 'assets/local_json/featureflag_config.json';

  /// Loads flags from local JSON using `featureName` + `enabledFlag` only.
  /// `userId` in the JSON is ignored.
  Future<FeatureFlags> loadFeatureFlags() async {
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw);

    if (decoded is List) {
      return FeatureFlags.fromFeatureList(decoded);
    }

    if (decoded is Map<String, dynamic>) {
      final features = decoded['features'];

      if (features is List) {
        return FeatureFlags.fromFeatureList(features);
      }

      return FeatureFlags.fromJson(decoded);
    }

    if (decoded is Map) {
      return FeatureFlags.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    }

    return FeatureFlags.allEnabled;
  }
}