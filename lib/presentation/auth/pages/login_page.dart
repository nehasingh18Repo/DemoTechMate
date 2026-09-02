import 'package:flutter/material.dart';
import 'package:brightspeed_fiber_app/data/mock/demo_user.dart';
import 'package:brightspeed_fiber_app/presentation/auth/pages/password_page.dart';
import 'package:brightspeed_fiber_app/presentation/widgets/app_header.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  static const routeName = '/login';

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _usernameController.text = DemoUser.username;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  void _onProceed() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pushNamed(
      PasswordPage.routeName,
      arguments: _usernameController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScreenBody(
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            const SizedBox(height: 24),
            const AuthProfileIcon(),
            const SizedBox(height: 16),
            Text(
              'Please enter your username to proceed',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'API: POST /api/auth/login',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 4),
            Text(
              'User: ${DemoUser.username}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _usernameController,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.email_outlined, color: Colors.grey.shade500),
                labelText: 'Username',
                hintText: 'Email / Username',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Username is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _onProceed,
                child: const Text(
                  'Proceed',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const AuthAlternativeSignIn(),
          ],
        ),
      ),
    );
  }
}
