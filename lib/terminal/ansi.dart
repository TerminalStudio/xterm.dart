import 'dart:async';

import 'package:async/async.dart';
import 'package:xterm/terminal/csi.dart';
import 'package:xterm/terminal/osc.dart';
import 'package:xterm/terminal/terminal.dart';

typedef AnsiHandler = FutureOr<void> Function(StreamQueue<int>, Terminal);

Future<void> ansiHandler(StreamQueue<int> queue, Terminal terminal) async {
  final charAfterEsc = String.fromCharCode(await queue.next);

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

void _unsupportedHandler(StreamQueue<int> queue, Terminal terminal) async {
  // print('unimplemented ansi sequence.');
}

void _ansiSaveCursorHandler(StreamQueue<int> queue, Terminal terminal) {
  terminal.buffer.saveCursor();
}

void _ansiRestoreCursorHandler(StreamQueue<int> queue, Terminal terminal) {
  terminal.buffer.restoreCursor();
}

void _ansiIndexHandler(StreamQueue<int> queue, Terminal terminal) {
  terminal.buffer.index();
}

void _ansiReverseIndexHandler(StreamQueue<int> queue, Terminal terminal) {
  terminal.buffer.reverseIndex();
}

AnsiHandler _scsHandler(int which) {
  return (StreamQueue<int> queue, Terminal terminal) async {
    final name = String.fromCharCode(await queue.next);
    terminal.buffer.charset.designate(which, name);
  };
}

void _ansiNextLineHandler(StreamQueue<int> queue, Terminal terminal) {
  terminal.buffer.newLine();
  terminal.buffer.setCursorX(0);
}

void _ansiTabSetHandler(StreamQueue<int> queue, Terminal terminal) {
  terminal.tabSetAtCursor();
}
