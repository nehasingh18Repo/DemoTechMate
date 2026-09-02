import 'package:brightspeed_fiber_app/core/utils/result.dart';
import 'package:brightspeed_fiber_app/domain/entities/dashboard_summary.dart';

abstract class DashboardRepository {
  Future<Result<DashboardSummary>> getSummary();
}
