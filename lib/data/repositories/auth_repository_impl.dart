import 'package:brightspeed_fiber_app/core/error/exceptions.dart';
import 'package:brightspeed_fiber_app/core/error/failures.dart';
import 'package:brightspeed_fiber_app/core/utils/result.dart';
import 'package:brightspeed_fiber_app/data/datasources/auth_local_datasource.dart';
import 'package:brightspeed_fiber_app/data/datasources/auth_remote_datasource.dart';
import 'package:brightspeed_fiber_app/domain/entities/auth_session.dart';
import 'package:brightspeed_fiber_app/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required AuthLocalDataSource localDataSource,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource;

  final AuthRemoteDataSource _remoteDataSource;
  final AuthLocalDataSource _localDataSource;

  @override
  Future<Result<AuthSession>> login({
    required String username,
    required String password,
  }) async {
    try {
      final trimmedUsername = username.trim();
      final trimmedPassword = password.trim();

      if (trimmedUsername.isEmpty || trimmedPassword.isEmpty) {
        return const ErrorResult(
          ValidationFailure('Username and password are required.'),
        );
      }

      final response = await _remoteDataSource.login(
        username: trimmedUsername,
        password: trimmedPassword,
      );

      if (response.token.isEmpty) {
        return const ErrorResult(
          ServerFailure('Login succeeded but no token was returned.'),
        );
      }

      final session = response.toEntity();
      await _localDataSource.saveSession(session);
      return Success(session);
    } on ServerException catch (error) {
      return ErrorResult(ServerFailure(error.message));
    } on CacheException catch (error) {
      return ErrorResult(CacheFailure(error.message));
    } catch (_) {
      return const ErrorResult(
        ServerFailure('Unexpected error during login.'),
      );
    }
  }

  @override
  Future<Result<AuthSession?>> getCachedSession() async {
    try {
      final session = await _localDataSource.getSession();
      return Success(session);
    } on CacheException catch (error) {
      return ErrorResult(CacheFailure(error.message));
    } catch (_) {
      return const ErrorResult(
        CacheFailure('Unable to read cached session.'),
      );
    }
  }

  @override
  Future<Result<void>> logout() async {
    try {
      await _localDataSource.clearSession();
      return const Success(null);
    } on CacheException catch (error) {
      return ErrorResult(CacheFailure(error.message));
    } catch (_) {
      return const ErrorResult(CacheFailure('Unable to logout.'));
    }
  }
}
