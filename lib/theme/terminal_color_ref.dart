import 'package:xterm/theme/terminal_color.dart';

class TerminalColorRef implements TerminalColor {
  TerminalColorRef(this.getter);

  final TerminalColor Function() getter;

  int get value => getter().value;
}
