import 'package:test/test.dart';
import 'package:xterm/xterm.dart';

void main() {
  group('BufferLine.getText()', () {
    test('should return the text', () {
      final terminal = Terminal();
      terminal.write('Hello World');
      expect(terminal.buffer.lines[0].getText(), 'Hello World');
    });

    test('getText() should support wide characters', () {
      final text = '😀😁😂🤣😃';
      final terminal = Terminal();
      terminal.write(text);
      expect(terminal.buffer.lines[0].getText(), equals(text));
    });

    test('can specify a range', () {
      final terminal = Terminal();
      terminal.write('Hello World');
      expect(terminal.buffer.lines[0].getText(0, 5), 'Hello');
    });

    test('can handle invalid ranges', () {
      final terminal = Terminal();
      terminal.write('Hello World');
      expect(terminal.buffer.lines[0].getText(0, 100), 'Hello World');
    });

    test('can handle negative ranges', () {
      final terminal = Terminal();
      terminal.write('Hello World');
      expect(terminal.buffer.lines[0].getText(-100, 100), 'Hello World');
    });

    test('can handle reversed ranges', () {
      final terminal = Terminal();
      terminal.write('Hello World');
      expect(terminal.buffer.lines[0].getText(5, 0), '');
    });
  });

  group('BufferLine.getTrimmedLength()', () {
    test('can get trimmed length', () {
      final line = BufferLine(10);

      final text = 'ABCDEF';

      for (var i = 0; i < text.length; i++) {
        line.setCodePoint(i, text.codeUnitAt(i));
      }

      expect(line.getTrimmedLength(), equals(text.length));
    });
  });
}
