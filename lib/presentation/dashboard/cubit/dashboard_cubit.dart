import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:brightspeed_fiber_app/core/utils/result.dart';
import 'package:brightspeed_fiber_app/domain/usecases/get_dashboard_summary_usecase.dart';
import 'package:brightspeed_fiber_app/presentation/dashboard/cubit/dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit(this._getDashboardSummaryUseCase)
      : super(const DashboardState());

  final GetDashboardSummaryUseCase _getDashboardSummaryUseCase;

  Future<void> loadSummary() async {
    emit(state.copyWith(status: DashboardStatus.loading, clearError: true));
    final result = await _getDashboardSummaryUseCase();
    switch (result) {
      case Success(:final data):
        emit(
          state.copyWith(
            status: DashboardStatus.success,
            summary: data,
            clearError: true,
          ),
        );
      case ErrorResult(:final failure):
        emit(
          state.copyWith(
            status: DashboardStatus.failure,
            errorMessage: failure.message,
          ),
        );
    }
  }
}
