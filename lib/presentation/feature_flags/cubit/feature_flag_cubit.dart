import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:brightspeed_fiber_app/data/datasources/feature_flag_local_datasource.dart';
import 'package:brightspeed_fiber_app/data/datasources/feature_flag_remote_datasource.dart';
import 'package:brightspeed_fiber_app/domain/entities/feature_flags.dart';
import 'package:brightspeed_fiber_app/presentation/feature_flags/cubit/feature_flag_state.dart';

class FeatureFlagCubit extends Cubit<FeatureFlagState> {
  FeatureFlagCubit({
    required FeatureFlagLocalDataSource localDataSource,
    required FeatureFlagRemoteDataSource remoteDataSource,
  })  : _localDataSource = localDataSource,
        _remoteDataSource = remoteDataSource,
        super(const FeatureFlagState());

  final FeatureFlagLocalDataSource _localDataSource;
  final FeatureFlagRemoteDataSource _remoteDataSource;

  /// GET /features/{userId} using the logged-in user id.
  /// If the API is unreachable or invalid, falls back to local JSON.
  /// Missing `featureName` keys stay visible (default true).
  Future<void> load({required int userId}) async {
    emit(
      state.copyWith(
        status: FeatureFlagStatus.loading,
        clearError: true,
      ),
    );

    try {
      final flags = await _remoteDataSource.getFeatureFlags(userId);
      _logFlags('API', userId, flags);
      emit(
        state.copyWith(
          status: FeatureFlagStatus.loaded,
          flags: flags,
          clearError: true,
        ),
      );
    } catch (apiError) {
      debugPrint(
        'Feature flags API failed for userId=$userId: $apiError. '
        'Falling back to local JSON.',
      );
      await _loadLocalFallback();
    }
  }

  void reset() {
    emit(const FeatureFlagState());
  }

  Future<void> _loadLocalFallback() async {
    try {
      final flags = await _localDataSource.loadFeatureFlags();
      _logFlags('local JSON', null, flags);
      emit(
        state.copyWith(
          status: FeatureFlagStatus.loaded,
          flags: flags,
          clearError: true,
        ),
      );
    } catch (error, stack) {
      debugPrint('Feature flags local load failed: $error\n$stack');
      emit(
        state.copyWith(
          status: FeatureFlagStatus.failure,
          flags: FeatureFlags.allEnabled,
          errorMessage: 'Failed to load feature flags; showing all UI.',
        ),
      );
    }
  }

  void _logFlags(String source, int? userId, FeatureFlags flags) {
    debugPrint(
      'FeatureFlags loaded from $source'
      '${userId == null ? '' : ' (userId=$userId)'}: '
      'job=${flags.job}, circuitView=${flags.circuitView}, '
      'myInventory=${flags.myInventory}, timesheet=${flags.timesheet}, '
      'hotReads=${flags.hotReads}, map=${flags.map}, refresh=${flags.refresh}, '
      'dashboardTab=${flags.dashboardTab}, jobsTab=${flags.jobsTab}',
    );
  }
}
