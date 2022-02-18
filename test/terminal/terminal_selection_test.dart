import 'dart:math' show max;
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/mouse/position.dart';
import 'package:xterm/xterm.dart';


void main() async {

  group("Terminal selection test", () {

    const text = ""
        "Hello World!\r\n"
        "This is beautiful plugin!";
    final linesLength = text.split('\n').length;
    final maxLengthInLine = text.split('\n').fold<int>(0, (pre, e) => max(pre, e.length));

    test("Select in normal range", () {
      final terminal = Terminal(maxLines: 100);
      terminal.write(text);
      terminal.selection!.init(Position(0, 0));
      terminal.selection!.update(Position(maxLengthInLine, linesLength));
      expect(terminal.getSelectedText(), text.replaceAll('\r', '') + "\n");
    });

    test("Select beyond the boundary", () {
      final terminal = Terminal(maxLines: 100);
      terminal.write(text);
      terminal.selection!.init(Position(-3, -7));
      terminal.selection!.update(Position(maxLengthInLine + 8, linesLength));
      expect(terminal.getSelectedText(), text.replaceAll('\r', '') + "\n");
    });
  });
}