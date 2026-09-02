import 'package:equatable/equatable.dart';
import 'package:brightspeed_fiber_app/domain/entities/auth_session.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated }

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.initial,
    this.session,
    this.isSubmitting = false,
    this.errorMessage,
    this.loginSuccessMessage,
  });

  final AuthStatus status;
  final AuthSession? session;
  final bool isSubmitting;
  final String? errorMessage;
  final String? loginSuccessMessage;

  AuthState copyWith({
    AuthStatus? status,
    AuthSession? session,
    bool? isSubmitting,
    String? errorMessage,
    String? loginSuccessMessage,
    bool clearError = false,
    bool clearLoginSuccess = false,
    bool clearSession = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      session: clearSession ? null : (session ?? this.session),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      loginSuccessMessage: clearLoginSuccess
          ? null
          : (loginSuccessMessage ?? this.loginSuccessMessage),
    );
  }

  @override
  List<Object?> get props =>
      [status, session, isSubmitting, errorMessage, loginSuccessMessage];
}
