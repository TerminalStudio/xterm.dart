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

    test('does not treat CSI > Ps m as SGR', () {
      final parser = EscapeParser(MockEscapeHandler());
      // XTMODKEYS, e.g. sent by programs enabling modifyOtherKeys.
      parser.write('\x1b[>4m');
      verifyNever(parser.handler.setCursorUnderline());
    });

    test('does not treat CSI ? Ps m as SGR', () {
      final parser = EscapeParser(MockEscapeHandler());
      parser.write('\x1b[?4m');
      verifyNever(parser.handler.setCursorUnderline());
    });

    test('still parses plain SGR', () {
      final parser = EscapeParser(MockEscapeHandler());
      parser.write('\x1b[4m');
      verify(parser.handler.setCursorUnderline()).called(1);
    });
  });
}
