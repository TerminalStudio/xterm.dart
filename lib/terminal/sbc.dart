import 'package:xterm/terminal/terminal.dart';

typedef SbcHandler = void Function(int, Terminal);

final sbcHandlers = <int, SbcHandler>{
  0x05: _voidHandler,
  0x07: _bellHandler,
  0x08: _backspaceReturnHandler,
  0x09: _tabHandler,
  0x0a: _newLineHandler,
  0x0b: _newLineHandler,
  0x0c: _newLineHandler,
  0x0d: _carriageReturnHandler,
  0x0e: _shiftOutHandler,
  0x0f: _shiftInHandler,
};

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
