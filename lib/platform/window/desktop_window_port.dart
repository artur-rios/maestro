abstract interface class DesktopWindowPort {
  Future<void> beginDrag();
  Future<void> minimize();
  Future<bool> isMaximized();
  Future<void> toggleMaximize();
  Future<void> close();
}

final class NoopDesktopWindowPort implements DesktopWindowPort {
  const NoopDesktopWindowPort();

  @override
  Future<void> beginDrag() async {}

  @override
  Future<void> minimize() async {}

  @override
  Future<bool> isMaximized() async => false;

  @override
  Future<void> toggleMaximize() async {}

  @override
  Future<void> close() async {}
}
