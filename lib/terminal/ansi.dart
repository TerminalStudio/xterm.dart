import 'dart:collection';

import 'package:xterm/terminal/csi.dart';
import 'package:xterm/terminal/osc.dart';
import 'package:xterm/terminal/terminal.dart';
import 'package:xterm/util/lookup_table.dart';

/// Handler of terminal sequences. Returns true if the sequence is consumed,
/// false to indicate that the sequence is not completed and no charater is
/// consumed from the queue.
typedef AnsiHandler = bool Function(Queue<int>, Terminal);

bool ansiHandler(Queue<int> queue, Terminal terminal) {
  // The sequence isn't completed, just ignore it.
  if (queue.isEmpty) {
    return false;
  }

  final charAfterEsc = queue.removeFirst();

  final handler = _ansiHandlers[charAfterEsc];
  if (handler != null) {
    // if (handler != csiHandler && handler != oscHandler) {
    //   terminal.debug.onEsc(charAfterEsc);
    // }

    final finished = handler(queue, terminal);
    if (!finished) {
      queue.addFirst(charAfterEsc);
    }
    return finished;
  }

  terminal.debug.onError('unsupported ansi sequence: $charAfterEsc');
  return true;
}

final _ansiHandlers = FastLookupTable({
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
});

AnsiHandler _voidHandler(int sequenceLength) {
  return (queue, terminal) {
    if (queue.length < sequenceLength) {
      return false;
    }

    for (var i = 0; i < sequenceLength; i++) {
      queue.removeFirst();
    }
    return true;
  };
}

bool _unsupportedHandler(Queue<int> queue, Terminal terminal) {
  // print('unimplemented ansi sequence.');
  return true;
}

bool _ansiSaveCursorHandler(Queue<int> queue, Terminal terminal) {
  terminal.buffer.saveCursor();
  return true;
}

bool _ansiRestoreCursorHandler(Queue<int> queue, Terminal terminal) {
  terminal.buffer.restoreCursor();
  return true;
}

/// https://vt100.net/docs/vt100-ug/chapter3.html#IND IND – Index
///
/// ESC D
///
/// This sequence causes the active position to move downward one line without
/// changing the column position. If the active position is at the bottom
/// margin, a scroll up is performed.
bool _ansiIndexHandler(Queue<int> queue, Terminal terminal) {
  terminal.buffer.index();
  return true;
}

bool _ansiReverseIndexHandler(Queue<int> queue, Terminal terminal) {
  terminal.buffer.reverseIndex();
  return true;
}

/// SCS – Select Character Set
///
/// The appropriate G0 and G1 character sets are designated from one of the five
/// possible character sets. The G0 and G1 sets are invoked by the codes SI and
/// SO (shift in and shift out) respectively.
AnsiHandler _scsHandler(int which) {
  return (Queue<int> queue, Terminal terminal) {
    // The sequence isn't completed, just ignore it.
    if (queue.isEmpty) {
      return false;
    }

    final name = queue.removeFirst();
    terminal.buffer.charset.designate(which, name);
    return true;
  };
}

bool _ansiNextLineHandler(Queue<int> queue, Terminal terminal) {
  terminal.buffer.newLine();
  terminal.buffer.setCursorX(0);
  return true;
}

bool _ansiTabSetHandler(Queue<int> queue, Terminal terminal) {
  terminal.tabSetAtCursor();
  return true;
}
