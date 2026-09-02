import 'package:brightspeed_fiber_app/domain/entities/dashboard_summary.dart';

/// Sample dashboard used when the API is unavailable.
class MockData {
  MockData._();

  static DashboardSummary dashboardSummary = const DashboardSummary(
    asOf: '06-19-2026 08:36 AM',
    technicianStatus: TechnicianStatusSummary(
      notStatused: 5,
      enRoute: 0,
      onSite: 0,
    ),
    attendance: AttendanceSummary(
      scheduled: 0,
      unscheduled: 0,
    ),
    jobStatus: JobStatusSummary(
      totalJobs: 9,
      completed: 7,
      assigned: 0,
      allocated: 0,
      accepted: 0,
      nonComplete: 2,
      assignedAtRisk: 1,
      cancelled: 0,
    ),
    jobReminders: JobRemindersSummary(
      jeopardy: 0,
      missedCommitments: 0,
    ),
  );
}
