import 'package:test/test.dart';
import 'package:xterm/core/buffer/line.dart';

void main() {
  group('BufferLine', () {
    test('getText() can get text', () {
      final line = BufferLine(10);

      final text = 'ABCDEFGHIJ';

      for (var i = 0; i < text.length; i++) {
        line.setCodePoint(i, text.codeUnitAt(i));
      }

      expect(line.getText(), equals(text));
    });

    test('getText() should support wide characters', () {
      final line = BufferLine(10);

      final text = '😀😁😂🤣😃';

      for (var i = 0; i < text.runes.length; i++) {
        line.setCodePoint(i * 2, text.runes.elementAt(i));
      }

      expect(line.getText(), equals(text));
    });

    test('getTrimmedLength() can get trimmed length', () {
      final line = BufferLine(10);

      final text = 'ABCDEF';

      for (var i = 0; i < text.length; i++) {
        line.setCodePoint(i, text.codeUnitAt(i));
      }

      expect(line.getTrimmedLength(), equals(text.length));
    });
  });
}
