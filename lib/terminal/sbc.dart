import 'package:xterm/terminal/terminal.dart';

typedef SbcHandler = void Function(int, Terminal);

const sbcMaxCodePoint = 0x0f;

final sbcHandlers = _sbcHandlers();

// Build single byte character lookup table
List<SbcHandler?> _sbcHandlers() {
  final result = List<SbcHandler?>.filled(sbcMaxCodePoint + 1, null);
  result[0x05] = _voidHandler;
  result[0x07] = _bellHandler;
  result[0x08] = _backspaceReturnHandler;
  result[0x09] = _tabHandler;
  result[0x0a] = _newLineHandler;
  result[0x0b] = _newLineHandler;
  result[0x0c] = _newLineHandler;
  result[0x0d] = _carriageReturnHandler;
  result[0x0e] = _shiftOutHandler;
  result[0x0f] = _shiftInHandler;
  return result;
}

void _bellHandler(int code, Terminal terminal) {
  terminal.onBell();
}

void _voidHandler(int code, Terminal terminal) {
  // unsupported.
}

void _newLineHandler(int code, Terminal terminal) {
  terminal.buffer.newLine();
}

void _carriageReturnHandler(int code, Terminal terminal) {
  terminal.buffer.carriageReturn();
}

void _backspaceReturnHandler(int code, Terminal terminal) {
  terminal.buffer.backspace();
}

void _shiftOutHandler(int code, Terminal terminal) {
  terminal.buffer.charset.use(1);
}

void _shiftInHandler(int code, Terminal terminal) {
  terminal.buffer.charset.use(0);
}

void _tabHandler(int code, Terminal terminal) {
  terminal.tab();
}
