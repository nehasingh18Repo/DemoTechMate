import 'package:flutter/foundation.dart';
import 'package:brightspeed_fiber_app/core/constants/api_constants.dart';
import 'package:brightspeed_fiber_app/core/error/exceptions.dart';
import 'package:brightspeed_fiber_app/core/network/api_client.dart';
import 'package:brightspeed_fiber_app/data/models/job_model.dart';
import 'package:brightspeed_fiber_app/domain/entities/job_outbox_event.dart';

class JobsRemoteDataSource {
  const JobsRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<List<JobModel>> fetchJobsForUser(int userId) async {
    final list =
        await _apiClient.getJsonList('${ApiConstants.userJobs}/$userId');
    final jobs =
        list.whereType<Map<String, dynamic>>().map(JobModel.fromJson).toList();
    return JobModel.withCardNumbers(jobs);
  }

  /// Sends one outbox event.
  ///
  /// Changes made offline go to /api/jobs/sync with a transaction id so the
  /// server can de-duplicate retries. Changes made while online are a plain
  /// status update, so they use PATCH /api/jobs/{jobId} directly.
  Future<dynamic> syncStatus(JobOutboxEvent event) async {
    if (!event.createdOffline) {
      return _updateStatusDirectly(event);
    }

    final body = event.toApiJson();
    debugPrint('JOBS_SYNC request POST ${ApiConstants.jobsSync} $body');
    try {
      final response = await _apiClient.postFlexible(
        ApiConstants.jobsSync,
        body: body,
      );
      debugPrint('JOBS_SYNC success POST ${ApiConstants.jobsSync} $response');
      return response;
    } on ServerException catch (error) {
      if (error.statusCode == 405) {
        debugPrint(
          'JOBS_SYNC POST 405 Method Not Allowed — retrying PATCH '
          '${ApiConstants.jobsSync} $body',
        );
        try {
          final response = await _apiClient.patchFlexible(
            ApiConstants.jobsSync,
            body: body,
          );
          debugPrint(
            'JOBS_SYNC success PATCH ${ApiConstants.jobsSync} $response',
          );
          return response;
        } on ServerException catch (patchError) {
          debugPrint(
            'JOBS_SYNC failure PATCH ${ApiConstants.jobsSync} '
            'status=${patchError.statusCode} ${patchError.message}',
          );
          rethrow;
        }
      }
      debugPrint(
        'JOBS_SYNC failure POST ${ApiConstants.jobsSync} '
        'status=${error.statusCode} ${error.message}',
      );
      rethrow;
    }
  }

  Future<dynamic> _updateStatusDirectly(JobOutboxEvent event) async {
    final path = '${ApiConstants.jobById}/${event.jobId}';
    final body = _jobStatusPatchBody(
      status: event.status,
      //version: event.version,
    );
    debugPrint('JOBS_SYNC request PATCH $path $body (online change)');
    try {
      await _apiClient.patchJson(path, body: body);
      debugPrint('JOBS_SYNC success PATCH $path');
      return 'Job ${event.jobId} status ${event.status} updated';
    } on ServerException catch (error) {
      debugPrint(
        'JOBS_SYNC failure PATCH $path '
        'status=${error.statusCode} ${error.message}',
      );
      rethrow;
    }
  }

  /// Body for PATCH [ApiConstants.jobById]/{jobId}.
  ///
  /// `version` is taken from GET [ApiConstants.userJobs]/{userId} job response.
  /// After a successful update, increment `version` by 1 for the next request.
  static Map<String, dynamic> _jobStatusPatchBody({
    required String status,
    ///required int version,
  }) {
    return {
      'status': status,
      //'version': version < 1 ? 1 : version,
    };
  }
}
