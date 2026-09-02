import 'package:brightspeed_fiber_app/core/utils/result.dart';
import 'package:brightspeed_fiber_app/domain/entities/job.dart';
import 'package:brightspeed_fiber_app/domain/repositories/jobs_repository.dart';

class GetUserJobsUseCase {
  const GetUserJobsUseCase(this._repository);

  final JobsRepository _repository;

  Future<Result<List<Job>>> call(
    int userId, {
    required bool isOnline,
    bool forceRemoteFetch = false,
    bool flushLocalStatusAfterFetch = false,
  }) =>
      _repository.getJobsForUser(
        userId,
        isOnline: isOnline,
        forceRemoteFetch: forceRemoteFetch,
        flushLocalStatusAfterFetch: flushLocalStatusAfterFetch,
      );
}

class RefreshJobStatusOnResumeUseCase {
  const RefreshJobStatusOnResumeUseCase(this._repository);

  final JobsRepository _repository;

  Future<Result<List<Job>>> call(
    int userId, {
    required bool isOnline,
    bool preferLocalStatus = false,
  }) {
    return _repository.refreshJobStatusOnResume(
      userId,
      isOnline: isOnline,
      preferLocalStatus: preferLocalStatus,
    );
  }
}

class UpdateJobStatusUseCase {
  const UpdateJobStatusUseCase(this._repository);

  final JobsRepository _repository;

  Future<Result<bool>> call({
    required int userId,
    required Job job,
    required String status,
    required bool createdOffline,
  }) {
    return _repository.updateJobStatus(
      userId: userId,
      job: job,
      status: status,
      createdOffline: createdOffline,
    );
  }
}
