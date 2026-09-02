import 'package:flutter/material.dart';
import 'package:brightspeed_fiber_app/core/theme/app_theme.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message = 'Loading...'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.navy),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}

class LoadingPlaceholder extends StatelessWidget {
  const LoadingPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (_, __) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Container(
          height: 120,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 14,
                width: 180,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 12),
              Container(
                height: 12,
                width: double.infinity,
                color: Colors.grey.shade200,
              ),
              const SizedBox(height: 8),
              Container(
                height: 12,
                width: 240,
                color: Colors.grey.shade200,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
