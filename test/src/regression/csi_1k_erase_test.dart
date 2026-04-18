// Regression: `CSI 1 K` (Erase in Line from start to cursor) must include
// the cell UNDER the cursor, per VT100 / xterm docs.
//
// Symptom fixed: Claude Code's "Do you want to…" interactive menu drew
// garbage/leftover characters on mobile + desktop (xterm.dart) but worked
// correctly in xterm.js on web. Each menu frame uses ~36 CSI 1 K calls;
// each one previously left exactly one residual cell of stale text.
//
// Root cause: eraseLineToCursor called eraseRange(0, _cursorX) but eraseRange
// end is exclusive, so column == _cursorX was never cleared.

import 'package:test/test.dart';
import 'package:xterm/core.dart';

/// Read the codepoint at a specific column on row 0.
int cp(Terminal t, int col) => t.buffer.lines[0].getCodePoint(col);

void main() {
  group('CSI 1 K — erase line to cursor (inclusive)', () {
    test('erases cells [0..cursor] inclusive (mid-line)', () {
      final t = Terminal(maxLines: 100);
      t.resize(20, 5);
      t.write('ABCDEFGHIJ'); // cells 0..9 filled
      t.write('\x1b[6G'); // CUP column 6 1-indexed → col 5 0-indexed (on 'F')
      t.write('\x1b[1K'); // Erase from start to cursor (inclusive)

      // Cols 0..5 should all be erased (codepoint 0). Cols 6..9 untouched.
      for (var c = 0; c <= 5; c++) {
        expect(cp(t, c), 0, reason: 'col $c should be erased');
      }
      expect(cp(t, 6), 'G'.codeUnitAt(0));
      expect(cp(t, 7), 'H'.codeUnitAt(0));
      expect(cp(t, 8), 'I'.codeUnitAt(0));
      expect(cp(t, 9), 'J'.codeUnitAt(0));
    });

    test('CSI 1 K at column 0 erases exactly that cell', () {
      final t = Terminal(maxLines: 100);
      t.resize(10, 3);
      t.write('ABCDE');
      t.write('\x1b[1G'); // cursor to col 0
      t.write('\x1b[1K');

      expect(cp(t, 0), 0, reason: "'A' should be erased");
      expect(cp(t, 1), 'B'.codeUnitAt(0));
      expect(cp(t, 4), 'E'.codeUnitAt(0));
    });

    test('CSI 1 K at last column erases the whole line', () {
      final t = Terminal(maxLines: 100);
      t.resize(10, 3);
      t.write('ABCDEFGHIJ');
      t.write('\x1b[10G'); // col 10 1-indexed → col 9 0-indexed (on 'J')
      t.write('\x1b[1K');

      // All cells 0..9 should be erased.
      for (var c = 0; c < 10; c++) {
        expect(cp(t, c), 0, reason: 'col $c should be erased');
      }
    });

    test('CSI 0 K (right/default) is unaffected by the fix', () {
      final t = Terminal(maxLines: 100);
      t.resize(10, 3);
      t.write('ABCDEFGHIJ');
      t.write('\x1b[6G'); // col 5 0-indexed (on 'F')
      t.write('\x1b[0K');

      // Cols 0..4 untouched, 5..9 erased
      expect(cp(t, 0), 'A'.codeUnitAt(0));
      expect(cp(t, 4), 'E'.codeUnitAt(0));
      for (var c = 5; c < 10; c++) {
        expect(cp(t, c), 0, reason: 'col $c should be erased');
      }
    });
  });
}
