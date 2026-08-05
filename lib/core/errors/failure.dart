sealed class MaestroFailure {
  const MaestroFailure({
    required this.code,
    required this.message,
    this.remediation,
    this.cause,
  });

  final String code;
  final String message;
  final String? remediation;
  final Object? cause;
}

final class ValidationFailure extends MaestroFailure {
  const ValidationFailure({
    required super.code,
    required super.message,
    super.remediation,
    super.cause,
  });
}

final class StorageFailure extends MaestroFailure {
  const StorageFailure({
    required super.code,
    required super.message,
    super.remediation,
    super.cause,
  });
}

final class PlatformFailure extends MaestroFailure {
  const PlatformFailure({
    required super.code,
    required super.message,
    super.remediation,
    super.cause,
  });
}

final class SecurityFailure extends MaestroFailure {
  const SecurityFailure({
    required super.code,
    required super.message,
    super.remediation,
    super.cause,
  });
}
