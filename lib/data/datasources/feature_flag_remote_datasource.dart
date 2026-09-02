import 'package:brightspeed_fiber_app/core/constants/api_constants.dart';
import 'package:brightspeed_fiber_app/core/network/api_client.dart';
import 'package:brightspeed_fiber_app/domain/entities/feature_flags.dart';

class FeatureFlagRemoteDataSource {
  const FeatureFlagRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  /// GET http://10.0.2.2:8081/features/{userId} (Android emulator)
  Future<FeatureFlags> getFeatureFlags(int userId) async {
    final data = await _apiClient.getJson(
      '${ApiConstants.featureFlags}/$userId',
    );
    final features = data['features'];
    if (features is List) {
      return FeatureFlags.fromFeatureList(features);
    }
    return FeatureFlags.fromJson(data);
  }
}
