import 'package:equatable/equatable.dart';
import 'package:brightspeed_fiber_app/domain/entities/feature_flags.dart';

enum FeatureFlagStatus { initial, loading, loaded, failure }

class FeatureFlagState extends Equatable {
  const FeatureFlagState({
    this.status = FeatureFlagStatus.initial,
    this.flags = FeatureFlags.allEnabled,
    this.errorMessage,
  });

  final FeatureFlagStatus status;
  final FeatureFlags flags;
  final String? errorMessage;

  FeatureFlagState copyWith({
    FeatureFlagStatus? status,
    FeatureFlags? flags,
    String? errorMessage,
    bool clearError = false,
  }) {
    return FeatureFlagState(
      status: status ?? this.status,
      flags: flags ?? this.flags,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, flags, errorMessage];
}
