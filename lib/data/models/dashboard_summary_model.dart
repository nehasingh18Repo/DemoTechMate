import 'package:brightspeed_fiber_app/domain/entities/dashboard_summary.dart';

class DashboardSummaryModel {
  const DashboardSummaryModel({
    required this.asOf,
    required this.technicianStatus,
    required this.attendance,
    required this.jobStatus,
    required this.jobReminders,
  });

  final String asOf;
  final TechnicianStatusModel technicianStatus;
  final AttendanceModel attendance;
  final JobStatusSummaryModel jobStatus;
  final JobRemindersModel jobReminders;

  factory DashboardSummaryModel.fromJson(Map<String, dynamic> json) {
    return DashboardSummaryModel(
      asOf: json['asOf'] as String? ?? '',
      technicianStatus: TechnicianStatusModel.fromJson(
        json['technicianStatus'] as Map<String, dynamic>? ?? {},
      ),
      attendance: AttendanceModel.fromJson(
        json['attendance'] as Map<String, dynamic>? ?? {},
      ),
      jobStatus: JobStatusSummaryModel.fromJson(
        json['jobStatus'] as Map<String, dynamic>? ?? {},
      ),
      jobReminders: JobRemindersModel.fromJson(
        json['jobReminders'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  DashboardSummary toEntity() {
    return DashboardSummary(
      asOf: asOf,
      technicianStatus: technicianStatus.toEntity(),
      attendance: attendance.toEntity(),
      jobStatus: jobStatus.toEntity(),
      jobReminders: jobReminders.toEntity(),
    );
  }
}

class TechnicianStatusModel {
  const TechnicianStatusModel({
    required this.notStatused,
    required this.enRoute,
    required this.onSite,
  });

  final int notStatused;
  final int enRoute;
  final int onSite;

  factory TechnicianStatusModel.fromJson(Map<String, dynamic> json) {
    return TechnicianStatusModel(
      notStatused: (json['notStatused'] as num?)?.toInt() ?? 0,
      enRoute: (json['enRoute'] as num?)?.toInt() ?? 0,
      onSite: (json['onSite'] as num?)?.toInt() ?? 0,
    );
  }

  TechnicianStatusSummary toEntity() {
    return TechnicianStatusSummary(
      notStatused: notStatused,
      enRoute: enRoute,
      onSite: onSite,
    );
  }
}

class AttendanceModel {
  const AttendanceModel({
    required this.scheduled,
    required this.unscheduled,
  });

  final int scheduled;
  final int unscheduled;

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      scheduled: (json['scheduled'] as num?)?.toInt() ?? 0,
      unscheduled: (json['unscheduled'] as num?)?.toInt() ?? 0,
    );
  }

  AttendanceSummary toEntity() {
    return AttendanceSummary(
      scheduled: scheduled,
      unscheduled: unscheduled,
    );
  }
}

class JobStatusSummaryModel {
  const JobStatusSummaryModel({
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

  factory JobStatusSummaryModel.fromJson(Map<String, dynamic> json) {
    return JobStatusSummaryModel(
      totalJobs: (json['totalJobs'] as num?)?.toInt() ?? 0,
      completed: (json['completed'] as num?)?.toInt() ?? 0,
      assigned: (json['assigned'] as num?)?.toInt() ?? 0,
      allocated: (json['allocated'] as num?)?.toInt() ?? 0,
      accepted: (json['accepted'] as num?)?.toInt() ?? 0,
      nonComplete: (json['nonComplete'] as num?)?.toInt() ?? 0,
      assignedAtRisk: (json['assignedAtRisk'] as num?)?.toInt() ?? 0,
      cancelled: (json['cancelled'] as num?)?.toInt() ?? 0,
    );
  }

  JobStatusSummary toEntity() {
    return JobStatusSummary(
      totalJobs: totalJobs,
      completed: completed,
      assigned: assigned,
      allocated: allocated,
      accepted: accepted,
      nonComplete: nonComplete,
      assignedAtRisk: assignedAtRisk,
      cancelled: cancelled,
    );
  }
}

class JobRemindersModel {
  const JobRemindersModel({
    required this.jeopardy,
    required this.missedCommitments,
  });

  final int jeopardy;
  final int missedCommitments;

  factory JobRemindersModel.fromJson(Map<String, dynamic> json) {
    return JobRemindersModel(
      jeopardy: (json['jeopardy'] as num?)?.toInt() ?? 0,
      missedCommitments: (json['missedCommitments'] as num?)?.toInt() ?? 0,
    );
  }

  JobRemindersSummary toEntity() {
    return JobRemindersSummary(
      jeopardy: jeopardy,
      missedCommitments: missedCommitments,
    );
  }
}
