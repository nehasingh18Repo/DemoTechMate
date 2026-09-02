import 'package:flutter/material.dart';
import 'package:brightspeed_fiber_app/core/theme/app_theme.dart';

class JobStatusOption {
  const JobStatusOption({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  static JobStatusOption forLabel(String label) {
    final normalized = label.toLowerCase().replaceAll('_', ' ').trim();

    if (normalized == 'accepted') {
      return const JobStatusOption(label: 'Accepted', color: AppColors.blue);
    }
    if (normalized == 'assigned') {
      return const JobStatusOption(label: 'Assigned', color: AppColors.orange);
    }
    if (normalized == 'en route' || normalized.contains('route')) {
      return const JobStatusOption(label: 'En Route', color: AppColors.purple);
    }
    if (normalized == 'on site' || normalized.contains('site')) {
      return const JobStatusOption(label: 'On Site', color: AppColors.blue);
    }
    if (normalized == 'complete' ||
        (normalized.contains('complete') && !normalized.contains('non'))) {
      return const JobStatusOption(label: 'Complete', color: AppColors.green);
    }
    if (normalized == 'pause' || normalized.contains('pause')) {
      return const JobStatusOption(label: 'Pause', color: AppColors.darkGray);
    }
    if (normalized == 'non complete' ||
        normalized.contains('non complete') ||
        normalized.contains('non_complete')) {
      return const JobStatusOption(label: 'Non Complete', color: AppColors.red);
    }

    return JobStatusOption(label: label, color: AppColors.red);
  }
}
