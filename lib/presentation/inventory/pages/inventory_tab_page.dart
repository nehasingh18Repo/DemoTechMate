import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:brightspeed_fiber_app/core/theme/app_theme.dart';
import 'package:brightspeed_fiber_app/presentation/auth/cubit/auth_cubit.dart';
import 'package:brightspeed_fiber_app/presentation/inventory/cubit/inventory_cubit.dart';
import 'package:brightspeed_fiber_app/presentation/inventory/cubit/inventory_state.dart';

class InventoryTabPage extends StatelessWidget {
  const InventoryTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<InventoryCubit, InventoryState>(
      listenWhen: (previous, current) =>
          previous.message != current.message ||
          previous.errorMessage != current.errorMessage,
      listener: (context, state) {
        final text = state.message ?? state.errorMessage;
        if (text == null) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
        context.read<InventoryCubit>().clearFeedback();
      },
      builder: (context, state) {
        final location = state.location;
        final isLoading = state.status == InventoryStatus.loading;

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'My Inventory',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Opens with device GPS and sends location + timestamp to '
                'POST /api/location/user/{userId}. Every 5 minutes while signed in: '
                'online → single API; offline → local DB, then batch API when back online.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.my_location, color: AppColors.blue),
                        const SizedBox(width: 8),
                        const Text(
                          'Current location',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (location != null) ...[
                      _coordRow('Latitude', location.latitude.toStringAsFixed(6)),
                      const SizedBox(height: 8),
                      _coordRow('Longitude', location.longitude.toStringAsFixed(6)),
                      const SizedBox(height: 8),
                      _coordRow('Timestamp', location.dateTimeUtc),
                    ] else
                      Text(
                        'Tap refresh to capture GPS coordinates.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: isLoading
                    ? null
                    : () {
                        final session =
                            context.read<AuthCubit>().state.session;
                        if (session == null) {
                          return;
                        }
                        context
                            .read<InventoryCubit>()
                            .captureAndSendLocation(session.userId);
                      },
                icon: const Icon(Icons.gps_fixed),
                label: Text(
                  isLoading ? 'Getting location...' : 'Refresh & send location',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _coordRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade700)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}
