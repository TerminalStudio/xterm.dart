/// interface for every Terminal backend
abstract class TerminalBackend {
  /// initializes the backend
  /// This can be used to instantiate instances that are problematic when
  /// passed to a Isolate.
  /// The [TerminalIsolate] will pass the backend to the [Terminal] that then
  /// executes [init] from inside the Isolate.
  /// So when your backend needs any complex instances (most of them will)
  /// then strongly consider instantiating them here
  void init();

  /// Stream for data that gets read from the backend
  Stream<String> get out;

  /// Future that fires when the backend terminates
  Future<int> get exitCode;

  /// writes data to this backend
  void write(String input);

  /// notifies the backend about a view port resize that happened
  /// If resizeFull() is overrode, resize() will not be called, but still
  /// requires an empty method as a stub for API compatibility reasons.
  void resize(int width, int height);

  /// notifies the backend about a view port resize that happened, with information
  /// including both row/column and pixel width/height.
  /// Not required to be overrode if the [TerminalBackend] does not require
  /// pixel size information, just override resize() instead.
  void resizeFull(int columns, int rows, int pixelWidth, int pixelHeight) {
    resize(columns, rows);
  }

  /// terminates this backend
  void terminate();

  /// acknowledges processing of a data junk
  void ackProcessed();
}
