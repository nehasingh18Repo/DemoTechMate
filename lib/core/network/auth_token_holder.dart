/// Holds the current auth token in memory for Dio interceptors.
class AuthTokenHolder {
  String? _token;

  String? get token => _token;

  void setToken(String? token) => _token = token;

  void clear() => _token = null;
}
