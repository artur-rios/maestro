import 'package:maestro/core/errors/failure.dart';

sealed class Result<T> {
  const Result();

  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(MaestroFailure failure) onFailure,
  });
}

final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;

  @override
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(MaestroFailure failure) onFailure,
  }) {
    return onSuccess(value);
  }
}

final class FailureResult<T> extends Result<T> {
  const FailureResult(this.failure);

  final MaestroFailure failure;

  @override
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(MaestroFailure failure) onFailure,
  }) {
    return onFailure(failure);
  }
}
