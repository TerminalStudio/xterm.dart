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

    test(
      'does not treat a private-marker-prefixed sequence ending in m as SGR',
      () {
        // `CSI > 4 ; 2 m` is xterm's modifyOtherKeys control, not SGR — its
        // params must not be read as "set underline; set faint".
        final parser = EscapeParser(MockEscapeHandler());
        parser.write('\x1b[>4;2m');
        verifyNever(parser.handler.setCursorUnderline());
        verifyNever(parser.handler.setCursorFaint());
        verify(parser.handler.unknownCSI('m'.codeUnitAt(0)));
      },
    );

    test('still parses plain SGR underline with no prefix', () {
      final parser = EscapeParser(MockEscapeHandler());
      parser.write('\x1b[4m');
      verify(parser.handler.setCursorUnderline());
    });

    test('still parses SGR with a leading empty parameter (default + bold)',
        () {
      // A leading `;` is legal SGR for an omitted/default first parameter —
      // `_csi.prefix` also captures `;` (same byte range as the real private
      // markers `< = > ?`), so this must not be misread as a private marker.
      final parser = EscapeParser(MockEscapeHandler());
      parser.write('\x1b[;1m');
      verify(parser.handler.setCursorBold());
    });
  });
}
