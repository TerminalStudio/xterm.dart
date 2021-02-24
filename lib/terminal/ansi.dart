import 'dart:collection';

import 'package:xterm/terminal/csi.dart';
import 'package:xterm/terminal/osc.dart';
import 'package:xterm/terminal/terminal.dart';

typedef AnsiHandler = void Function(Queue<int>, Terminal);

void ansiHandler(Queue<int> queue, Terminal terminal) {
  final charAfterEsc = String.fromCharCode(queue.removeFirst());

  final handler = _ansiHandlers[charAfterEsc];
  if (handler != null) {
    if (handler != csiHandler && handler != oscHandler) {
      terminal.debug.onEsc(charAfterEsc);
    }
    return handler(queue, terminal);
  }

  terminal.debug.onError('unsupported ansi sequence: $charAfterEsc');
}

final _ansiHandlers = <String, AnsiHandler>{
  '[': csiHandler,
  ']': oscHandler,
  '7': _ansiSaveCursorHandler,
  '8': _ansiRestoreCursorHandler,
  'D': _ansiIndexHandler,
  'E': _ansiNextLineHandler,
  'H': _ansiTabSetHandler,
  'M': _ansiReverseIndexHandler,
  'P': _unsupportedHandler, // Sixel
  'c': _unsupportedHandler,
  '#': _unsupportedHandler,
  '(': _scsHandler(0), //  G0
  ')': _scsHandler(1), //  G1
  '*': _voidHandler(1), // TODO: G2 (vt220)
  '+': _voidHandler(1), // TODO: G3 (vt220)
  '>': _voidHandler(0), // TODO: Normal Keypad
  '=': _voidHandler(0), // TODO: Application Keypad
};

AnsiHandler _voidHandler(int sequenceLength) {
  return (queue, terminal) {
    return queue.take(sequenceLength);
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

void _ansiIndexHandler(Queue<int> queue, Terminal terminal) {
  terminal.buffer.index();
}

void _ansiReverseIndexHandler(Queue<int> queue, Terminal terminal) {
  terminal.buffer.reverseIndex();
}

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
