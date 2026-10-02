import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:xterm/xterm.dart';

@GenerateNiceMocks([MockSpec<EscapeHandler>()])
import 'parser_test.mocks.dart';

void main() {
  group('EscapeParser', () {
    test('can parse window manipulation', () {
      final parser = EscapeParser(MockEscapeHandler());
      parser.write('\x1b[8;24;80t');
      verify(parser.handler.resize(80, 24));
    });

    test('parses SGR colon sub-parameters', () {
      final parser = EscapeParser(MockEscapeHandler());
      parser.write('\x1b[4m\x1b[4:0m');
      verifyInOrder([
        parser.handler.setCursorUnderline(),
        parser.handler.unsetCursorUnderline(),
      ]);
      verifyNever(parser.handler.setBackgroundColor16(NamedColor.black));
    });

    test('parses colon-separated underline styles as underline', () {
      final parser = EscapeParser(MockEscapeHandler());
      parser.write('\x1b[4:3m');
      verify(parser.handler.setCursorUnderline()).called(1);
    });

    test('parses colon-separated RGB colours', () {
      final parser = EscapeParser(MockEscapeHandler());
      parser.write('\x1b[38:2::1:2:3m\x1b[48:2:4:5:6m');
      verify(parser.handler.setForegroundColorRgb(1, 2, 3));
      verify(parser.handler.setBackgroundColorRgb(4, 5, 6));
    });

    test('parses colon-separated 256 colours among other parameters', () {
      final parser = EscapeParser(MockEscapeHandler());
      parser.write('\x1b[1;38:5:9;3m');
      verify(parser.handler.setCursorBold());
      verify(parser.handler.setForegroundColor256(9));
      verify(parser.handler.setCursorItalic());
    });
  });
}
