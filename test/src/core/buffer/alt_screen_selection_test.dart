import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

/// Selection inside a full-screen program (`less`, `htop`, an editor).
///
/// Those run on the ALTERNATE screen and scroll it as they paint. Scrolling
/// shifts every line up a slot, and a line left detached from its buffer makes
/// any [CellAnchor] on it dead — which is what silently broke selecting text
/// there: no highlight, nothing to copy.
void main() {
  const altScreenOn = '\x1b[?1049h';

  group('selection on the alternate screen', () {
    test('lines stay attached after the screen scrolls', () {
      final terminal = Terminal(maxLines: 10000);

      terminal.resize(80, 24);
      terminal.write(altScreenOn);

      // Paint past the last row, which scrolls the alternate screen.
      for (var row = 0; row < 40; row++) {
        terminal.write('row $row\r\n');
      }

      expect(terminal.buffer.lines.length, 24);
      expect(terminal.buffer.lines[0].attached, isTrue);
      expect(terminal.buffer.lines[23].attached, isTrue);
    });

    test('a selection made after scrolling still resolves', () {
      final terminal = Terminal(maxLines: 10000);
      final controller = TerminalController();

      terminal.resize(80, 24);
      terminal.write(altScreenOn);

      for (var row = 0; row < 40; row++) {
        terminal.write('row $row\r\n');
      }

      terminal.write('SELECT THIS LINE');

      final base = terminal.buffer.createAnchorFromOffset(
        const CellOffset(0, 23),
      );

      final extent = terminal.buffer.createAnchorFromOffset(
        const CellOffset(16, 23),
      );

      controller.setSelection(base, extent);

      expect(controller.selection, isNotNull);

      final selectedText = terminal.buffer.getText(controller.selection!);

      expect(selectedText, contains('SELECT THIS'));
    });
  });
}
