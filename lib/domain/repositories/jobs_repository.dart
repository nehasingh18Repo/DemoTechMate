import 'package:brightspeed_fiber_app/core/utils/result.dart';
import 'package:brightspeed_fiber_app/domain/entities/job.dart';

abstract class JobsRepository {
  Future<Result<List<Job>>> getJobsForUser(
    int userId, {
    required bool isOnline,
    bool forceRemoteFetch = false,
    bool flushLocalStatusAfterFetch = false,
  });

  /// Refreshes job status when the app returns to the foreground.
  ///
  /// Online: returns live API jobs with server status.
  /// Offline: returns cached job details with DB status when available,
  /// otherwise the cached API status.
  Future<Result<List<Job>>> refreshJobStatusOnResume(
    int userId, {
    required bool isOnline,
    bool preferLocalStatus = false,
  });

  Future<Result<bool>> updateJobStatus({
    required int userId,
    required Job job,
    required String status,
    required bool createdOffline,
  });
}
