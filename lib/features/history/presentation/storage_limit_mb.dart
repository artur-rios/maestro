sealed class StorageLimitMbParseResult {
  const StorageLimitMbParseResult();

  int? get bytes => null;
  String? get error => null;
}

final class StorageLimitMbValid extends StorageLimitMbParseResult {
  const StorageLimitMbValid(this.bytes);

  @override
  final int bytes;
}

final class StorageLimitMbInvalid extends StorageLimitMbParseResult {
  const StorageLimitMbInvalid(this.error);

  @override
  final String error;
}

final class StorageLimitMb {
  static const bytesPerMb = 1000000;
  static const minimumMb = 1;
  static const maximumMb = 1099511;

  static StorageLimitMbParseResult parse(String value) {
    final megabytes = int.tryParse(value.trim());
    if (megabytes == null) {
      return const StorageLimitMbInvalid('Enter a whole number of MB.');
    }
    if (megabytes < minimumMb || megabytes > maximumMb) {
      return const StorageLimitMbInvalid(
        'Storage limit must be between 1 and 1099511 MB.',
      );
    }
    return StorageLimitMbValid(megabytes * bytesPerMb);
  }

  static String formatBytes(int bytes) => (bytes ~/ bytesPerMb).toString();
}
