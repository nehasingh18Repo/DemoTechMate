enum JobOutboxStatus { pending, processing, success, failed }

class JobOutboxEvent {
  const JobOutboxEvent({
    required this.id,
    required this.transactionId,
    required this.userId,
    required this.jobId,
    required this.status,
    required this.version,
    required this.createdAtMs,
    required this.syncStatus,
    required this.retryCount,
    this.lastError,
    this.createdOffline = true,
  });

  final int id;
  final String transactionId;
  final int userId;
  final int jobId;
  final String status;
  final int version;
  final int createdAtMs;
  final JobOutboxStatus syncStatus;
  final int retryCount;
  final String? lastError;

  /// True when the technician made this change while the app was offline.
  /// Only these events are sent to POST /api/jobs/sync.
  final bool createdOffline;

  Map<String, dynamic> toApiJson() {
    return {
      'transactionId': transactionId,
      'jobId': jobId,
      'status': status,
      'version': version < 1 ? 1 : version,
    };
  }
}
