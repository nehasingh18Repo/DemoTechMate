import 'package:equatable/equatable.dart';
import 'package:brightspeed_fiber_app/domain/entities/job.dart';

enum JobsStatus { initial, loading, success, failure, updating }

class JobsState extends Equatable {
  const JobsState({
    this.status = JobsStatus.initial,
    this.allJobs = const [],
    this.visibleJobs = const [],
    this.searchQuery = '',
    this.pageSize = 10,
    this.currentPage = 1,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.errorMessage,
    this.statusUpdateMessage,
  });

  final JobsStatus status;
  final List<Job> allJobs;
  final List<Job> visibleJobs;
  final String searchQuery;
  final int pageSize;
  final int currentPage;
  final bool hasMore;
  final bool isLoadingMore;
  final String? errorMessage;
  final String? statusUpdateMessage;

  JobsState copyWith({
    JobsStatus? status,
    List<Job>? allJobs,
    List<Job>? visibleJobs,
    String? searchQuery,
    int? pageSize,
    int? currentPage,
    bool? hasMore,
    bool? isLoadingMore,
    String? errorMessage,
    String? statusUpdateMessage,
    bool clearError = false,
    bool clearStatusMessage = false,
  }) {
    return JobsState(
      status: status ?? this.status,
      allJobs: allJobs ?? this.allJobs,
      visibleJobs: visibleJobs ?? this.visibleJobs,
      searchQuery: searchQuery ?? this.searchQuery,
      pageSize: pageSize ?? this.pageSize,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      statusUpdateMessage: clearStatusMessage
          ? null
          : (statusUpdateMessage ?? this.statusUpdateMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        allJobs,
        visibleJobs,
        searchQuery,
        pageSize,
        currentPage,
        hasMore,
        isLoadingMore,
        errorMessage,
        statusUpdateMessage,
      ];
}
