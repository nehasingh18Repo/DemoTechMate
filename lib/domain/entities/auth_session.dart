import 'package:equatable/equatable.dart';

class AuthSession extends Equatable {
  const AuthSession({
    required this.token,
    required this.tokenType,
    required this.expiresIn,
    required this.username,
    required this.role,
    required this.id,
  });

  final String token;
  final String tokenType;
  final int expiresIn;
  final String username;
  final String role;
  final int id;

  /// Backward-compatible alias used by jobs API.
  int get userId => id;

  @override
  List<Object?> get props => [token, tokenType, expiresIn, username, role, id];
}
