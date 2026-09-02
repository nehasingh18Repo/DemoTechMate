import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:brightspeed_fiber_app/core/location/location_tracking_service.dart';
import 'package:brightspeed_fiber_app/core/notifications/fcm_service.dart';
import 'package:brightspeed_fiber_app/core/sync/jobs_sync_service.dart';
import 'package:brightspeed_fiber_app/core/utils/result.dart';
import 'package:brightspeed_fiber_app/domain/usecases/auth_usecases.dart';
import 'package:brightspeed_fiber_app/presentation/auth/cubit/auth_state.dart';
import 'package:brightspeed_fiber_app/presentation/feature_flags/cubit/feature_flag_cubit.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({
    required LoginUseCase loginUseCase,
    required LogoutUseCase logoutUseCase,
    required GetCachedSessionUseCase getCachedSessionUseCase,
    required FcmService fcmService,
    required LocationTrackingService locationTrackingService,
    required JobsSyncService jobsSyncService,
    required FeatureFlagCubit featureFlagCubit,
  })  : _loginUseCase = loginUseCase,
        _logoutUseCase = logoutUseCase,
        _getCachedSessionUseCase = getCachedSessionUseCase,
        _fcmService = fcmService,
        _locationTrackingService = locationTrackingService,
        _jobsSyncService = jobsSyncService,
        _featureFlagCubit = featureFlagCubit,
        super(const AuthState());

  final LoginUseCase _loginUseCase;
  final LogoutUseCase _logoutUseCase;
  final GetCachedSessionUseCase _getCachedSessionUseCase;
  final FcmService _fcmService;
  final LocationTrackingService _locationTrackingService;
  final JobsSyncService _jobsSyncService;
  final FeatureFlagCubit _featureFlagCubit;

  Future<void> checkSession() async {
    emit(state.copyWith(status: AuthStatus.loading, clearError: true));
    final result = await _getCachedSessionUseCase();
    switch (result) {
      case Success(:final data):
        if (data != null) {
          emit(
            state.copyWith(
              status: AuthStatus.authenticated,
              session: data,
              clearError: true,
            ),
          );
          // Keep server FCM mapping in sync when restoring a session.
          unawaited(_fcmService.registerForUser(data.userId));
          debugPrint(
            'AUTH: Starting location tracking from checkSession userId=${data.userId}',
          );
          unawaited(_locationTrackingService.start(data.userId));
          unawaited(_featureFlagCubit.load(userId: data.userId));
        } else {
          emit(
            state.copyWith(
              status: AuthStatus.unauthenticated,
              clearError: true,
            ),
          );
        }
      case ErrorResult(:final failure):
        emit(
          state.copyWith(
            status: AuthStatus.unauthenticated,
            errorMessage: failure.message,
          ),
        );
    }
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    final result = await _loginUseCase(username: username, password: password);
    switch (result) {
      case Success(:final data):
        emit(
          state.copyWith(
            status: AuthStatus.authenticated,
            session: data,
            isSubmitting: false,
            loginSuccessMessage: 'Login successfully',
            clearError: true,
          ),
        );
        // POST /api/fcm/register after successful login.
        unawaited(_fcmService.registerForUser(data.userId));
        // Start 5-minute location sync using persisted userId + JWT.
        unawaited(_locationTrackingService.start(data.userId));
        // ADD THIS
        debugPrint(
            'AUTH: Starting location tracking for userId=${data.userId}');
        // GET /features/{userId} using the id returned by login.
        unawaited(_featureFlagCubit.load(userId: data.userId));
      case ErrorResult(:final failure):
        emit(
          state.copyWith(
            status: AuthStatus.unauthenticated,
            isSubmitting: false,
            errorMessage: failure.message,
          ),
        );
    }
  }

  Future<void> logout() async {
    _jobsSyncService.stop();
    await _locationTrackingService.stop();

    final result = await _logoutUseCase();
    switch (result) {
      case Success():
        _featureFlagCubit.reset();
        emit(const AuthState(status: AuthStatus.unauthenticated));
      case ErrorResult(:final failure):
        emit(state.copyWith(errorMessage: failure.message));
    }
  }

  void clearError() {
    emit(state.copyWith(clearError: true));
  }

  void clearLoginSuccessMessage() {
    emit(state.copyWith(clearLoginSuccess: true));
  }
}
