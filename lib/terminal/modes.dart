import 'package:xterm/mouse/mouse_mode.dart';
import 'package:xterm/terminal/csi.dart';
import 'package:xterm/terminal/terminal.dart';

final _decset = 'h'.codeUnitAt(0);
final _decrst = 'l'.codeUnitAt(0);

bool _isEnabled(int finalByte) {
  if (finalByte == _decset) {
    return true;
  }

  if (finalByte == _decrst) {
    return false;
  }

  // print('unexpected finalByte: $finalByte');
  return true;
}

void csiSetModes(CSI csi, Terminal terminal) {
  if (csi.params.isEmpty) {
    // print('warning: no mode specified.');
    return;
  }

  final enabled = _isEnabled(csi.finalByte);

  const decPrefix = 63; // '?'
  final isDec = csi.prefix == decPrefix;

  for (var mode in csi.params) {
    if (isDec) {
      csiDecSetMode(mode, enabled, terminal);
    } else {
      csiSetMode(mode, enabled, terminal);
    }
  }
}

void csiSetMode(int mode, bool enabled, Terminal terminal) {
  switch (mode) {
    case 4:
      if (enabled) {
        terminal.setInsertMode();
      } else {
        terminal.setReplaceMode();
      }
      break;
    case 20:
      if (enabled) {
        terminal.setNewLineMode();
      } else {
        terminal.setLineFeedMode();
      }
      break;
    default:
      terminal.debug.onError('unsupported mode: $mode');
      return;
  }
}

void csiDecSetMode(int mode, bool enabled, Terminal terminal) {
  switch (mode) {
    case 1:
      terminal.setApplicationCursorKeys(enabled);
      break;
    // case "?3":
    // 	if (enabled) {
    // 		// DECCOLM - COLumn mode, 132 characters per line
    // 		terminal.setSize(132, uint(lines));
    // 	} else {
    // 		// DECCOLM - 80 characters per line (erases screen)
    // 		terminal.setSize(80, uint(lines));
    // 	}
    // 	terminal.clear();
    // case "?4":
    // 	// DECSCLM
    case 5:
      // DECSCNM
      terminal.setScreenMode(enabled);
      break;
    case 6:
      // DECOM
      terminal.setOriginMode(enabled);
      break;
    case 7:
      //DECAWM
      terminal.setAutoWrapMode(enabled);
      break;
    case 9:
      if (enabled) {
        // terminal.setMouseMode(MouseMode.x10);
      } else {
        terminal.setMouseMode(MouseMode.none);
      }
      break;
    case 12:
    case 13:
      terminal.setBlinkingCursor(enabled);
      break;
    case 25:
      terminal.setShowCursor(enabled);
      break;
    case 47:
    case 1047:
      if (enabled) {
        terminal.useAltBuffer();
      } else {
        terminal.useMainBuffer();
      }
      break;
    case 1000:
    case 10061000:
      // enable mouse tracking
      // 1000 refers to ext mode for extended mouse click area - otherwise only x <= 255-31
      if (enabled) {
        // terminal.setMouseMode(MouseMode.vt200);
      } else {
        terminal.setMouseMode(MouseMode.none);
      }
      break;
    case 1002:
      // enable mouse tracking
      // 1000 refers to ext mode for extended mouse click area - otherwise only x <= 255-31
      if (enabled) {
        // terminal.setMouseMode(MouseMode.buttonEvent);
      } else {
        terminal.setMouseMode(MouseMode.none);
      }
      break;
    case 1003:
      if (enabled) {
        // terminal.setMouseMode(MouseMode.anyEvent);
      } else {
        terminal.setMouseMode(MouseMode.none);
      }
      break;
    case 1005:
      if (enabled) {
        // terminal.setMouseExtMode(MouseExt.utf);
      } else {
        // terminal.setMouseExtMode(MouseExt.none);
      }
      break;
    case 1006:
      if (enabled) {
        // terminal.setMouseExtMode(MouseExt.sgr);
      } else {
        // terminal.setMouseExtMode(MouseExt.none);
      }
      break;
    case 1048:
      if (enabled) {
        terminal.buffer.saveCursor();
      } else {
        terminal.buffer.restoreCursor();
      }
      break;
    case 1049:
      if (enabled) {
        terminal.useAltBuffer();
        terminal.buffer.clear();
      } else {
        terminal.useMainBuffer();
      }
      break;
    case 2004:
      terminal.setBracketedPasteMode(enabled);
      break;
    default:
      terminal.debug.onError('unsupported mode: $mode');
      return;
  }
}
