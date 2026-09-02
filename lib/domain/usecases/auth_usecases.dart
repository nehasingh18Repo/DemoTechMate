import 'package:brightspeed_fiber_app/core/utils/result.dart';
import 'package:brightspeed_fiber_app/domain/entities/auth_session.dart';
import 'package:brightspeed_fiber_app/domain/repositories/auth_repository.dart';

class LoginUseCase {
  const LoginUseCase(this._repository);

  final AuthRepository _repository;

  Future<Result<AuthSession>> call({
    required String username,
    required String password,
  }) {
    return _repository.login(username: username, password: password);
  }
}

class LogoutUseCase {
  const LogoutUseCase(this._repository);

  final AuthRepository _repository;

  Future<Result<void>> call() => _repository.logout();
}

class GetCachedSessionUseCase {
  const GetCachedSessionUseCase(this._repository);

  final AuthRepository _repository;

  Future<Result<AuthSession?>> call() => _repository.getCachedSession();
}
