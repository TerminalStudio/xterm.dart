import 'package:async/async.dart';
import 'package:xterm/terminal/modes.dart';
import 'package:xterm/terminal/sgr.dart';
import 'package:xterm/terminal/terminal.dart';

typedef CsiSequenceHandler = void Function(CSI, Terminal);

final _csiHandlers = <String, CsiSequenceHandler>{
  'c': csiSendDeviceAttributesHandler,
  'd': csiLinePositionAbsolute,
  'f': csiCursorPositionHandler,
  'g': csiTabClearHandler,
  'h': csiModeHandler,
  'l': csiModeHandler,
  'm': sgrHandler,
  'n': csiDeviceStatusReportHandler,
  'r': csiSetMarginsHandler,
  't': csiWindowManipulation,
  'A': csiCursorUpHandler,
  'B': csiCursorDownHandler,
  'C': csiCursorForwardHandler,
  'D': csiCursorBackwardHandler,
  'E': csiCursorNextLineHandler,
  'F': csiCursorPrecedingLineHandler,
  'G': csiCursorHorizontalAbsoluteHandler,
  'H': csiCursorPositionHandler,
  'J': csiEraseInDisplayHandler,
  'K': csiEraseInLineHandler,
  'L': csiInsertLinesHandler,
  'M': csiDeleteLinesHandler,
  'P': csiDeleteHandler,
  'S': csiScrollUpHandler,
  'T': csiScrollDownHandler,
  'X': csiEraseCharactersHandler,
  '@': csiInsertBlankCharactersHandler,
};

class CSI {
  CSI({
    this.params,
    this.finalByte,
    this.intermediates,
  });

  final List<String> params;
  final int finalByte;
  final List<int> intermediates;

  @override
  String toString() {
    return params.join(';') + String.fromCharCode(finalByte);
  }
}

Future<CSI> _parseCsi(StreamQueue<int> queue) async {
  final paramBuffer = StringBuffer();
  final intermediates = <int>[];

  while (true) {
    final char = await queue.next;

    if (char >= 0x30 && char <= 0x3F) {
      paramBuffer.writeCharCode(char);
      continue;
    }

    if (char > 0 && char <= 0x2F) {
      intermediates.add(char);
      continue;
    }

    const csiMin = 0x40;
    const csiMax = 0x7e;

    if (char >= csiMin && char <= csiMax) {
      final params = paramBuffer.toString().split(';');
      return CSI(
        params: params,
        finalByte: char,
        intermediates: intermediates,
      );
    }
  }
}

Future<void> csiHandler(StreamQueue<int> queue, Terminal terminal) async {
  final csi = await _parseCsi(queue);

  terminal.debug.onCsi(csi);

  final handler = _csiHandlers[String.fromCharCode(csi.finalByte)];

  if (handler != null) {
    handler(csi, terminal);
    return;
  }

  terminal.debug.onError('unknown: $csi');
}

void csiEraseInDisplayHandler(CSI csi, Terminal terminal) {
  var ps = '0';

  if (csi.params.isNotEmpty) {
    ps = csi.params.first;
  }

  switch (ps) {
    case '':
    case '0':
      terminal.buffer.eraseDisplayFromCursor();
      break;
    case '1':
      terminal.buffer.eraseDisplayToCursor();
      break;
    case '2':
    case '3':
      terminal.buffer.eraseDisplay();
      break;
    default:
      terminal.debug.onError("Unsupported ED: CSI $ps J");
  }
}

void csiEraseInLineHandler(CSI csi, Terminal terminal) {
  var ps = '0';

  if (csi.params.isNotEmpty) {
    ps = csi.params.first;
  }

  switch (ps) {
    case '':
    case '0':
      terminal.buffer.eraseLineFromCursor();
      break;
    case '1':
      terminal.buffer.eraseLineToCursor();
      break;
    case '2':
      terminal.buffer.eraseLine();
      break;
    default:
      terminal.debug.onError("Unsupported EL: CSI $ps K");
  }
}

void csiCursorPositionHandler(CSI csi, Terminal terminal) {
  var x = 1;
  var y = 1;

  if (csi.params.length == 2) {
    y = int.tryParse(csi.params[0]) ?? x;
    x = int.tryParse(csi.params[1]) ?? y;
  }

  terminal.buffer.setPosition(x - 1, y - 1);
}

void csiLinePositionAbsolute(CSI csi, Terminal terminal) {
  var row = 1;

  if (csi.params.isNotEmpty) {
    row = int.tryParse(csi.params.first) ?? row;
  }

  terminal.buffer.setCursorY(row - 1);
}

void csiCursorHorizontalAbsoluteHandler(CSI csi, Terminal terminal) {
  var x = 1;

  if (csi.params.isNotEmpty) {
    x = int.tryParse(csi.params.first) ?? x;
  }

  terminal.buffer.setCursorX(x - 1);
}

void csiCursorForwardHandler(CSI csi, Terminal terminal) {
  var offset = 1;

  if (csi.params.isNotEmpty) {
    offset = int.tryParse(csi.params.first) ?? offset;
  }

  terminal.buffer.movePosition(offset, 0);
}

void csiCursorBackwardHandler(CSI csi, Terminal terminal) {
  var offset = 1;

  if (csi.params.isNotEmpty) {
    offset = int.tryParse(csi.params.first) ?? offset;
  }

  terminal.buffer.movePosition(-offset, 0);
}

void csiEraseCharactersHandler(CSI csi, Terminal terminal) {
  var count = 1;

  if (csi.params.isNotEmpty) {
    count = int.tryParse(csi.params.first) ?? count;
  }

  terminal.buffer.eraseCharacters(count);
}

void csiModeHandler(CSI csi, Terminal terminal) {
  // terminal.ActiveBuffer().ClearSelection()
  return csiSetModes(csi, terminal);
}

void csiDeviceStatusReportHandler(CSI csi, Terminal terminal) {
  if (csi.params.isEmpty) return;

  switch (csi.params[0]) {
    case "5":
      terminal.onInput("\x1b[0n");
      break;
    case "6": // report cursor position
      terminal.onInput("\x1b[${terminal.cursorX + 1};${terminal.cursorY + 1}R");
      break;
    default:
      terminal.debug
          .onError('Unknown Device Status Report identifier: ${csi.params[0]}');
      return;
  }
}

void csiSendDeviceAttributesHandler(CSI csi, Terminal terminal) {
  var response = '?1;2';

  if (csi.params.isNotEmpty && csi.params.first.startsWith('>')) {
    response = '>0;0;0';
  }

  terminal.onInput('\x1b[${response}c');
}

void csiCursorUpHandler(CSI csi, Terminal terminal) {
  var distance = 1;

  if (csi.params.isNotEmpty) {
    distance = int.tryParse(csi.params.first) ?? distance;
  }

  terminal.buffer.movePosition(0, -distance);
}

void csiCursorDownHandler(CSI csi, Terminal terminal) {
  var distance = 1;

  if (csi.params.isNotEmpty) {
    distance = int.tryParse(csi.params.first) ?? distance;
  }

  terminal.buffer.movePosition(0, distance);
}

void csiSetMarginsHandler(CSI csi, Terminal terminal) {
  var top = 1;
  var bottom = terminal.viewHeight;

  if (csi.params.length > 2) {
    return;
  }

  if (csi.params.isNotEmpty) {
    top = int.tryParse(csi.params[0]) ?? top;

    if (csi.params.length > 1) {
      bottom = int.tryParse(csi.params[1]) ?? bottom;
    }
  }

  terminal.buffer.setVerticalMargins(top - 1, bottom - 1);
  terminal.buffer.setPosition(0, 0);
}

void csiDeleteHandler(CSI csi, Terminal terminal) {
  var count = 1;

  if (csi.params.isNotEmpty) {
    count = int.tryParse(csi.params.first) ?? count;
  }

  if (count < 1) {
    count = 1;
  }

  terminal.buffer.deleteChars(count);
}

void csiTabClearHandler(CSI csi, Terminal terminal) {
  // TODO
}

void csiWindowManipulation(CSI csi, Terminal terminal) {
  // not supported
}

void csiCursorNextLineHandler(CSI csi, Terminal terminal) {
  var count = 1;

  if (csi.params.isNotEmpty) {
    count = int.tryParse(csi.params.first) ?? count;
  }

  if (count < 1) {
    count = 1;
  }

  terminal.buffer.moveCursorY(count);
  terminal.buffer.setCursorX(0);
}

void csiCursorPrecedingLineHandler(CSI csi, Terminal terminal) {
  var count = 1;

  if (csi.params.isNotEmpty) {
    count = int.tryParse(csi.params.first) ?? count;
  }

  if (count < 1) {
    count = 1;
  }

  terminal.buffer.moveCursorY(-count);
  terminal.buffer.setCursorX(0);
}

void csiInsertLinesHandler(CSI csi, Terminal terminal) {
  var count = 1;

  if (csi.params.isNotEmpty) {
    count = int.tryParse(csi.params.first) ?? count;
  }

  if (count < 1) {
    count = 1;
  }

  terminal.buffer.insertLines(count);
}

void csiDeleteLinesHandler(CSI csi, Terminal terminal) {
  var count = 1;

  if (csi.params.isNotEmpty) {
    count = int.tryParse(csi.params.first) ?? count;
  }

  if (count < 1) {
    count = 1;
  }

  terminal.buffer.deleteLines(count);
}

void csiScrollUpHandler(CSI csi, Terminal terminal) {
  var count = 1;

  if (csi.params.isNotEmpty) {
    count = int.tryParse(csi.params.first) ?? count;
  }

  if (count < 1) {
    count = 1;
  }

  terminal.buffer.areaScrollUp(count);
}

void csiScrollDownHandler(CSI csi, Terminal terminal) {
  var count = 1;

  if (csi.params.isNotEmpty) {
    count = int.tryParse(csi.params.first) ?? count;
  }

  if (count < 1) {
    count = 1;
  }

  terminal.buffer.areaScrollDown(count);
}

void csiInsertBlankCharactersHandler(CSI csi, Terminal terminal) {
  var count = 1;

  if (csi.params.isNotEmpty) {
    count = int.tryParse(csi.params.first) ?? count;
  }

  if (count < 1) {
    count = 1;
  }

  terminal.buffer.insertBlankCharacters(count);
}
