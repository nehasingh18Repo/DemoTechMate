import 'package:flutter/material.dart';
import 'package:brightspeed_fiber_app/core/theme/app_theme.dart';
import 'package:brightspeed_fiber_app/domain/entities/dashboard_summary.dart';
import 'package:brightspeed_fiber_app/presentation/widgets/summary_stat_card.dart';

class DashboardSummarySection extends StatelessWidget {
  const DashboardSummarySection({super.key, required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final js = summary.jobStatus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'As of: ${summary.asOf}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ),
        const SizedBox(height: 12),
        _sectionTitle('Technician Status'),
        Row(
          children: [
            SummaryStatCard(
              icon: Icons.person_outline,
              count: summary.technicianStatus.notStatused,
              label: 'Not Statused',
              color: AppColors.orange,
            ),
            const SizedBox(width: 8),
            SummaryStatCard(
              icon: Icons.local_shipping_outlined,
              count: summary.technicianStatus.enRoute,
              label: 'En Route',
              color: AppColors.purple,
            ),
            const SizedBox(width: 8),
            SummaryStatCard(
              icon: Icons.home_outlined,
              count: summary.technicianStatus.onSite,
              label: 'On Site',
              color: AppColors.blue,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _sectionTitle('Attendance'),
        Row(
          children: [
            SummaryStatCard(
              icon: Icons.event_available,
              count: summary.attendance.scheduled,
              label: 'Scheduled',
              color: AppColors.green,
            ),
            const SizedBox(width: 8),
            SummaryStatCard(
              icon: Icons.event_busy,
              count: summary.attendance.unscheduled,
              label: 'Unscheduled',
              color: AppColors.red,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _sectionTitle('Job Status')),
            Text(
              'Total Jobs: ${js.totalJobs}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  JobStatusRow(label: 'Completed', count: js.completed, total: js.totalJobs),
                  JobStatusRow(label: 'Assigned', count: js.assigned, total: js.totalJobs),
                  JobStatusRow(label: 'Allocated', count: js.allocated, total: js.totalJobs),
                  JobStatusRow(label: 'Accepted', count: js.accepted, total: js.totalJobs),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                children: [
                  JobStatusRow(label: 'Non Complete', count: js.nonComplete, total: js.totalJobs),
                  JobStatusRow(
                    label: 'Assigned At Risk',
                    count: js.assignedAtRisk,
                    total: js.totalJobs,
                  ),
                  JobStatusRow(label: 'Cancelled', count: js.cancelled, total: js.totalJobs),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _sectionTitle('Job Reminders'),
        Row(
          children: [
            ReminderChip(
              label: 'Jeopardy',
              count: summary.jobReminders.jeopardy,
            ),
            ReminderChip(
              label: 'Missed Commitments',
              count: summary.jobReminders.missedCommitments,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text(
                      'Tech Capacity Viewer',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Text(
                      'Next Day >>',
                      style: TextStyle(color: AppColors.blue, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'No Data Available',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
