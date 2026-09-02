import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:brightspeed_fiber_app/core/config/app_config.dart';
import 'package:brightspeed_fiber_app/core/error/exceptions.dart';
import 'package:brightspeed_fiber_app/core/network/auth_interceptor.dart';
import 'package:brightspeed_fiber_app/core/network/auth_token_holder.dart';

/// Centralized Dio client for all HTTP traffic.
class ApiClient {
  ApiClient({
    required AuthTokenHolder tokenHolder,
    String? baseUrl,
    Dio? dio,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? AppConfig.apiBaseUrl,
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 20),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
              ),
            ) {
    _dio.interceptors.add(AuthInterceptor(tokenHolder));
    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          error: true,
        ),
      );
    }
  }

  final Dio _dio;

  Dio get dio => _dio;

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: queryParameters,
      );
      return _parseMap(response);
    } on DioException catch (error) {
      throw _mapDioError(error);
    }
  }

  Future<List<dynamic>> getJsonList(String path) async {
    try {
      final response = await _dio.get<dynamic>(path);
      final data = response.data;
      if (data is List<dynamic>) {
        return data;
      }
      if (data is Map<String, dynamic>) {
        final jobs = data['jobs'];
        if (jobs is List<dynamic>) {
          return jobs;
        }
      }
      throw const ServerException('Unexpected list response format.');
    } on DioException catch (error) {
      throw _mapDioError(error);
    }
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        data: body,
      );
      return _parseMap(response);
    } on DioException catch (error) {
      throw _mapDioError(error);
    }
  }

  /// POST accepting JSON, plain text, or an empty 2xx response.
  Future<dynamic> postFlexible(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        path,
        data: body,
        options: Options(
          responseType: ResponseType.json,
          headers: const {'Accept': '*/*'},
          validateStatus: (status) => status != null && status < 600,
        ),
      );
      _ensureSuccessStatus(response.statusCode, response.data);
      return response.data;
    } on DioException catch (error) {
      if (_isSuccessfulLooseBody(error)) {
        return error.response?.data;
      }
      throw _mapDioError(error);
    } on FormatException {
      // Some sync deployments return plain text despite a JSON content type.
      return null;
    }
  }

  /// POST that accepts **both**:
  /// - plain text bodies (e.g. `location saved successfully`)
  /// - JSON bodies / empty bodies
  ///
  /// Any HTTP 2xx is treated as success regardless of body format, so Dio
  /// `FormatException` on plain text never fails the location/FCM calls.
  Future<void> postVoid(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        path,
        data: body,
        options: Options(
          responseType: ResponseType.plain,
          headers: const {'Accept': '*/*'},
          // Let us inspect non-2xx ourselves; still catch transport errors.
          validateStatus: (status) => status != null && status < 600,
        ),
      );
      _ensureSuccessStatus(response.statusCode, response.data);
    } on DioException catch (error) {
      if (_isSuccessfulLooseBody(error)) {
        if (kDebugMode) {
          debugPrint(
            'ApiClient.postVoid: treating non-JSON 2xx as success '
            '(${error.response?.statusCode})',
          );
        }
        return;
      }
      throw _mapDioError(error);
    } on FormatException catch (error) {
      // Body arrived but was not JSON — still OK for void endpoints.
      if (kDebugMode) {
        debugPrint('ApiClient.postVoid: FormatException ignored: $error');
      }
    }
  }

  /// PATCH accepting JSON, plain text, or an empty 2xx response.
  Future<dynamic> patchFlexible(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await _dio.patch<dynamic>(
        path,
        data: body,
        options: Options(
          responseType: ResponseType.json,
          headers: const {'Accept': '*/*'},
          validateStatus: (status) => status != null && status < 600,
        ),
      );
      _ensureSuccessStatus(response.statusCode, response.data);
      return response.data;
    } on DioException catch (error) {
      if (_isSuccessfulLooseBody(error)) {
        return error.response?.data;
      }
      throw _mapDioError(error);
    } on FormatException {
      return null;
    }
  }

  /// PATCH that accepts plain text or JSON success bodies (same as [postVoid]).
  Future<void> patchJson(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await _dio.patch<dynamic>(
        path,
        data: body,
        options: Options(
          responseType: ResponseType.plain,
          headers: const {'Accept': '*/*'},
          validateStatus: (status) => status != null && status < 600,
        ),
      );
      _ensureSuccessStatus(response.statusCode, response.data);
    } on DioException catch (error) {
      if (_isSuccessfulLooseBody(error)) {
        if (kDebugMode) {
          debugPrint(
            'ApiClient.patchJson: treating non-JSON 2xx as success '
            '(${error.response?.statusCode})',
          );
        }
        return;
      }
      throw _mapDioError(error);
    } on FormatException catch (error) {
      if (kDebugMode) {
        debugPrint('ApiClient.patchJson: FormatException ignored: $error');
      }
    }
  }

  void _ensureSuccessStatus(int? statusCode, dynamic data) {
    final code = statusCode ?? 0;
    if (code >= 200 && code < 300) {
      return;
    }
    final message = switch (data) {
      final String s when s.trim().isNotEmpty => s.trim(),
      final Map m => (m['message'] ?? m['error'] ?? m['detail'])?.toString(),
      _ => null,
    };
    throw ServerException(
      message?.isNotEmpty == true ? message! : 'Request failed ($code).',
      statusCode: code == 0 ? null : code,
    );
  }

  /// True when the server returned HTTP 2xx but Dio failed while decoding
  /// the body (plain text like "location saved successfully").
  bool _isSuccessfulLooseBody(DioException error) {
    final status = error.response?.statusCode;
    if (status == null || status < 200 || status >= 300) {
      return false;
    }
    final inner = error.error;
    if (inner is FormatException) {
      return true;
    }
    final message = error.message ?? '';
    if (message.contains('FormatException') ||
        message.contains('Unexpected character')) {
      return true;
    }
    // Unknown + 2xx with a String/null body → treat as success.
    if (error.type == DioExceptionType.unknown) {
      final data = error.response?.data;
      return data == null || data is String;
    }
    return false;
  }

  Map<String, dynamic> _parseMap(Response<Map<String, dynamic>> response) {
    final data = response.data;
    if (data == null) {
      throw ServerException(
        'Empty response body.',
        statusCode: response.statusCode,
      );
    }
    return data;
  }

  ServerException _mapDioError(DioException error) {
    final statusCode = error.response?.statusCode;
    final responseData = error.response?.data;

    if (responseData is Map<String, dynamic>) {
      final message = responseData['message'] ??
          responseData['error'] ??
          responseData['detail'];
      if (message is String && message.isNotEmpty) {
        return ServerException(message, statusCode: statusCode);
      }
    }

    if (responseData is String && responseData.trim().isNotEmpty) {
      if (statusCode != null && statusCode >= 400) {
        return ServerException(responseData, statusCode: statusCode);
      }
    }

    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return ServerException(
        'Unable to reach the server. Check your network or base URL.',
        statusCode: statusCode,
      );
    }

    return ServerException(
      error.message ?? 'Request failed.',
      statusCode: statusCode,
    );
  }
}
