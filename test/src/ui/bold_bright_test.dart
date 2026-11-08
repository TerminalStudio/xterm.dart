import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/src/ui/painter.dart';
import 'package:xterm/src/ui/palette_builder.dart';
import 'package:xterm/xterm.dart';

/// A theme in which all 16 colors differ, so any mix-up shows.
TerminalTheme _theme({bool boldIsBright = false}) => TerminalTheme(
      cursor: const Color(0xFFFFFFFF),
      selection: const Color(0x80FFFFFF),
      foreground: const Color(0xFFCCCCCC),
      background: const Color(0xFF0C0C0C),
      black: const Color(0xFF000001),
      red: const Color(0xFF000002),
      green: const Color(0xFF000003),
      yellow: const Color(0xFF000004),
      blue: const Color(0xFF000005),
      magenta: const Color(0xFF000006),
      cyan: const Color(0xFF000007),
      white: const Color(0xFF000008),
      brightBlack: const Color(0xFF000009),
      brightRed: const Color(0xFF00000A),
      brightGreen: const Color(0xFF00000B),
      brightYellow: const Color(0xFF00000C),
      brightBlue: const Color(0xFF00000D),
      brightMagenta: const Color(0xFF00000E),
      brightCyan: const Color(0xFF00000F),
      brightWhite: const Color(0xFF000010),
      searchHitBackground: const Color(0xFFFFFF2B),
      searchHitBackgroundCurrent: const Color(0xFF31FF26),
      searchHitForeground: const Color(0xFF000000),
      boldIsBright: boldIsBright,
    );

/// The color the painter uses for the text of the first cell after [text]
/// (an escape sequence followed by a character) was written to a terminal.
Color _textColor(TerminalPainter painter, String text) {
  final terminal = Terminal();
  terminal.write(text);
  final line = terminal.buffer.lines[0];
  return painter.resolveForegroundColor(
    line.getForeground(0),
    bold: line.getAttributes(0) & CellFlags.bold != 0,
  );
}

TerminalPainter _painter(TerminalTheme theme) => TerminalPainter(
      theme: theme,
      textStyle: const TerminalStyle(),
      textScaler: TextScaler.noScaling,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('boldIsBright', () {
    test('is off unless the theme turns it on', () {
      expect(TerminalThemes.defaultTheme.boldIsBright, isFalse);
      expect(TerminalThemes.whiteOnBlack.boldIsBright, isFalse);
      final t = _theme();
      expect(t.boldIsBright, isFalse);
      final p = _painter(t);
      expect(_textColor(p, '\x1b[1;34mX'), t.blue);
    });

    test('bold text in each of the 8 normal colors uses the bright one', () {
      final t = _theme(boldIsBright: true);
      final p = _painter(t);
      final normal = [
        t.black,
        t.red,
        t.green,
        t.yellow,
        t.blue,
        t.magenta,
        t.cyan,
        t.white,
      ];
      final bright = [
        t.brightBlack,
        t.brightRed,
        t.brightGreen,
        t.brightYellow,
        t.brightBlue,
        t.brightMagenta,
        t.brightCyan,
        t.brightWhite,
      ];
      for (var i = 0; i < 8; i++) {
        // 30-37, and the same color as 256-color index i
        expect(_textColor(p, '\x1b[1;${30 + i}mX'), bright[i], reason: '$i');
        expect(_textColor(p, '\x1b[1;38;5;${i}mX'), bright[i], reason: '$i');
        // not bold: unchanged
        expect(_textColor(p, '\x1b[${30 + i}mX'), normal[i], reason: '$i');
        // bold set after the color gives the same result
        expect(_textColor(p, '\x1b[${30 + i}m\x1b[1mX'), bright[i],
            reason: '$i');
      }
    });

    test('only the 8 normal colors change', () {
      final t = _theme(boldIsBright: true);
      final p = _painter(t);
      // already bright: stays bright (not shifted again)
      expect(_textColor(p, '\x1b[1;94mX'), t.brightBlue);
      expect(_textColor(p, '\x1b[1;38;5;12mX'), t.brightBlue);
      // the rest of the 256-color palette
      final palette = PaletteBuilder(t).build();
      expect(_textColor(p, '\x1b[1;38;5;100mX'), palette[100]);
      // true color
      expect(_textColor(p, '\x1b[1;38;2;1;2;3mX'), const Color(0xFF010203));
      // the default foreground
      expect(_textColor(p, '\x1b[1mX'), t.foreground);
    });

    test('after a reset, a normal color is not brightened', () {
      final t = _theme(boldIsBright: true);
      final p = _painter(t);
      expect(_textColor(p, '\x1b[1;34m\x1b[0m\x1b[34mX'), t.blue);
    });
  });
}
