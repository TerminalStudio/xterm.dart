import 'package:meta/meta.dart';
import 'package:xterm/buffer/cell_color.dart';

class TerminalColourScheme {
  TerminalColourScheme({
    @required this.cursor,
    @required this.selection,
    @required this.foreground,
    @required this.background,
    @required this.black,
    @required this.white,
    @required this.red,
    @required this.green,
    @required this.yellow,
    @required this.blue,
    @required this.magenta,
    @required this.cyan,
    @required this.brightBlack,
    @required this.brightRed,
    @required this.brightGreen,
    @required this.brightYellow,
    @required this.brightBlue,
    @required this.brightMagenta,
    @required this.brightCyan,
  });

  CellColor cursor;
  CellColor selection;

  CellColor foreground;
  CellColor background;
  CellColor black;
  CellColor red;
  CellColor green;
  CellColor yellow;
  CellColor blue;
  CellColor magenta;
  CellColor cyan;

  CellColor brightBlack;
  CellColor brightRed;
  CellColor brightGreen;
  CellColor brightYellow;
  CellColor brightBlue;
  CellColor brightMagenta;
  CellColor brightCyan;
  CellColor white;
}
