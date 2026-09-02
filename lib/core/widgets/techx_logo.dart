import 'package:flutter/material.dart';
import 'package:brightspeed_fiber_app/core/theme/app_theme.dart';

/// TechMate wordmark used on auth screens and splash-style headers.
class TechMateLogo extends StatelessWidget {
  const TechMateLogo({super.key, this.fontSize = 36});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'Tech',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w300,
              letterSpacing: -0.5,
              color: Colors.black87,
            ),
          ),
          TextSpan(
            text: 'Mate',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
              color: AppColors.navy,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        24,
        MediaQuery.paddingOf(context).top + 24,
        24,
        40,
      ),
      decoration: const BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: const Column(
        children: [
          TechMateLogo(),
          SizedBox(height: 16),
          Text(
            'Welcome!',
            style: TextStyle(
              fontSize: 22,
              color: AppColors.navy,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
