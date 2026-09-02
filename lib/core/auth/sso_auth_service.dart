// class SsoAuthService {
//   Future<String?> login() async {
//     // Microsoft login
//     // token receive
//     // return token
//   }

//   Future<void> logout() async {
//     // Microsoft logout
//   }
// }

// ElevatedButton(
//   onPressed: () {
//     context.read<AuthCubit>().loginWithSso();
//   },
//   child: const Text('Sign in with SSO'),
// )

// Future<void> loginWithSso() async {
//   emit(AuthLoading());

//   try {
//     final token = await ssoAuthService.login();

//     if (token != null) {
//       emit(AuthSuccess(token));
//     } else {
//       emit(AuthFailure('Login cancelled'));
//     }
//   } catch (e) {
//     emit(AuthFailure(e.toString()));
//   }
// }