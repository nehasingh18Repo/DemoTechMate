class StorageKeys {
  StorageKeys._();

  static const String authToken = 'auth_token';
  static const String tokenType = 'token_type';
  static const String expiresIn = 'expires_in';
  static const String username = 'username';
  static const String userId = 'user_id';
  static const String userRole = 'user_role';

  /// Epoch ms when the app last entered background / was left by the user.
  static const String lastAppBackgroundMs = 'last_app_background_ms';
}
