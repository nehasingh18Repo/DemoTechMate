import 'package:brightspeed_fiber_app/core/error/exceptions.dart';
import 'package:brightspeed_fiber_app/core/error/failures.dart';
import 'package:brightspeed_fiber_app/core/utils/result.dart';
import 'package:brightspeed_fiber_app/data/datasources/dashboard_remote_datasource.dart';
import 'package:brightspeed_fiber_app/data/mock/mock_data.dart';
import 'package:brightspeed_fiber_app/domain/entities/dashboard_summary.dart';
import 'package:brightspeed_fiber_app/domain/repositories/dashboard_repository.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  const DashboardRepositoryImpl(this._remoteDataSource);

  final DashboardRemoteDataSource _remoteDataSource;

  @override
  Future<Result<DashboardSummary>> getSummary() async {
    try {
      final model = await _remoteDataSource.fetchSummary();
      return Success(model.toEntity());
    } on ServerException {
      return Success(MockData.dashboardSummary);
    } catch (_) {
      return Success(MockData.dashboardSummary);
    }
  }
}
