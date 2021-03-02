import 'package:xterm/theme/terminal_color.dart';

class TerminalTheme {
  const TerminalTheme({
    required this.cursor,
    required this.selection,
    required this.foreground,
    required this.background,
    required this.black,
    required this.white,
    required this.red,
    required this.green,
    required this.yellow,
    required this.blue,
    required this.magenta,
    required this.cyan,
    required this.brightBlack,
    required this.brightRed,
    required this.brightGreen,
    required this.brightYellow,
    required this.brightBlue,
    required this.brightMagenta,
    required this.brightCyan,
    required this.brightWhite,
  });

  final TerminalColor cursor;
  final TerminalColor selection;

  final TerminalColor foreground;
  final TerminalColor background;
  final TerminalColor black;
  final TerminalColor red;
  final TerminalColor green;
  final TerminalColor yellow;
  final TerminalColor blue;
  final TerminalColor magenta;
  final TerminalColor cyan;
  final TerminalColor white;

  final TerminalColor brightBlack;
  final TerminalColor brightRed;
  final TerminalColor brightGreen;
  final TerminalColor brightYellow;
  final TerminalColor brightBlue;
  final TerminalColor brightMagenta;
  final TerminalColor brightCyan;
  final TerminalColor brightWhite;
}
