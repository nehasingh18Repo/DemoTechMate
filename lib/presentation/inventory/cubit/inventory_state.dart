import 'package:equatable/equatable.dart';
import 'package:brightspeed_fiber_app/core/location/device_location.dart';

enum InventoryStatus { initial, loading, success, failure }

class InventoryState extends Equatable {
  const InventoryState({
    this.status = InventoryStatus.initial,
    this.location,
    this.message,
    this.errorMessage,
  });

  final InventoryStatus status;
  final DeviceLocation? location;
  final String? message;
  final String? errorMessage;

  InventoryState copyWith({
    InventoryStatus? status,
    DeviceLocation? location,
    String? message,
    String? errorMessage,
    bool clearMessage = false,
    bool clearError = false,
  }) {
    return InventoryState(
      status: status ?? this.status,
      location: location ?? this.location,
      message: clearMessage ? null : (message ?? this.message),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, location, message, errorMessage];
}
