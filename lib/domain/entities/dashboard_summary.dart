import 'package:equatable/equatable.dart';

class DashboardSummary extends Equatable {
  const DashboardSummary({
    required this.asOf,
    required this.technicianStatus,
    required this.attendance,
    required this.jobStatus,
    required this.jobReminders,
  });

  final String asOf;
  final TechnicianStatusSummary technicianStatus;
  final AttendanceSummary attendance;
  final JobStatusSummary jobStatus;
  final JobRemindersSummary jobReminders;

  @override
  List<Object?> get props =>
      [asOf, technicianStatus, attendance, jobStatus, jobReminders];
}

class TechnicianStatusSummary extends Equatable {
  const TechnicianStatusSummary({
    required this.notStatused,
    required this.enRoute,
    required this.onSite,
  });

  final int notStatused;
  final int enRoute;
  final int onSite;

  @override
  List<Object?> get props => [notStatused, enRoute, onSite];
}

class AttendanceSummary extends Equatable {
  const AttendanceSummary({
    required this.scheduled,
    required this.unscheduled,
  });

  final int scheduled;
  final int unscheduled;

  @override
  List<Object?> get props => [scheduled, unscheduled];
}

class JobStatusSummary extends Equatable {
  const JobStatusSummary({
    required this.totalJobs,
    required this.completed,
    required this.assigned,
    required this.allocated,
    required this.accepted,
    required this.nonComplete,
    required this.assignedAtRisk,
    required this.cancelled,
  });

  final int totalJobs;
  final int completed;
  final int assigned;
  final int allocated;
  final int accepted;
  final int nonComplete;
  final int assignedAtRisk;
  final int cancelled;

  @override
  List<Object?> get props => [
        totalJobs,
        completed,
        assigned,
        allocated,
        accepted,
        nonComplete,
        assignedAtRisk,
        cancelled,
      ];
}

class JobRemindersSummary extends Equatable {
  const JobRemindersSummary({
    required this.jeopardy,
    required this.missedCommitments,
  });

  final int jeopardy;
  final int missedCommitments;

  @override
  List<Object?> get props => [jeopardy, missedCommitments];
}
