import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// The value the `compression` column carries for an uncompacted segment.
const String uncompactedEncoding = 'none';

/// The value retention writes when it compacts a segment in place.
const String gzipEncoding = 'gzip';

/// Expands a stored log segment back to the bytes the step produced.
///
/// Retention rewrites older segments as gzip in place, so compaction is a
/// storage detail that must not cross a repository boundary: every reader —
/// the live observation window as much as the history panel — has to receive
/// plaintext or the view renders compressed bytes as text.
///
/// A segment that cannot be expanded yields a legible marker rather than
/// throwing, so one corrupt row never fails a whole page of evidence.
Uint8List expandLogSegment({
  required List<int> bytes,
  required String compression,
  required String segmentId,
}) {
  if (compression == uncompactedEncoding) {
    return bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  }
  try {
    return Uint8List.fromList(gzip.decode(bytes));
  } on Object {
    return Uint8List.fromList(
      utf8.encode('[log segment $segmentId could not be expanded]'),
    );
  }
}
