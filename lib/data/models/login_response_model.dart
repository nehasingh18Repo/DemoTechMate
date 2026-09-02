import 'package:brightspeed_fiber_app/domain/entities/auth_session.dart';

class LoginResponseModel {
  const LoginResponseModel({
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

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) {
    final rawUserId = json['id'] ?? json['userId'];
    final parsedId = switch (rawUserId) {
      final num n => n.toInt(),
      final String s => int.tryParse(s),
      _ => null,
    };

    return LoginResponseModel(
      token: json['token'] as String? ?? json['authToken'] as String? ?? '',
      tokenType: json['tokenType'] as String? ?? 'Bearer',
      expiresIn: (json['expiresIn'] as num?)?.toInt() ?? 0,
      username: json['username'] as String? ?? '',
      role: json['role'] as String? ?? '',
      id: parsedId ?? 3,
    );
  }

  AuthSession toEntity() {
    return AuthSession(
      token: token,
      tokenType: tokenType,
      expiresIn: expiresIn,
      username: username,
      role: role,
      id: id == 0 ? 3 : id,
    );
  }
}
