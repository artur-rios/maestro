import 'dart:typed_data';

final class LogBatch {
  LogBatch({required this.sequence, required Uint8List bytes})
    : bytes = Uint8List.fromList(bytes);

  final int sequence;
  final Uint8List bytes;
}

abstract interface class DurableLogSink {
  Future<void> append(LogBatch batch);
}
