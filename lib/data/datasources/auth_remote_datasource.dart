import 'package:brightspeed_fiber_app/data/models/login_request_model.dart';
import 'package:brightspeed_fiber_app/data/models/login_response_model.dart';
import 'package:brightspeed_fiber_app/core/constants/api_constants.dart';
import 'package:brightspeed_fiber_app/core/network/api_client.dart';

class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<LoginResponseModel> login({
    required String username,
    required String password,
  }) async {
    final request = LoginRequestModel(username: username, password: password);
    final json = await _apiClient.postJson(
      ApiConstants.login,
      body: request.toJson(),
    );
    return LoginResponseModel.fromJson(json);
  }
}
