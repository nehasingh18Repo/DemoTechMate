import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:brightspeed_fiber_app/core/constants/storage_keys.dart';
import 'package:brightspeed_fiber_app/core/error/exceptions.dart';
import 'package:brightspeed_fiber_app/core/network/auth_token_holder.dart';
import 'package:brightspeed_fiber_app/domain/entities/auth_session.dart';

class AuthLocalDataSource {
  AuthLocalDataSource({
    required FlutterSecureStorage secureStorage,
    required SharedPreferences sharedPreferences,
    required AuthTokenHolder tokenHolder,
  })  : _secureStorage = secureStorage,
        _prefs = sharedPreferences,
        _tokenHolder = tokenHolder;

  final FlutterSecureStorage _secureStorage;
  final SharedPreferences _prefs;
  final AuthTokenHolder _tokenHolder;

  Future<void> saveSession(AuthSession session) async {
    try {
      await _secureStorage.write(key: StorageKeys.authToken, value: session.token);
      await _prefs.setString(StorageKeys.tokenType, session.tokenType);
      await _prefs.setInt(StorageKeys.expiresIn, session.expiresIn);
      await _prefs.setString(StorageKeys.username, session.username);
      await _prefs.setInt(StorageKeys.userId, session.id);
      await _prefs.setString(StorageKeys.userRole, session.role);
      _tokenHolder.setToken(session.token);
    } catch (_) {
      throw const CacheException('Failed to persist session.');
    }
  }

  Future<AuthSession?> getSession() async {
    try {
      final token = await _secureStorage.read(key: StorageKeys.authToken);
      final tokenType = _prefs.getString(StorageKeys.tokenType);
      final expiresIn = _prefs.getInt(StorageKeys.expiresIn);
      final username = _prefs.getString(StorageKeys.username);
      final userId = _prefs.getInt(StorageKeys.userId);
      final role = _prefs.getString(StorageKeys.userRole);

      if (token == null ||
          tokenType == null ||
          expiresIn == null ||
          username == null ||
          userId == null ||
          role == null) {
        return null;
      }

      _tokenHolder.setToken(token);
      return AuthSession(
        token: token,
        tokenType: tokenType,
        expiresIn: expiresIn,
        username: username,
        role: role,
        id: userId,
      );
    } catch (_) {
      throw const CacheException('Failed to read cached session.');
    }
  }

  Future<void> clearSession() async {
    try {
      await _secureStorage.delete(key: StorageKeys.authToken);
      await _prefs.remove(StorageKeys.tokenType);
      await _prefs.remove(StorageKeys.expiresIn);
      await _prefs.remove(StorageKeys.username);
      await _prefs.remove(StorageKeys.userId);
      await _prefs.remove(StorageKeys.userRole);
   _tokenHolder.clear();
    } catch (_) {
      throw const CacheException('Failed to clear session.');
    }
  }
}
