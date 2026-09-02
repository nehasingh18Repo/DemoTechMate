class ApiConstants {
  ApiConstants._();

  static const String login = '/api/auth/login';
  static const String dashboardSummary = '/api/dashboard/summary';
  static const String userJobs = '/api/jobs/user';
  /// PATCH /api/jobs/{jobId} — request body includes `version` from [userJobs].
  /// After each successful update, increment `version` by 1 for the next request.
  static const String jobById = '/api/jobs';
  static const String jobsSync = '/api/jobs/sync';
  static const String fcmRegister = '/api/fcm/register';

  /// POST /api/location/user/{userId} — periodic technician location sync.
  static const String locationUserUpdate = '/api/location/user';

  /// GET /features/{userId}
  static const String featureFlags = '/api/features';

  /// Legacy alias kept for older call sites.
  static const String locationUpdate = locationUserUpdate;
}
