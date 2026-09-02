import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:brightspeed_fiber_app/data/mock/demo_user.dart';
import 'package:brightspeed_fiber_app/presentation/auth/cubit/auth_cubit.dart';
import 'package:brightspeed_fiber_app/presentation/auth/cubit/auth_state.dart';
import 'package:brightspeed_fiber_app/presentation/home/pages/home_page.dart';
import 'package:brightspeed_fiber_app/presentation/widgets/app_header.dart';

class PasswordPage extends StatefulWidget {
  const PasswordPage({super.key, required this.username});

  static const routeName = '/password';

  final String username;

  @override
  State<PasswordPage> createState() => _PasswordPageState();
}

class _PasswordPageState extends State<PasswordPage> {
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _passwordController.text = DemoUser.password;
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your password.')),
      );
      return;
    }

    await context.read<AuthCubit>().login(
          username: widget.username,
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state.status == AuthStatus.authenticated) {
          if (state.loginSuccessMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.loginSuccessMessage!)),
            );
            context.read<AuthCubit>().clearLoginSuccessMessage();
          }
          Navigator.of(context).pushNamedAndRemoveUntil(
            HomePage.routeName,
            (_) => false,
          );
          return;
        }

        if (state.errorMessage != null && !state.isSubmitting) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
          context.read<AuthCubit>().clearError();
        }
      },
      builder: (context, state) {
        final isLoading = state.isSubmitting;

        return AuthScreenBody(
          child: Column(
            children: [
              const SizedBox(height: 24),
              const AuthProfileIcon(icon: Icons.verified_user_outlined),
              const SizedBox(height: 12),
              Text(
                'Enter your password to login',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              Text(
                'API: POST /api/auth/login',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(Icons.person_outline, color: Colors.grey.shade500),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.username,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Password',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.lock_outline, color: Colors.grey.shade500),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  hintText: 'Enter password',
                ),
                onSubmitted: (_) => _login(),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isLoading ? null : _login,
                  child: isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Login'),
                ),
              ),
              const SizedBox(height: 32),
              const AuthAlternativeSignIn(),
            ],
          ),
        );
      },
    );
  }
}
