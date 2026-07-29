import 'package:test/test.dart';
import 'package:xterm/core.dart';

void main() {
  group('background-colour erase (bce)', () {
    test('ESC[K after short text fills the rest of the row with the current background', () {
      final terminal = Terminal();
      terminal.resize(20, 5);

      // Green background, two characters, then erase-to-end-of-line.
      terminal.write('\x1b[42mAB\x1b[K');

      final line = terminal.buffer.lines[0];
      final green = line.getBackground(0); // the background used for the written cells
      expect(green, isNot(0), reason: 'sanity: an explicit background is set');

      // Cells past the written text must carry the same background (bce), not the default.
      expect(line.getBackground(2), green);
      expect(line.getBackground(10), green);
      expect(line.getBackground(19), green);
    });

    test('ESC[K with the default background does not extend the line', () {
      final terminal = Terminal();
      terminal.resize(20, 5);

      terminal.write('AB\x1b[K');

      // No explicit background → erased cells stay at the default (0); the line is not grown.
      expect(terminal.buffer.lines[0].getBackground(10), 0);
    });
  });
}
