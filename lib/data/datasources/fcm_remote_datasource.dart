import 'package:brightspeed_fiber_app/core/constants/api_constants.dart';
import 'package:brightspeed_fiber_app/core/network/api_client.dart';

class FcmRemoteDataSource {
  const FcmRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  /// Registers the device FCM token with the backend.
  /// POST /api/fcm/register  { "userId": int, "fcm": string }
  Future<void> registerFcm({
    required int userId,
    required String fcm,
  }) {
    return _apiClient.postVoid(
      ApiConstants.fcmRegister,
      body: {
        'userId': userId,
        'fcm': fcm,
      },
    );
  }
}
