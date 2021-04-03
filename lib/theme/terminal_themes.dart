import 'package:xterm/theme/terminal_theme.dart';

class TerminalThemes {
  static const defaultTheme = TerminalTheme(
    cursor: 0XFFAEAFAD,
    selection: 0XFFFFFF40,
    foreground: 0XFFCCCCCC,
    background: 0XFF1E1E1E,
    black: 0XFF000000,
    red: 0XFFCD3131,
    green: 0XFF0DBC79,
    yellow: 0XFFE5E510,
    blue: 0XFF2472C8,
    magenta: 0XFFBC3FBC,
    cyan: 0XFF11A8CD,
    white: 0XFFE5E5E5,
    brightBlack: 0XFF666666,
    brightRed: 0XFFF14C4C,
    brightGreen: 0XFF23D18B,
    brightYellow: 0XFFF5F543,
    brightBlue: 0XFF3B8EEA,
    brightMagenta: 0XFFD670D6,
    brightCyan: 0XFF29B8DB,
    brightWhite: 0XFFFFFFFF,
  );

  static const whiteOnBlack = TerminalTheme(
    cursor: 0XFFAEAFAD,
    selection: 0XFFFFFF40,
    foreground: 0XFFFFFFFF,
    background: 0XFF000000,
    black: 0XFF000000,
    red: 0XFFCD3131,
    green: 0XFF0DBC79,
    yellow: 0XFFE5E510,
    blue: 0XFF2472C8,
    magenta: 0XFFBC3FBC,
    cyan: 0XFF11A8CD,
    white: 0XFFE5E5E5,
    brightBlack: 0XFF666666,
    brightRed: 0XFFF14C4C,
    brightGreen: 0XFF23D18B,
    brightYellow: 0XFFF5F543,
    brightBlue: 0XFF3B8EEA,
    brightMagenta: 0XFFD670D6,
    brightCyan: 0XFF29B8DB,
    brightWhite: 0XFFFFFFFF,
  );
}
