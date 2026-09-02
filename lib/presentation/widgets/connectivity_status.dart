import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:brightspeed_fiber_app/core/network/connectivity_status_service.dart';
import 'package:brightspeed_fiber_app/core/sync/jobs_sync_service.dart';
import 'package:brightspeed_fiber_app/core/theme/app_theme.dart';

/// Header pill: green when the app is online, red when it is offline.
class ConnectivityStatusChip extends StatelessWidget {
  const ConnectivityStatusChip({super.key});

  @override
  Widget build(BuildContext context) {
    final isOnline = context.watch<ConnectivityStatusService>().isOnline;
    final color = isOnline ? AppColors.green : AppColors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isOnline ? 'Online' : 'Offline',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Yellow status box pinned above the bottom navigation bar.
class ConnectivityStatusBanner extends StatelessWidget {
  const ConnectivityStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final isOnline = context.watch<ConnectivityStatusService>().isOnline;
    final syncService = context.watch<JobsSyncService>();
    final combinedState = _worseState(
      syncService.state,
      syncService.locationState,
    );
    final statusColor = switch (combinedState) {
      JobsSyncState.failed => AppColors.red,
      JobsSyncState.syncing => AppColors.blue,
      JobsSyncState.queued => AppColors.orange,
      JobsSyncState.success => AppColors.green,
      JobsSyncState.idle => isOnline ? AppColors.green : AppColors.red,
    };
    final parts = <String>[
      if (syncService.message != null &&
          syncService.state != JobsSyncState.idle)
        syncService.message!,
      if (syncService.locationMessage != null &&
          syncService.locationState != JobsSyncState.idle)
        syncService.locationMessage!,
    ];
    final text = parts.isEmpty
        ? (isOnline ? 'You are online' : 'You are offline')
        : parts.join(' • ');
    final icon = switch (combinedState) {
      JobsSyncState.failed => Icons.sync_problem,
      JobsSyncState.syncing => Icons.sync,
      JobsSyncState.queued => Icons.schedule,
      JobsSyncState.success => Icons.cloud_done,
      JobsSyncState.idle => isOnline ? Icons.wifi : Icons.wifi_off,
    };

    return Container(
      width: double.infinity,
      color: AppColors.warmYellow,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 16,
            color: statusColor,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

JobsSyncState _worseState(JobsSyncState a, JobsSyncState b) {
  int rank(JobsSyncState state) => switch (state) {
        JobsSyncState.failed => 4,
        JobsSyncState.syncing => 3,
        JobsSyncState.queued => 2,
        JobsSyncState.success => 1,
        JobsSyncState.idle => 0,
      };
  return rank(a) >= rank(b) ? a : b;
}
