import 'package:test/test.dart';
import 'package:xterm/core.dart';

void main() {
  group('partial DECSTBM scroll region', () {
    test('scrolling a partial region does not disturb rows below it', () {
      final terminal = Terminal();
      terminal.resize(10, 6);

      // Fill six rows with identifiable content.
      terminal.write('L0\r\nL1\r\nL2\r\nL3\r\nL4\r\nL5');

      // A *partial* scroll region covering rows 1..3 (indices 0..2); the screen is 6 rows tall.
      terminal.write('\x1b[1;3r');
      // Park the cursor on the bottom margin (row 3) and index — scrolls the region up by one.
      terminal.write('\x1b[3;1H');
      terminal.write('\n');

      String row(int i) => terminal.buffer.lines[i].toString().trim();

      // Rows below the region must be untouched — the bug inserted a line below the region and shoved
      // these down.
      expect(row(3), 'L3');
      expect(row(4), 'L4');
      expect(row(5), 'L5');

      // The region itself scrolled up: L0 fell off the top, L1/L2 moved up, the bottom row cleared.
      expect(row(0), 'L1');
      expect(row(1), 'L2');
      expect(row(2), '');
    });
  });
}
