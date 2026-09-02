import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:brightspeed_fiber_app/core/error/failures.dart';
import 'package:brightspeed_fiber_app/core/location/location_tracking_service.dart';
import 'package:brightspeed_fiber_app/core/utils/result.dart';
import 'package:brightspeed_fiber_app/presentation/inventory/cubit/inventory_state.dart';

class InventoryCubit extends Cubit<InventoryState> {
  InventoryCubit({
    required LocationTrackingService locationTrackingService,
  })  : _locationTrackingService = locationTrackingService,
        super(const InventoryState());

  final LocationTrackingService _locationTrackingService;

  /// Reads GPS lat/lng/timestamp, then POSTs to /api/location/user/{userId}.
  Future<void> captureAndSendLocation(int userId) async {
    emit(
      state.copyWith(
        status: InventoryStatus.loading,
        clearError: true,
        clearMessage: true,
      ),
    );

    final result = await _locationTrackingService.syncOnce(userId);
    switch (result) {
      case Success(:final data):
        emit(
          state.copyWith(
            status: InventoryStatus.success,
            location: data,
            message:
                'Location sent: ${data.latitude.toStringAsFixed(6)}, '
                '${data.longitude.toStringAsFixed(6)}',
            clearError: true,
          ),
        );
      case ErrorResult(:final failure):
        final isLocation = failure is LocationFailure;
        emit(
          state.copyWith(
            status: InventoryStatus.failure,
            errorMessage: isLocation
                ? failure.message
                : 'Got location but API failed: ${failure.message}',
            clearMessage: true,
          ),
        );
    }
  }

  void clearFeedback() {
    emit(state.copyWith(clearError: true, clearMessage: true));
  }
}
