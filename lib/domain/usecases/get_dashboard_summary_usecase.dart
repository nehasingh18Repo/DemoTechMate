import 'package:brightspeed_fiber_app/core/utils/result.dart';
import 'package:brightspeed_fiber_app/domain/entities/dashboard_summary.dart';
import 'package:brightspeed_fiber_app/domain/repositories/dashboard_repository.dart';

class GetDashboardSummaryUseCase {
  const GetDashboardSummaryUseCase(this._repository);

  final DashboardRepository _repository;

  Future<Result<DashboardSummary>> call() => _repository.getSummary();
}
