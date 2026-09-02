import 'package:dio/dio.dart';
import 'package:brightspeed_fiber_app/core/network/auth_token_holder.dart';

/// Adds `Authorization: Bearer <token>` to protected requests.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokenHolder);

  final AuthTokenHolder _tokenHolder;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _tokenHolder.token;
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
