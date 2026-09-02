import 'package:brightspeed_fiber_app/core/constants/api_constants.dart';
import 'package:brightspeed_fiber_app/core/network/api_client.dart';
import 'package:brightspeed_fiber_app/data/models/dashboard_summary_model.dart';

class DashboardRemoteDataSource {
  const DashboardRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<DashboardSummaryModel> fetchSummary() async {
    final json = await _apiClient.getJson(ApiConstants.dashboardSummary);
    return DashboardSummaryModel.fromJson(json);
  }
}
