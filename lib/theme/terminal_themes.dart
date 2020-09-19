import 'package:xterm/theme/terminal_color.dart';
import 'package:xterm/theme/terminal_theme.dart';

class TerminalThemes {
  static const defaultTheme = TerminalTheme(
    cursor: TerminalColor(0xffaeafad),
    selection: TerminalColor(0xffffff40),
    foreground: TerminalColor(0xffcccccc),
    background: TerminalColor(0xff1e1e1e),
    black: TerminalColor(0xff000000),
    white: TerminalColor(0xffe5e5e5),
    red: TerminalColor(0xffcd3131),
    green: TerminalColor(0xff0dbc79),
    yellow: TerminalColor(0xffe5e510),
    blue: TerminalColor(0xff2472c8),
    magenta: TerminalColor(0xffbc3fbc),
    cyan: TerminalColor(0xff11a8cd),
    brightBlack: TerminalColor(0xff666666),
    brightRed: TerminalColor(0xfff14c4c),
    brightGreen: TerminalColor(0xff23d18b),
    brightYellow: TerminalColor(0xfff5f543),
    brightBlue: TerminalColor(0xff3b8eea),
    brightMagenta: TerminalColor(0xffd670d6),
    brightCyan: TerminalColor(0xff29b8db),
  );
}
