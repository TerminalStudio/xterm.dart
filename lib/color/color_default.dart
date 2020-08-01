import 'package:xterm/buffer/cell_color.dart';
import 'package:xterm/color/color_scheme.dart';

final defaultColorScheme = TerminalColourScheme(
  cursor: CellColor(0xffaeafad),
  selection: CellColor(0xffffff40),
  foreground: CellColor(0xffcccccc),
  background: CellColor(0xff1e1e1e),
  black: CellColor(0xff000000),
  white: CellColor(0xffe5e5e5),
  red: CellColor(0xffcd3131),
  green: CellColor(0xff0dbc79),
  yellow: CellColor(0xffe5e510),
  blue: CellColor(0xff2472c8),
  magenta: CellColor(0xffbc3fbc),
  cyan: CellColor(0xff11a8cd),
  brightBlack: CellColor(0xff666666),
  brightRed: CellColor(0xfff14c4c),
  brightGreen: CellColor(0xff23d18b),
  brightYellow: CellColor(0xfff5f543),
  brightBlue: CellColor(0xff3b8eea),
  brightMagenta: CellColor(0xffd670d6),
  brightCyan: CellColor(0xff29b8db),
);
