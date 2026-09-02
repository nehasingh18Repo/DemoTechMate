import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:brightspeed_fiber_app/core/utils/job_status_mapper.dart';
import 'package:brightspeed_fiber_app/core/utils/result.dart';
import 'package:brightspeed_fiber_app/core/sync/jobs_sync_service.dart';
import 'package:brightspeed_fiber_app/domain/entities/job.dart';
import 'package:brightspeed_fiber_app/domain/usecases/jobs_usecases.dart';
import 'package:brightspeed_fiber_app/presentation/jobs/cubit/jobs_state.dart';

class JobsCubit extends Cubit<JobsState> {
  JobsCubit({
    required GetUserJobsUseCase getUserJobsUseCase,
    required RefreshJobStatusOnResumeUseCase refreshJobStatusOnResumeUseCase,
    required UpdateJobStatusUseCase updateJobStatusUseCase,
    required JobsSyncService jobsSyncService,
  })  : _getUserJobsUseCase = getUserJobsUseCase,
        _refreshJobStatusOnResumeUseCase = refreshJobStatusOnResumeUseCase,
        _updateJobStatusUseCase = updateJobStatusUseCase,
        _jobsSyncService = jobsSyncService,
        super(const JobsState()) {
    _jobsSyncService.addListener(_onSyncChanged);
  }

  final GetUserJobsUseCase _getUserJobsUseCase;
  final RefreshJobStatusOnResumeUseCase _refreshJobStatusOnResumeUseCase;
  final UpdateJobStatusUseCase _updateJobStatusUseCase;
  final JobsSyncService _jobsSyncService;
  int? _userId;
  int _handledCompletionGeneration = 0;
  JobsSyncState? _handledSyncState;
  final Set<int> _statusUpdatesInFlight = {};

  static const _duplicateStatusMessage =
      'You have already selected this status';

  Future<void> loadJobs(
    int userId, {
    bool refresh = false,
    bool silent = false,
    bool forceRemoteFetch = false,
    bool flushLocalStatusAfterFetch = false,
  }) async {
    _userId = userId;
    await _jobsSyncService.start(userId);

    // Silent/fast refresh keeps current Job Cards visible (~instant UI).
    if (!(silent && state.visibleJobs.isNotEmpty)) {
      emit(
        state.copyWith(
          status: JobsStatus.loading,
          clearError: true,
          clearStatusMessage: true,
          currentPage: refresh ? 1 : state.currentPage,
        ),
      );
    } else {
      emit(
        state.copyWith(
          clearError: true,
          clearStatusMessage: true,
          currentPage: refresh ? 1 : state.currentPage,
        ),
      );
    }

    final isOnline = _jobsSyncService.isOnline;
    final result = await _getUserJobsUseCase(
      userId,
      isOnline: isOnline,
      forceRemoteFetch: forceRemoteFetch && isOnline,
      flushLocalStatusAfterFetch: flushLocalStatusAfterFetch,
    );
    switch (result) {
      case Success(:final data):
        final filtered = _applySearch(data, state.searchQuery);
        emit(
          state.copyWith(
            status: JobsStatus.success,
            allJobs: data,
            visibleJobs: _paginate(filtered, 1),
            currentPage: 1,
            hasMore: filtered.length > state.pageSize,
            clearError: true,
          ),
        );
      case ErrorResult(:final failure):
        emit(
          state.copyWith(
            status: state.visibleJobs.isNotEmpty
                ? JobsStatus.success
                : JobsStatus.failure,
            errorMessage: failure.message,
          ),
        );
    }
  }

  /// Refreshes job status when the app returns from background/inactive.
  ///
  /// Online: live API status. Offline: DB status when available, otherwise
  /// the cached API status. Other job fields always come from the API payload.
  Future<void> refreshJobStatusOnResume(int userId) async {
    _userId = userId;
    await _jobsSyncService.start(userId);

    emit(
      state.copyWith(
        clearError: true,
        clearStatusMessage: true,
      ),
    );

    final isOnline = _jobsSyncService.isOnline;
    final pending = await _jobsSyncService.pendingOutboxCount();
    final preferLocalStatus = !isOnline || pending > 0;

    final result = await _refreshJobStatusOnResumeUseCase(
      userId,
      isOnline: isOnline,
      preferLocalStatus: preferLocalStatus,
    );
    switch (result) {
      case Success(:final data):
        final filtered = _applySearch(data, state.searchQuery);
        emit(
          state.copyWith(
            status: JobsStatus.success,
            allJobs: data,
            visibleJobs: _paginate(filtered, state.currentPage),
            hasMore: filtered.length > state.currentPage * state.pageSize,
            clearError: true,
          ),
        );
      case ErrorResult(:final failure):
        if (state.visibleJobs.isEmpty) {
          emit(
            state.copyWith(
              status: JobsStatus.failure,
              errorMessage: failure.message,
            ),
          );
        }
    }
  }

  void updateSearch(String query) {
    final filtered = _applySearch(state.allJobs, query);
    emit(
      state.copyWith(
        searchQuery: query,
        visibleJobs: _paginate(filtered, 1),
        currentPage: 1,
        hasMore: filtered.length > state.pageSize,
      ),
    );
  }

  void loadMore() {
    if (state.isLoadingMore || !state.hasMore) {
      return;
    }

    final filtered = _applySearch(state.allJobs, state.searchQuery);
    final nextPage = state.currentPage + 1;
    final end = nextPage * state.pageSize;

    emit(state.copyWith(isLoadingMore: true));
    emit(
      state.copyWith(
        visibleJobs: filtered.take(end).toList(),
        currentPage: nextPage,
        hasMore: filtered.length > end,
        isLoadingMore: false,
      ),
    );
  }

  Future<void> updateStatus({
    required Job job,
    required String displayStatus,
  }) async {
    final userId = _userId;
    if (userId == null || job.id <= 0) {
      return;
    }

    final targetApiStatus = JobStatusMapper.toApi(displayStatus);
    final currentApiStatus = JobStatusMapper.toApi(job.status);
    if (targetApiStatus == currentApiStatus) {
      emit(
        state.copyWith(
          status: JobsStatus.success,
          statusUpdateMessage: _duplicateStatusMessage,
        ),
      );
      return;
    }

    if (_statusUpdatesInFlight.contains(job.id)) {
      return;
    }
    _statusUpdatesInFlight.add(job.id);

    final previousJobs = state.allJobs;
    final optimistic = previousJobs
        .map(
          (item) => item.id == job.id && item.jobId == job.jobId
              ? item.copyWith(
                  status: displayStatus,
                  version: item.version,
                )
              : item,
        )
        .toList();

    emit(
      state.copyWith(
        status: JobsStatus.updating,
        allJobs: optimistic,
        visibleJobs: _paginate(
          _applySearch(optimistic, state.searchQuery),
          state.currentPage,
        ),
        clearError: true,
        clearStatusMessage: true,
      ),
    );

    final apiStatus = targetApiStatus;
    try {
      final result = await _updateJobStatusUseCase(
        userId: userId,
        job: job,
        status: apiStatus,
        createdOffline: !_jobsSyncService.isOnline,
      );
      switch (result) {
        case Success(:final data):
          if (data) {
            _jobsSyncService.notifyQueued(displayStatus);
            emit(
              state.copyWith(
                status: JobsStatus.success,
                clearStatusMessage: true,
              ),
            );
          } else {
            emit(
              state.copyWith(
                status: JobsStatus.success,
                allJobs: previousJobs,
                visibleJobs: _paginate(
                  _applySearch(previousJobs, state.searchQuery),
                  state.currentPage,
                ),
                statusUpdateMessage: _duplicateStatusMessage,
              ),
            );
          }
        case ErrorResult(:final failure):
          emit(
            state.copyWith(
              status: JobsStatus.success,
              allJobs: previousJobs,
              visibleJobs: _paginate(
                _applySearch(previousJobs, state.searchQuery),
                state.currentPage,
              ),
              errorMessage: failure.message,
            ),
          );
      }
    } finally {
      _statusUpdatesInFlight.remove(job.id);
    }
  }

  void _onSyncChanged() {
    if (isClosed) {
      return;
    }
    final syncState = _jobsSyncService.state;
    if (syncState == JobsSyncState.failed &&
        _handledSyncState != JobsSyncState.failed) {
      emit(
        state.copyWith(
          status: JobsStatus.success,
          errorMessage: _jobsSyncService.message,
        ),
      );
    }
    _handledSyncState = syncState;

    final generation = _jobsSyncService.completionGeneration;
    if (generation > _handledCompletionGeneration) {
      _handledCompletionGeneration = generation;
      _reloadAfterSync();
    }
  }

  /// Runs once the outbox is fully drained: refetches the jobs list from the
  /// server so the cards show the values the backend now holds.
  Future<void> _reloadAfterSync() async {
    final userId = _userId;
    if (userId == null || isClosed) {
      return;
    }
    debugPrint('JOBS_SYNC calling GET /api/jobs/user/$userId after sync');
    await loadJobs(
      userId,
      refresh: true,
      silent: true,
      forceRemoteFetch: true,
      flushLocalStatusAfterFetch: true,
    );
    if (!isClosed) {
      _jobsSyncService.completeSyncCycle();
      debugPrint(
          'JOBS_SYNC job list refreshed with ${state.allJobs.length} jobs');
      emit(
        state.copyWith(
          statusUpdateMessage: 'Job updates synced successfully',
          clearStatusMessage: true,
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _jobsSyncService.removeListener(_onSyncChanged);
    return super.close();
  }

  List<Job> _applySearch(List<Job> jobs, String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return jobs;
    }

    return jobs.where((job) {
      return job.name.toLowerCase().contains(normalized) ||
          job.jobId.toLowerCase().contains(normalized) ||
          job.orderNumber.toLowerCase().contains(normalized) ||
          job.address.toLowerCase().contains(normalized) ||
          job.status.toLowerCase().contains(normalized) ||
          job.technicianName.toLowerCase().contains(normalized);
    }).toList();
  }

  List<Job> _paginate(List<Job> jobs, int page) {
    final end = page * state.pageSize;
    return jobs.take(end).toList();
  }
}
