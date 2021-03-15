import 'dart:collection';

import 'package:xterm/terminal/csi.dart';
import 'package:xterm/terminal/osc.dart';
import 'package:xterm/terminal/terminal.dart';

typedef AnsiHandler = void Function(Queue<int>, Terminal);

void ansiHandler(Queue<int> queue, Terminal terminal) {
  final charAfterEsc = queue.removeFirst();

  final handler = _ansiHandlers[charAfterEsc];
  if (handler != null) {
    if (handler != csiHandler && handler != oscHandler) {
      terminal.debug.onEsc(charAfterEsc);
    }
    return handler(queue, terminal);
  }

  terminal.debug.onError('unsupported ansi sequence: $charAfterEsc');
}

final _ansiHandlers = <int, AnsiHandler>{
  '['.codeUnitAt(0): csiHandler,
  ']'.codeUnitAt(0): oscHandler,
  '7'.codeUnitAt(0): _ansiSaveCursorHandler,
  '8'.codeUnitAt(0): _ansiRestoreCursorHandler,
  'D'.codeUnitAt(0): _ansiIndexHandler,
  'E'.codeUnitAt(0): _ansiNextLineHandler,
  'H'.codeUnitAt(0): _ansiTabSetHandler,
  'M'.codeUnitAt(0): _ansiReverseIndexHandler,
  'P'.codeUnitAt(0): _unsupportedHandler, // Sixel
  'c'.codeUnitAt(0): _unsupportedHandler,
  '#'.codeUnitAt(0): _unsupportedHandler,
  '('.codeUnitAt(0): _scsHandler(0), //  SCS - G0
  ')'.codeUnitAt(0): _scsHandler(1), //  SCS - G1
  '*'.codeUnitAt(0): _voidHandler(1), // TODO: G2 (vt220)
  '+'.codeUnitAt(0): _voidHandler(1), // TODO: G3 (vt220)
  '>'.codeUnitAt(0): _voidHandler(0), // TODO: Normal Keypad
  '='.codeUnitAt(0): _voidHandler(0), // TODO: Application Keypad
};

AnsiHandler _voidHandler(int sequenceLength) {
  return (queue, terminal) {
    queue.take(sequenceLength);
  };
}

void _unsupportedHandler(Queue<int> queue, Terminal terminal) async {
  // print('unimplemented ansi sequence.');
}

void _ansiSaveCursorHandler(Queue<int> queue, Terminal terminal) {
  terminal.buffer.saveCursor();
}

void _ansiRestoreCursorHandler(Queue<int> queue, Terminal terminal) {
  terminal.buffer.restoreCursor();
}

/// https://vt100.net/docs/vt100-ug/chapter3.html#IND IND – Index
///
/// ESC D  
///
/// This sequence causes the active position to move downward one line without
/// changing the column position. If the active position is at the bottom
/// margin, a scroll up is performed.
void _ansiIndexHandler(Queue<int> queue, Terminal terminal) {
  terminal.buffer.index();
}

void _ansiReverseIndexHandler(Queue<int> queue, Terminal terminal) {
  terminal.buffer.reverseIndex();
}

/// SCS – Select Character Set
///
/// The appropriate G0 and G1 character sets are designated from one of the five
/// possible character sets. The G0 and G1 sets are invoked by the codes SI and
/// SO (shift in and shift out) respectively.
AnsiHandler _scsHandler(int which) {
  return (Queue<int> queue, Terminal terminal) {
    final name = String.fromCharCode(queue.removeFirst());
    terminal.buffer.charset.designate(which, name);
  };
}

void _ansiNextLineHandler(Queue<int> queue, Terminal terminal) {
  terminal.buffer.newLine();
  terminal.buffer.setCursorX(0);
}

void _ansiTabSetHandler(Queue<int> queue, Terminal terminal) {
  terminal.tabSetAtCursor();
}
