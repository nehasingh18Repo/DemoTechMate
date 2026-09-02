import 'package:brightspeed_fiber_app/core/error/failures.dart';

/// Lightweight result type for repository/use-case boundaries.
sealed class Result<T> {
  const Result();
}

class Success<T> extends Result<T> {
  const Success(this.data);

  final T data;
}

class ErrorResult<T> extends Result<T> {
  const ErrorResult(this.failure);

  final Failure failure;
}

extension ResultX<T> on Result<T> {
  bool get isSuccess => this is Success<T>;
  bool get isError => this is ErrorResult<T>;

  T? get dataOrNull => switch (this) {
        Success<T>(:final data) => data,
        _ => null,
      };

  Failure? get failureOrNull => switch (this) {
        ErrorResult<T>(:final failure) => failure,
        _ => null,
      };
}
