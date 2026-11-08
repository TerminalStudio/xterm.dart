import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

/// The attributes of the first cell after [escape] and one character.
int _attrs(String escape) {
  final terminal = Terminal();
  terminal.write('${escape}X');
  return terminal.buffer.lines[0].getAttributes(0);
}

bool _bold(int attrs) => attrs & CellFlags.bold != 0;
bool _faint(int attrs) => attrs & CellFlags.faint != 0;

void main() {
  group('SGR 22 (normal intensity)', () {
    test('bold on, then ESC[22m: bold is off', () {
      expect(_bold(_attrs('\x1b[1m')), isTrue);
      expect(_bold(_attrs('\x1b[1m\x1b[22m')), isFalse);
    });

    test('faint on, then ESC[22m: faint is off', () {
      expect(_faint(_attrs('\x1b[2m')), isTrue);
      expect(_faint(_attrs('\x1b[2m\x1b[22m')), isFalse);
    });

    test('clears both when both are on, in one sequence or several', () {
      final both = _attrs('\x1b[1;2m');
      expect(_bold(both) && _faint(both), isTrue);
      for (final seq in ['\x1b[1;2;22m', '\x1b[1m\x1b[2m\x1b[22m']) {
        final a = _attrs(seq);
        expect(_bold(a) || _faint(a), isFalse, reason: seq);
      }
    });

    test('leaves the other attributes and the colors alone', () {
      final terminal = Terminal();
      terminal.write('\x1b[1;3;4;31m\x1b[22mX');
      final line = terminal.buffer.lines[0];
      final a = line.getAttributes(0);
      expect(_bold(a), isFalse);
      expect(a & CellFlags.italic != 0, isTrue);
      expect(a & CellFlags.underline != 0, isTrue);
      expect(line.getForeground(0) & CellColor.valueMask, 1);
    });

    test('bold can be set again afterwards', () {
      expect(_bold(_attrs('\x1b[1m\x1b[22m\x1b[1m')), isTrue);
    });
  });
}
