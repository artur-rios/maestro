/// A manifest source or downloader that owns a network transport.
///
/// `UpdateService.close` releases these. A fake that owns no transport simply
/// does not implement it, so test compositions need no closing ceremony.
abstract interface class ClosableUpdateTransport {
  Future<void> close();
}
