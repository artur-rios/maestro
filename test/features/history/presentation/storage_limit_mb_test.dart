import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/history/presentation/storage_limit_mb.dart';

void main() {
  test('GivenWholeMegabytes_WhenParsed_ThenTheyConvertToDecimalBytes', () {
    expect(StorageLimitMb.parse('1024').bytes, 1024000000);
  });

  test('GivenInvalidMegabytes_WhenParsed_ThenTheyReturnMBFeedback', () {
    expect(
      StorageLimitMb.parse('0').error,
      'Storage limit must be between 1 and 1099511 MB.',
    );
    expect(StorageLimitMb.parse('1.5').error, 'Enter a whole number of MB.');
  });

  test('GivenPersistedBytes_WhenFormatted_ThenTheWholeMBValueIsShown', () {
    expect(StorageLimitMb.formatBytes(1073741824), '1073');
  });
}
