import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/storage/log_compaction.dart';

void main() {
  test(
    'GivenAnUncompactedSegment_WhenExpanded_ThenItsBytesAreReturnedUnchanged',
    () {
      // Given
      final bytes = utf8.encode('step output\n');

      // When
      final expanded = expandLogSegment(
        bytes: bytes,
        compression: uncompactedEncoding,
        segmentId: 'segment-1',
      );

      // Then
      expect(expanded, bytes);
    },
  );

  test(
    'GivenUncompactedUint8ListBytes_WhenExpanded_ThenTheSameBufferIsReturned',
    () {
      final bytes = Uint8List.fromList(utf8.encode('already typed'));

      final expanded = expandLogSegment(
        bytes: bytes,
        compression: uncompactedEncoding,
        segmentId: 'segment-1',
      );

      expect(identical(expanded, bytes), isTrue);
    },
  );

  test(
    'GivenAGzipCompactedSegment_WhenExpanded_ThenThePlaintextIsReturned',
    () {
      final plaintext = utf8.encode('${'line of evidence\n' * 64}tail');

      final expanded = expandLogSegment(
        bytes: gzip.encode(plaintext),
        compression: gzipEncoding,
        segmentId: 'segment-2',
      );

      expect(expanded, plaintext);
    },
  );

  test('GivenACorruptCompactedSegment_WhenExpanded_ThenALegibleMarkerNamesTheSegment', () {
    // Given: bytes that are not gzip at all.
    final corrupt = utf8.encode('not gzip');

    // When
    final expanded = expandLogSegment(
      bytes: corrupt,
      compression: gzipEncoding,
      segmentId: 'segment-3',
    );

    // Then: one corrupt row yields a marker instead of failing the page.
    expect(
      utf8.decode(expanded),
      '[log segment segment-3 could not be expanded]',
    );
  });

  test('GivenAnUnknownCompression_WhenExpanded_ThenItIsTreatedAsCompacted', () {
    // Anything but "none" is a compacted segment; plaintext under another
    // label is therefore reported as unexpandable, never shown as-is.
    final expanded = expandLogSegment(
      bytes: utf8.encode('plain'),
      compression: 'zstd',
      segmentId: 'segment-4',
    );

    expect(
      utf8.decode(expanded),
      '[log segment segment-4 could not be expanded]',
    );
  });
}
