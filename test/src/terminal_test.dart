import 'package:test/test.dart';
import 'package:xterm/core.dart';

void main() {
  group('Terminal.resize', () {
    test('a throwing onResize leaves the terminal at the new size', () {
      // What an SSH session with a closed transport does. Called before the
      // buffers were resized, the throw left them at the old size while the
      // view had already moved on, and nothing retried it.
      final terminal = Terminal(maxLines: 100)
        ..onResize = (_, _, _, _) => throw StateError('closed');

      expect(() => terminal.resize(40, 30), throwsStateError);

      expect(terminal.viewWidth, 40);
      expect(terminal.viewHeight, 30);
      expect(terminal.buffer.height, 30);
      // Writing to the last row reads the rows the new size has.
      terminal.write('\x1b[30;1H${'x' * 40}\n');
    });

    test('onResize is told the size the terminal now is', () {
      final seen = <(int, int, int, int)>[];
      final terminal = Terminal()
        ..onResize = (w, h, pw, ph) {
          seen.add((w, h, pw, ph));
        };

      terminal.resize(100, 40, 800, 600);

      expect(seen, [(100, 40, 800, 600)]);
    });
  });

  group('Terminal.write', () {
    test('empty writes do not notify listeners', () {
      final terminal = Terminal();
      var notifications = 0;
      terminal.addListener(() {
        notifications++;
      });

      terminal.write('');
      expect(notifications, 0);

      terminal.write('X');
      expect(notifications, 1);
    });
  });

  group('Terminal.textInput', () {
    test('empty text input and paste do not emit output', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);

      terminal.textInput('');
      terminal.paste('');
      terminal.write('\x1b[?2004h');
      terminal.paste('');

      expect(output, isEmpty);
    });

    test('paste emits bracketed paste only for non-empty text', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);

      terminal.write('\x1b[?2004h');
      terminal.paste('abc');

      expect(output, ['\x1b[200~abc\x1b[201~']);
    });
  });

  group('Terminal.charInput', () {
    test('alt sends ESC and the character, lower case for a letter', () {
      final out = <String>[];
      final t = Terminal(
        platform: TerminalTargetPlatform.linux,
        onOutput: out.add,
      );
      t.keyInput(TerminalKey.keyA, alt: true);
      t.charInput('b'.codeUnitAt(0), alt: true);
      t.charInput('.'.codeUnitAt(0), alt: true);
      expect(out, ['\x1ba', '\x1bb', '\x1b.']);
    });

    test('ctrl maps uppercase and lowercase letters to C0 controls', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);

      expect(terminal.charInput('A'.codeUnitAt(0), ctrl: true), isTrue);
      expect(terminal.charInput('a'.codeUnitAt(0), ctrl: true), isTrue);
      expect(terminal.charInput('Z'.codeUnitAt(0), ctrl: true), isTrue);
      expect(terminal.charInput('z'.codeUnitAt(0), ctrl: true), isTrue);

      expect(output, ['\x01', '\x01', '\x1a', '\x1a']);
    });
  });

  group('Terminal.keyInput', () {
    test('arrows carry the modifiers held', () {
      final out = <String>[];
      final t = Terminal(
        platform: TerminalTargetPlatform.linux,
        onOutput: out.add,
      );
      t.keyInput(TerminalKey.arrowUp, shift: true);
      t.keyInput(TerminalKey.arrowUp, alt: true);
      t.keyInput(TerminalKey.arrowUp, ctrl: true);
      t.keyInput(TerminalKey.arrowDown, ctrl: true, alt: true);
      expect(out, ['\x1b[1;2A', '\x1b[1;3A', '\x1b[1;5A', '\x1b[1;7B']);
    });
  });

  group('Terminal.inputHandler', () {
    test('can be set to null', () {
      final terminal = Terminal(inputHandler: null);
      expect(() => terminal.keyInput(TerminalKey.keyA), returnsNormally);
    });

    test('can be changed', () {
      final handler1 = _TestInputHandler();
      final handler2 = _TestInputHandler();
      final terminal = Terminal(inputHandler: handler1);

      terminal.keyInput(TerminalKey.keyA);
      expect(handler1.events, isNotEmpty);

      terminal.inputHandler = handler2;

      terminal.keyInput(TerminalKey.keyA);
      expect(handler2.events, isNotEmpty);
    });
  });

  group('Terminal.mouseInput', () {
    test('can handle mouse events', () {
      final output = <String>[];

      final terminal = Terminal(onOutput: output.add);

      terminal.mouseInput(
        TerminalMouseButton.left,
        TerminalMouseButtonState.down,
        CellOffset(10, 10),
      );

      expect(output, isEmpty);

      // enable mouse reporting
      terminal.write('\x1b[?1000h');

      terminal.mouseInput(
        TerminalMouseButton.left,
        TerminalMouseButtonState.down,
        CellOffset(10, 10),
      );

      expect(output, ['\x1B[M ++']);
    });

    test('reports a move with a button held from mode 1002 on', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);

      void move(TerminalMouseButton button) {
        terminal.mouseInput(
          button,
          TerminalMouseButtonState.motion,
          CellOffset(1, 1),
        );
      }

      terminal.write('\x1b[?1000h\x1b[?1006h');
      move(TerminalMouseButton.left);
      expect(output, isEmpty);

      terminal.write('\x1b[?1002h');
      move(TerminalMouseButton.left);
      move(TerminalMouseButton.none);
      expect(output, ['\x1b[<32;2;2M']);

      output.clear();
      terminal.write('\x1b[?1003h');
      move(TerminalMouseButton.none);
      expect(output, ['\x1b[<35;2;2M']);
    });

    test('alternate scroll mode maps wheel to cursor keys in alt buffer', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);

      terminal.write('\x1b[?1007h\x1b[?1047h');

      terminal.mouseInput(
        TerminalMouseButton.wheelUp,
        TerminalMouseButtonState.down,
        CellOffset(0, 0),
      );
      terminal.mouseInput(
        TerminalMouseButton.wheelDown,
        TerminalMouseButtonState.down,
        CellOffset(0, 0),
      );

      expect(output, ['\x1b[A', '\x1b[B']);
    });

    test('mouse reporting takes precedence over alternate scroll mode', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);

      terminal.write('\x1b[?1007h\x1b[?1047h\x1b[?1000h');

      terminal.mouseInput(
        TerminalMouseButton.wheelUp,
        TerminalMouseButtonState.down,
        CellOffset(0, 0),
      );

      expect(output, ['\x1b[M`!!']);
    });

    test('ignores events outside the viewport', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add)..resize(4, 2);

      terminal.write('\x1b[?1000h\x1b[?1007h\x1b[?1047h');

      expect(
        terminal.mouseInput(
          TerminalMouseButton.left,
          TerminalMouseButtonState.down,
          CellOffset(-1, 0),
        ),
        isFalse,
      );
      expect(
        terminal.mouseInput(
          TerminalMouseButton.left,
          TerminalMouseButtonState.down,
          CellOffset(4, 0),
        ),
        isFalse,
      );
      expect(
        terminal.mouseInput(
          TerminalMouseButton.wheelUp,
          TerminalMouseButtonState.down,
          CellOffset(0, 2),
        ),
        isFalse,
      );

      expect(output, isEmpty);
    });
  });

  group('Terminal.indexing', () {
    test('DECBI and DECFI shift line content at horizontal edges', () {
      final terminal = Terminal();
      terminal.resize(4, 2);

      terminal.write('abcd\r\x1b6');
      expect(terminal.buffer.lines[0].getCodePoint(0), 0);
      expect(terminal.buffer.lines[0].getCodePoint(1), 'a'.codeUnitAt(0));
      expect(terminal.buffer.cursorX, 0);

      terminal.write('\x1bcabcd\x1b[4G\x1b9');
      expect(terminal.buffer.lines[0].toString(), 'bcd');
      expect(terminal.buffer.cursorX, 3);
    });

    test('RI clears pending wrap before moving up', () {
      final terminal = Terminal();
      terminal.resize(4, 3);

      terminal.write('\nabcd\x1bMX');

      expect(terminal.buffer.lines[0].getCodePoint(0), 0);
      expect(terminal.buffer.lines[0].getCodePoint(3), 'X'.codeUnitAt(0));
      expect(terminal.buffer.lines[1].getText(), 'abcd');
      expect(terminal.buffer.cursorX, 3);
      expect(terminal.buffer.cursorY, 0);
    });
  });

  group('Terminal.charset', () {
    test('UK charset maps number sign to pound sign', () {
      final terminal = Terminal();

      terminal.write('\x1b)A\x0e#\x0f#');

      expect(terminal.buffer.lines[0].toString(), '£#');
    });

    test('coding system designation is consumed', () {
      final terminal = Terminal();

      terminal.write('\x1b%GZ');

      expect(terminal.buffer.lines[0].toString(), 'Z');
    });

    test('zero-width combining characters do not advance the cursor', () {
      final terminal = Terminal();

      terminal.write('e\u0301X');

      expect(terminal.buffer.lines[0].getText(), 'e\u0301X');
      expect(terminal.buffer.cursorX, 2);
    });

    test('REP repeats the displayed character after charset changes', () {
      final terminal = Terminal();

      terminal.write('\x1b)A\x0e#\x0f\x1b[b');

      expect(terminal.buffer.lines[0].getText(), '££');
    });

    test('restore cursor keeps saved charset snapshot immutable', () {
      final terminal = Terminal();

      terminal.write('\x1b)A\x0e\x1b7\x1b)B\x1b8#\x1b)B\x1b8#');

      expect(terminal.buffer.lines[0].getText(), '£');
    });

    test('single shift uses G2 or G3 for one character only', () {
      final terminal = Terminal();

      terminal.write('\x1b*0\x1b+B\x1bNq\x1bNq\x1bOq');

      expect(terminal.buffer.lines[0].toString(), '──q');
    });
  });

  group('Terminal.saveRestoreCursor', () {
    test('DECSC and DECRC preserve origin and autowrap modes', () {
      final terminal = Terminal();

      terminal.write('\x1b[?6h\x1b[?7l\x1b7\x1b[?6l\x1b[?7h\x1b8');

      expect(terminal.originMode, isTrue);
      expect(terminal.autoWrapMode, isFalse);
    });

    test('restore clamps saved cursor after resize', () {
      final terminal = Terminal();
      terminal.resize(10, 10);

      terminal.write('\x1b[10;10H\x1b7');
      terminal.resize(4, 4);
      terminal.write('\x1b8');

      expect(terminal.buffer.cursorX, 3);
      expect(terminal.buffer.cursorY, 3);
    });

    test('CSI s and u preserve cursor and style', () {
      final terminal = Terminal();

      terminal.write('\x1b[2;3H\x1b[31m\x1b[s\x1b[4;5H\x1b[32m\x1b[uX');

      expect(terminal.buffer.cursorX, 3);
      expect(terminal.buffer.cursorY, 1);
      expect(terminal.buffer.lines[1].getCodePoint(2), 'X'.codeUnitAt(0));
      expect(
        terminal.buffer.lines[1].getForeground(2),
        terminal.cursor.foreground,
      );
    });
  });

  group('Terminal.backspaceReturn', () {
    test('BS clears pending wrap and moves to the last column', () {
      final terminal = Terminal();
      terminal.resize(4, 2);

      terminal.write('abcd\bX');

      expect(terminal.buffer.lines[0].getText(), 'abcX');
      expect(terminal.buffer.cursorX, 3);
      expect(terminal.buffer.cursorY, 0);
    });

    test('BS at start of wrapped line returns to previous line', () {
      final terminal = Terminal();
      terminal.resize(4, 2);

      terminal.write('abcdE\b\bX');

      expect(terminal.buffer.lines[0].getText(), 'abcX');
      expect(terminal.buffer.lines[1].getText(), 'E');
      expect(terminal.buffer.lines[1].isWrapped, isFalse);
      expect(terminal.buffer.cursorX, 3);
      expect(terminal.buffer.cursorY, 0);
    });
  });

  group('Terminal.lineFeedMode', () {
    test('LNM makes LF move to column zero', () {
      final terminal = Terminal();

      terminal.write('ab\nX');
      expect(terminal.buffer.lines[1].getCodePoint(0), 0);
      expect(terminal.buffer.lines[1].getCodePoint(1), 0);
      expect(terminal.buffer.lines[1].getCodePoint(2), 'X'.codeUnitAt(0));

      terminal.resetTerminal();
      terminal.write('\x1b[20hab\nX');
      expect(terminal.buffer.lines[1].getCodePoint(0), 'X'.codeUnitAt(0));
    });

    test('LF clears pending wrap without adding an extra line', () {
      final terminal = Terminal();
      terminal.resize(4, 3);

      terminal.write('abcd\nX');

      expect(terminal.buffer.lines[0].getText(), 'abcd');
      expect(terminal.buffer.lines[1].getCodePoint(3), 'X'.codeUnitAt(0));
      expect(terminal.buffer.lines[2].getText(), isEmpty);
      expect(terminal.buffer.cursorX, 3);
      expect(terminal.buffer.cursorY, 1);
    });
  });

  group('Terminal.c1Controls', () {
    test('8-bit HTS sets tab stop', () {
      final terminal = Terminal();

      terminal.write('\x1b[3G\u0088\r\tX');

      expect(terminal.buffer.cursorX, 3);
      expect(terminal.buffer.currentLine.getCodePoint(2), 'X'.codeUnitAt(0));
    });
  });

  group('Terminal.colors', () {
    test(
      'invisible strikethrough and overline SGR attributes are stored in cells',
      () {
        final terminal = Terminal();

        terminal.write('\x1b[8;9;53mX');

        final flags = terminal.buffer.lines[0].getAttributes(0);
        expect(flags & CellAttr.invisible, CellAttr.invisible);
        expect(flags & CellAttr.strikethrough, CellAttr.strikethrough);
        expect(flags & CellAttr.overline, CellAttr.overline);
      },
    );

    test('extended SGR color values are clamped to valid ranges', () {
      final terminal = Terminal();

      terminal.write('\x1b[38;2;300;1;999m\x1b[48;5;300m');

      expect(
        terminal.cursor.foreground,
        CellColor.rgb | (255 << 16) | (1 << 8) | 255,
      );
      expect(terminal.cursor.background, CellColor.palette | 255);
    });
  });

  group('Terminal.displayModes', () {
    test('DECSCNM toggles reverse display mode', () {
      final terminal = Terminal();

      terminal.write('\x1b[?5h');
      expect(terminal.reverseDisplayMode, isTrue);

      terminal.write('\x1b[?5l');
      expect(terminal.reverseDisplayMode, isFalse);
    });

    test('DECCOLM is ignored, so reset keeps the width and the screen', () {
      final terminal = Terminal();
      terminal.resize(10, 3);

      terminal.write('abc\x1b[?3h');
      expect(terminal.viewWidth, 10);
      expect(terminal.buffer.lines[0].getText(), 'abc');

      terminal.write('\x1b[?3l');
      expect(terminal.viewWidth, 10);
      expect(terminal.buffer.lines[0].getText(), 'abc');
    });
  });

  group('Terminal.cursorShape', () {
    test('DECSCUSR sets and resets cursor type override', () {
      final terminal = Terminal();

      terminal.write('\x1b[5 q');
      expect(terminal.cursorTypeOverride, TerminalCursorType.verticalBar);
      expect(terminal.cursorBlinkMode, isTrue);

      terminal.write('\x1b[4 q');
      expect(terminal.cursorTypeOverride, TerminalCursorType.underline);
      expect(terminal.cursorBlinkMode, isFalse);

      terminal.write('\x1b[ q');
      expect(terminal.cursorTypeOverride, isNull);
      expect(terminal.cursorBlinkMode, isFalse);
    });
  });

  group('Terminal.focusInput', () {
    test('reports focus changes only when enabled', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);

      terminal.focusInput(true);
      terminal.write('\x1b[?1004h');
      terminal.focusInput(true);
      terminal.focusInput(false);
      terminal.write('\x1b[?1004l');
      terminal.focusInput(true);

      expect(output, ['\x1b[I', '\x1b[O']);
    });
  });

  group('Terminal.deviceStatusReport', () {
    test('CPR reports one-based cursor position', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);

      terminal.write('\x1b[3;4H\x1b[6n\x1b[?6n');

      expect(output, ['\x1b[3;4R', '\x1b[?3;4R']);
    });

    test('CPR reports the last column while wrap is pending', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add)..resize(4, 2);

      terminal.write('abcd\x1b[6n\x1b[?6nX');

      expect(output, ['\x1b[1;4R', '\x1b[?1;4R']);
      expect(terminal.buffer.lines[0].toString(), 'abcd');
      expect(terminal.buffer.lines[1].toString(), 'X');
    });
  });

  group('Terminal.softResetTerminal', () {
    test('DECSTR resets modes and margins without clearing the buffer', () {
      final terminal = Terminal();

      terminal.write(
        'abc\x1b[3;6r\x1b[?6h\x1b[?1000h\x1b[4h\x1b[31m\x1b)0\x0e\x1b[2;2H',
      );
      terminal.write('\x1b[!p#');

      // The cursor stays where origin mode put it, at the margin's second
      // row: only the saved cursor goes home.
      expect(terminal.buffer.lines[0].toString(), 'abc');
      expect(terminal.buffer.lines[3].toString(), ' #');
      expect(terminal.insertMode, isFalse);
      expect(terminal.originMode, isFalse);
      expect(terminal.mouseMode, MouseMode.none);
      expect(terminal.cursor.foreground, 0);
      expect(terminal.buffer.marginTop, 0);
      expect(terminal.buffer.marginBottom, terminal.viewHeight - 1);
      expect(terminal.buffer.cursorX, 2);
      expect(terminal.buffer.cursorY, 3);
    });

    test('RIS still sends the cursor home', () {
      final terminal = Terminal();

      terminal.write('abc\x1b[3;4H\x1bc#');

      expect(terminal.buffer.lines[0].toString(), '#');
      expect(terminal.buffer.cursorX, 1);
      expect(terminal.buffer.cursorY, 0);
    });
  });

  group('Terminal.screenAlignmentPattern', () {
    test('DECALN fills the viewport with E using current style', () {
      final terminal = Terminal();
      terminal.resize(4, 2);

      terminal.write('\x1b[31m\x1b#8');

      expect(terminal.buffer.lines[0].toString(), 'EEEE');
      expect(terminal.buffer.lines[1].toString(), 'EEEE');
      expect(
        terminal.buffer.lines[0].getForeground(0),
        terminal.cursor.foreground,
      );
    });
  });

  group('Terminal.altBuffer', () {
    test('clear alternate buffer resets its cursor and state', () {
      final terminal = Terminal();

      terminal.write('\x1b[?1047h\x1b[10;10Halt\x1b[?1047l\x1b[?1049h');

      expect(terminal.isUsingAltBuffer, isTrue);
      expect(terminal.buffer.cursorX, 0);
      expect(terminal.buffer.cursorY, 0);
      expect(terminal.buffer.lines[9].toString(), isEmpty);
    });
  });

  group('Terminal.resetTerminal', () {
    test('RIS resets buffers modes style and tab stops', () {
      final terminal = Terminal();

      terminal.write('abc\x1b[2G\x1b[1;31m\x1b[4h\x1b[?6h\x1b[?1000h');
      terminal.write('\x1b[5G\x1bH\x1b[?1049halt\x1bc\tX');

      expect(terminal.isUsingAltBuffer, isFalse);
      expect(terminal.insertMode, isFalse);
      expect(terminal.originMode, isFalse);
      expect(terminal.mouseMode, MouseMode.none);
      expect(terminal.cursor.attrs, 0);
      expect(terminal.cursor.foreground, 0);
      expect(terminal.buffer.cursorX, 9);
      expect(terminal.buffer.currentLine.getCodePoint(8), 'X'.codeUnitAt(0));
      expect(terminal.mainBuffer.lines[0].getCodePoint(8), 'X'.codeUnitAt(0));
      expect(terminal.altBuffer.lines[0].toString(), isEmpty);
    });
  });

  group('Terminal.lineEditing', () {
    test('non-positive line editing counts are no-ops', () {
      final terminal = Terminal();
      terminal.resize(4, 3);
      terminal.write('abcd\nefgh\r\x1b[A');
      final before = [
        terminal.buffer.lines[0].data.toList(),
        terminal.buffer.lines[1].data.toList(),
        terminal.buffer.lines[2].data.toList(),
      ];

      terminal.insertLines(0);
      terminal.insertLines(-1);
      terminal.deleteLines(0);
      terminal.deleteLines(-1);
      terminal.eraseChars(0);
      terminal.eraseChars(-1);

      expect(terminal.buffer.lines[0].data.toList(), before[0]);
      expect(terminal.buffer.lines[1].data.toList(), before[1]);
      expect(terminal.buffer.lines[2].data.toList(), before[2]);
    });
  });

  group('Terminal.deleteChars', () {
    test('DCH in the pending-wrap column deletes the last cell', () {
      // As xterm and xterm.js do: the pending wrap is dropped and the cursor
      // is on the last column.
      final terminal = Terminal();
      terminal.resize(4, 2);

      terminal.write('abcd\x1b[P');

      expect(terminal.buffer.lines[0].getText().trimRight(), 'abc');
      expect(terminal.buffer.cursorX, 3);
      expect(terminal.buffer.cursorY, 0);
    });

    test('non-positive counts are no-ops', () {
      final terminal = Terminal();
      terminal.write('abcd\r');
      final snapshot = terminal.buffer.lines[0].data.toList();

      terminal.deleteChars(0);
      terminal.deleteChars(-1);

      expect(terminal.buffer.lines[0].data.toList(), snapshot);
    });
  });

  group('Terminal.insertBlankChars', () {
    test('non-positive counts are no-ops', () {
      final terminal = Terminal();
      terminal.write('abcd\r');
      final snapshot = terminal.buffer.lines[0].data.toList();

      terminal.insertBlankChars(0);
      terminal.insertBlankChars(-1);

      expect(terminal.buffer.lines[0].data.toList(), snapshot);
    });
  });

  group('Terminal.autoWrapMode', () {
    test('resize works when maxLines is smaller than the viewport', () {
      final terminal = Terminal(maxLines: 1);

      terminal.resize(4, 3);
      terminal.write('ok');

      expect(terminal.buffer.lines[0].getText(), 'ok');
    });

    test(
      'wide characters wrap before the last column when autowrap is enabled',
      () {
        final terminal = Terminal();
        terminal.resize(4, 3);

        terminal.write('abc界');

        expect(terminal.buffer.lines[0].getText(), 'abc');
        expect(terminal.buffer.lines[1].getText(), '界');
        expect(terminal.buffer.lines[1].isWrapped, isTrue);
        expect(terminal.buffer.cursorX, 2);
        expect(terminal.buffer.cursorY, 1);
      },
    );

    test('DECAWM disabled overwrites last column instead of wrapping', () {
      final terminal = Terminal();
      terminal.resize(4, 2);

      terminal.write('\x1b[?7labcdZ');

      expect(terminal.buffer.lines[0].toString(), 'abcZ');
      expect(terminal.buffer.lines[1].toString(), isEmpty);
      expect(terminal.buffer.cursorX, 3);
      expect(terminal.buffer.cursorY, 0);
    });

    test('overwriting wide character cells clears stale fragments', () {
      final terminal = Terminal();
      terminal.resize(4, 2);

      terminal.write('界\x1b[2GA');
      expect(terminal.buffer.lines[0].getCodePoint(0), 0);
      expect(terminal.buffer.lines[0].getCodePoint(1), 'A'.codeUnitAt(0));

      terminal.write('\r界\x1b[1GB');
      expect(terminal.buffer.lines[0].getCodePoint(0), 'B'.codeUnitAt(0));
      expect(terminal.buffer.lines[0].getCodePoint(1), 0);
    });

    test(
      'wide characters at last column do not wrap when DECAWM is disabled',
      () {
        final terminal = Terminal();
        terminal.resize(4, 2);

        terminal.write('\x1b[?7labc界');

        // Untrimmed, because the space in the last column is the assertion:
        // the wide character did not fit and did not wrap, so the cell was
        // blanked rather than written to.
        expect(terminal.buffer.lines[0].getText(null, null, false), 'abc ');
        expect(terminal.buffer.lines[1].getText(), '');
        expect(terminal.buffer.cursorX, 3);
        expect(terminal.buffer.cursorY, 0);
      },
    );
  });

  group('Terminal.insertMode', () {
    test('IRM inserts cells instead of replacing them', () {
      final terminal = Terminal();

      terminal.write('abc\x1b[2G\x1b[4hX\x1b[4lY');

      expect(terminal.buffer.currentLine.toString(), 'aXYc');
    });

    test('IRM inserts wide characters without erasing shifted content', () {
      final terminal = Terminal();
      terminal.resize(6, 2);

      terminal.write('abcd\x1b[2G\x1b[4h界');

      expect(terminal.buffer.currentLine.getText(), 'a界bcd');
    });
  });

  group('Terminal.cursorMovement', () {
    test('vertical cursor movement clears pending wrap', () {
      final terminal = Terminal();
      terminal.resize(4, 3);

      terminal.write('\nabcd\x1b[AX');

      expect(terminal.buffer.lines[0].getCodePoint(3), 'X'.codeUnitAt(0));
      expect(terminal.buffer.lines[1].getText(), 'abcd');
      expect(terminal.buffer.lines[2].getText(), isEmpty);
      expect(terminal.buffer.cursorX, 3);
      expect(terminal.buffer.cursorY, 0);
    });

    test('absolute vertical positioning clears pending wrap', () {
      final terminal = Terminal();
      terminal.resize(4, 3);

      terminal.write('\nabcd\x1b[1dX');

      expect(terminal.buffer.lines[0].getCodePoint(3), 'X'.codeUnitAt(0));
      expect(terminal.buffer.lines[1].getText(), 'abcd');
      expect(terminal.buffer.lines[2].getText(), isEmpty);
      expect(terminal.buffer.cursorX, 3);
      expect(terminal.buffer.cursorY, 0);
    });
  });

  group('Terminal.originMode', () {
    test('DECOM moves cursor home relative to margins', () {
      final terminal = Terminal();

      terminal.write('\x1b[3;6r\x1b[?6h');

      expect(terminal.buffer.cursorX, 0);
      expect(terminal.buffer.cursorY, 2);

      terminal.write('\x1b[?6l');

      expect(terminal.buffer.cursorX, 0);
      expect(terminal.buffer.cursorY, 0);
    });

    test('DECOM constrains relative cursor movement to margins', () {
      final terminal = Terminal();
      terminal.resize(10, 8);

      terminal.write('\x1b[3;6r\x1b[?6h\x1b[999B');
      expect(terminal.buffer.cursorY, 5);

      terminal.write('\x1b[999A');
      expect(terminal.buffer.cursorY, 2);
    });

    test('DECOM makes VPA relative to margins', () {
      final terminal = Terminal();
      terminal.resize(10, 8);

      terminal.write('\x1b[3;6r\x1b[?6h\x1b[2d');

      expect(terminal.buffer.cursorY, 3);
    });
  });

  group('Terminal.margins', () {
    test('DECSTBM moves cursor home and ignores invalid regions', () {
      final terminal = Terminal();

      terminal.write('\x1b[10;10H\x1b[3;6r');

      expect(terminal.buffer.marginTop, 2);
      expect(terminal.buffer.marginBottom, 5);
      expect(terminal.buffer.cursorX, 0);
      expect(terminal.buffer.cursorY, 0);

      terminal.write('\x1b[7;4r');

      expect(terminal.buffer.marginTop, 2);
      expect(terminal.buffer.marginBottom, 5);
    });
  });

  group('Terminal.tabStops', () {
    test('ESC H sets a tab stop at the current cursor column', () {
      final terminal = Terminal();

      terminal.write('\x1b[3G\x1bH\r\tX');

      expect(terminal.buffer.cursorX, 3);
      expect(terminal.buffer.currentLine.getCodePoint(2), 'X'.codeUnitAt(0));
    });

    test('CBT moves cursor backward by tab stops', () {
      final terminal = Terminal();

      terminal.write('\x1b[20G\x1b[Z');
      expect(terminal.buffer.cursorX, 16);

      terminal.write('\x1b[2Z');
      expect(terminal.buffer.cursorX, 0);
    });

    test(
      'HT without following tab stop moves to last column without wrapping',
      () {
        final terminal = Terminal()..resize(4, 2);

        terminal.write('abc\t');

        expect(terminal.buffer.lines[0].toString(), 'abc');
        expect(terminal.buffer.lines[1].toString(), isEmpty);
        expect(terminal.buffer.cursorX, 3);
        expect(terminal.buffer.cursorY, 0);

        terminal.write('X');
        expect(terminal.buffer.lines[0].toString(), 'abcX');
        expect(terminal.buffer.lines[1].toString(), isEmpty);
      },
    );
  });

  group('Terminal.reflowEnabled', () {
    test('prevents reflow when set to false', () {
      final terminal = Terminal(reflowEnabled: false);

      terminal.write('Hello World');
      terminal.resize(5, 5);

      expect(terminal.buffer.lines[0].toString(), 'Hello');
      expect(terminal.buffer.lines[1].toString(), isEmpty);
    });

    test('preserves hidden cells when reflow is disabled', () {
      final terminal = Terminal(reflowEnabled: false);

      terminal.write('Hello World');
      terminal.resize(5, 5);
      terminal.resize(20, 5);

      expect(terminal.buffer.lines[0].toString(), 'Hello World');
      expect(terminal.buffer.lines[1].toString(), isEmpty);
    });

    test('can be set at runtime', () {
      final terminal = Terminal(reflowEnabled: true);

      terminal.resize(5, 5);
      terminal.write('Hello World');
      terminal.reflowEnabled = false;
      terminal.resize(20, 5);

      expect(terminal.buffer.lines[0].toString(), 'Hello');
      expect(terminal.buffer.lines[1].toString(), ' Worl');
      expect(terminal.buffer.lines[2].toString(), 'd');
    });
  });

  group('Terminal.mouseInput', () {
    test('applys to the main buffer', () {
      final terminal = Terminal(wordSeparators: {'z'.codeUnitAt(0)});

      expect(terminal.mainBuffer.wordSeparators, contains('z'.codeUnitAt(0)));
    });

    test('applys to the alternate buffer', () {
      final terminal = Terminal(wordSeparators: {'z'.codeUnitAt(0)});

      expect(terminal.altBuffer.wordSeparators, contains('z'.codeUnitAt(0)));
    });
  });

  group('Terminal.onPrivateOSC', () {
    test(r'works with \a end', () {
      String? lastCode;
      List<String>? lastData;

      final terminal = Terminal(
        onPrivateOSC: (String code, List<String> data) {
          lastCode = code;
          lastData = data;
        },
      );

      terminal.write('\x1b]6\x07');

      expect(lastCode, '6');
      expect(lastData, []);

      terminal.write('\x1b]66;hello world\x07');

      expect(lastCode, '66');
      expect(lastData, ['hello world']);

      terminal.write('\x1b]666;hello;world\x07');

      expect(lastCode, '666');
      expect(lastData, ['hello', 'world']);

      terminal.write('\x1b]hello;world\x07');

      expect(lastCode, 'hello');
      expect(lastData, ['world']);
    });

    test(r'works with \x1b\ end', () {
      String? lastCode;
      List<String>? lastData;

      final terminal = Terminal(
        onPrivateOSC: (String code, List<String> data) {
          lastCode = code;
          lastData = data;
        },
      );

      terminal.write('\x1b]6\x1b\\');

      expect(lastCode, '6');
      expect(lastData, []);

      terminal.write('\x1b]66;hello world\x1b\\');

      expect(lastCode, '66');
      expect(lastData, ['hello world']);

      terminal.write('\x1b]666;hello;world\x1b\\');

      expect(lastCode, '666');
      expect(lastData, ['hello', 'world']);

      terminal.write('\x1b]hello;world\x1b\\');

      expect(lastCode, 'hello');
      expect(lastData, ['world']);
    });

    test('ESC without backslash ends an OSC and starts its own sequence', () {
      String? title;
      final terminal = Terminal(onTitleChange: (value) => title = value);

      terminal.write('\x1b]2;hello\x1b[31mRED\x07after');

      expect(title, 'hello');
      expect(terminal.buffer.lines[0].getText().trimRight(), 'REDafter');
      expect(terminal.cursor.foreground, isNot(0));
    });

    test('common OSC preserves semicolons in payload', () {
      String? title;
      String? icon;
      final terminal = Terminal(
        onTitleChange: (value) => title = value,
        onIconChange: (value) => icon = value,
      );

      terminal.write('\x1b]0;hello;world\x07');

      expect(title, 'hello;world');
      expect(icon, 'hello;world');
    });

    test('do not receive common osc', () {
      String? lastCode;
      List<String>? lastData;

      final terminal = Terminal(
        onPrivateOSC: (String code, List<String> data) {
          lastCode = code;
          lastData = data;
        },
      );

      terminal.write('\x1b]0;hello world\x07');

      expect(lastCode, isNull);
      expect(lastData, isNull);
    });

    test('ignores empty OSC sequences', () {
      String? lastCode;
      List<String>? lastData;
      final terminal = Terminal(
        onPrivateOSC: (String code, List<String> data) {
          lastCode = code;
          lastData = data;
        },
      );

      terminal.write('\x1b]\x07\x1b]\x1b\\');

      expect(lastCode, isNull);
      expect(lastData, isNull);
    });
  });
}

class _TestInputHandler implements TerminalInputHandler {
  final events = <TerminalKeyboardEvent>[];

  @override
  String? call(TerminalKeyboardEvent event) {
    events.add(event);
    return null;
  }
}
