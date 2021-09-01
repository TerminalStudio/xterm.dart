import 'package:xterm/buffer/buffer.dart';

/// This interface defines the functionality of a Terminal that is needed
/// by the search functionality
abstract class TerminalSearchInteraction {
  /// the current buffer
  Buffer get buffer;

  /// indication if the alternative buffer is currently used
  bool isUsingAltBuffer();

  /// the terminal width
  int get terminalWidth;
}
