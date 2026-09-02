import 'package:brightspeed_fiber_app/core/utils/result.dart';
import 'package:brightspeed_fiber_app/domain/entities/auth_session.dart';

abstract class AuthRepository {
  Future<Result<AuthSession>> login({
    required String username,
    required String password,
  });

  Future<Result<AuthSession?>> getCachedSession();

  Future<Result<void>> logout();
}
