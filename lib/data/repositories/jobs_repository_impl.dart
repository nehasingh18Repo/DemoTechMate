import 'package:brightspeed_fiber_app/core/error/exceptions.dart';
import 'package:brightspeed_fiber_app/core/error/failures.dart';
import 'package:brightspeed_fiber_app/core/utils/job_status_mapper.dart';
import 'package:brightspeed_fiber_app/core/utils/result.dart';
import 'package:brightspeed_fiber_app/data/datasources/jobs_local_datasource.dart';
import 'package:brightspeed_fiber_app/data/datasources/jobs_remote_datasource.dart';
import 'package:brightspeed_fiber_app/domain/entities/job.dart';
import 'package:brightspeed_fiber_app/domain/repositories/jobs_repository.dart';
import 'package:uuid/uuid.dart';

class JobsRepositoryImpl implements JobsRepository {
  JobsRepositoryImpl({
    required JobsRemoteDataSource remoteDataSource,
    required JobsLocalDataSource localDataSource,
    Uuid? uuid,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource,
        _uuid = uuid ?? const Uuid();

  final JobsRemoteDataSource _remoteDataSource;
  final JobsLocalDataSource _localDataSource;
  final Uuid _uuid;

  @override
  Future<Result<List<Job>>> getJobsForUser(
    int userId, {
    required bool isOnline,
    bool forceRemoteFetch = false,
    bool flushLocalStatusAfterFetch = false,
  }) async {
    if (!forceRemoteFetch && !isOnline) {
      try {
        final local = await _loadOfflineResumeJobs(userId);
        if (local.isNotEmpty) {
          return Success(local);
        }
        return const ErrorResult(
          CacheFailure('No cached jobs available while offline'),
        );
      } catch (error) {
        return ErrorResult(CacheFailure('Unable to load cached jobs: $error'));
      }
    }

    return _fetchJobsFromApi(
      userId,
      flushLocalStatusAfterFetch: flushLocalStatusAfterFetch,
    );
  }

  Future<Result<List<Job>>> _fetchJobsFromApi(
    int userId, {
    required bool flushLocalStatusAfterFetch,
  }) async {
    try {
      final models = await _remoteDataSource.fetchJobsForUser(userId);
      if (flushLocalStatusAfterFetch) {
        await _localDataSource.applyServerJobsAndFlushSyncedStatusData(
          userId,
          models,
        );
        return Success(models.map((m) => m.toEntity()).toList());
      }

      await _localDataSource.cacheJobs(userId, models);
      final pending = await _localDataSource.pendingCount(userId);
      if (pending > 0) {
        final local = await _loadOfflineResumeJobs(userId);
        if (local.isNotEmpty) {
          return Success(local);
        }
      }
      return Success(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (error) {
      final local = await _loadOfflineResumeJobs(userId);
      if (local.isNotEmpty) {
        return Success(local);
      }
      return ErrorResult(ServerFailure(error.message));
    } catch (error) {
      final local = await _loadOfflineResumeJobs(userId);
      if (local.isNotEmpty) {
        return Success(local);
      }
      return ErrorResult(CacheFailure('Unable to load cached jobs: $error'));
    }
  }

  @override
  Future<Result<List<Job>>> refreshJobStatusOnResume(
    int userId, {
    required bool isOnline,
    bool preferLocalStatus = false,
  }) async {
    if (!preferLocalStatus && isOnline) {
      try {
        final models = await _remoteDataSource.fetchJobsForUser(userId);
        await _localDataSource.applyServerJobsAndFlushSyncedStatusData(
          userId,
          models,
        );
        return Success(models.map((m) => m.toEntity()).toList());
      } on ServerException catch (error) {
        final local = await _loadOfflineResumeJobs(userId);
        if (local.isNotEmpty) {
          return Success(local);
        }
        return ErrorResult(ServerFailure(error.message));
      } catch (error) {
        final local = await _loadOfflineResumeJobs(userId);
        if (local.isNotEmpty) {
          return Success(local);
        }
        return ErrorResult(CacheFailure('Unable to refresh job status: $error'));
      }
    }

    try {
      final local = await _loadOfflineResumeJobs(userId);
      if (local.isNotEmpty) {
        return Success(local);
      }
      return const ErrorResult(
        CacheFailure('No cached jobs available while offline'),
      );
    } catch (error) {
      return ErrorResult(CacheFailure('Unable to refresh job status: $error'));
    }
  }

  Future<List<Job>> _loadOfflineResumeJobs(int userId) async {
    final models =
        await _localDataSource.getJobsWithResolvedStatusForOffline(userId);
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<Result<bool>> updateJobStatus({
    required int userId,
    required Job job,
    required String status,
    required bool createdOffline,
  }) async {
    final apiStatus = JobStatusMapper.toApi(
      JobStatusMapper.toDisplay(status),
    );

    try {
      final inserted = await _localDataSource.enqueueStatusUpdate(
        userId: userId,
        job: job,
        apiStatus: apiStatus,
        transactionId: _uuid.v4(),
        createdOffline: createdOffline,
      );
      return Success(inserted);
    } catch (error) {
      final text = error.toString();
      if (text.toLowerCase().contains('unique')) {
        try {
          final inserted = await _localDataSource.enqueueStatusUpdate(
            userId: userId,
            job: job,
            apiStatus: apiStatus,
            transactionId: _uuid.v4(),
            createdOffline: createdOffline,
          );
          return Success(inserted);
        } catch (retryError) {
          return ErrorResult(
            CacheFailure('Unable to save the job status locally: $retryError'),
          );
        }
      }
      return ErrorResult(
        CacheFailure('Unable to save the job status locally: $error'),
      );
    }
  }
}
