abstract class TerminalBackend {
  void init();

  Stream<String> get out;
  Future<int> get exitCode;

  void write(String input);
  void resize(int width, int height);
}
