import 'package:xterm/src/base/event.dart';

mixin Disposable {
  final _disposables = <Disposable>[];

  bool get disposed => _disposed;
  bool _disposed = false;

  Event get onDisposed => _onDisposed.event;
  final _onDisposed = EventEmitter();

  void register(Disposable disposable) {
    assert(!_disposed);
    _disposables.add(disposable);
  }

  void dispose() {
    _disposed = true;
    for (final disposable in _disposables) {
      disposable.dispose();
    }
    _onDisposed.emit(null);
  }
}
