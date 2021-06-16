import 'package:xterm/mouse/position.dart';
import 'package:xterm/terminal/terminal.dart';

abstract class MouseMode {
  const MouseMode();

  static const none = MouseModeNone();
  // static const x10 = MouseModeX10();
  // static const vt200 = MouseModeX10();
  // static const buttonEvent = MouseModeX10();

  void onTap(Terminal terminal, Position offset);
  void onDoubleTap(Terminal terminal, Position offset) {}
  void onPanStart(Terminal terminal, Position offset) {}
  void onPanUpdate(Terminal terminal, Position offset) {}
}

class MouseModeNone extends MouseMode {
  const MouseModeNone();

  @override
  void onTap(Terminal terminal, Position offset) {
    terminal.debug.onMsg('tap: $offset');
  }

  @override
  void onDoubleTap(Terminal terminal, Position offset) {
    terminal.selectWordOrRow(offset);
  }

  @override
  void onPanStart(Terminal terminal, Position offset) {
    terminal.selection!.init(offset);
  }

  @override
  void onPanUpdate(Terminal terminal, Position offset) {
    terminal.selection!.update(offset);
  }
}

class MouseModeX10 extends MouseMode {
  const MouseModeX10();

  @override
  void onTap(Terminal terminal, Position offset) {
    final btn = 1;

    final px = offset.x + 1;
    final py = terminal.buffer.convertRawLineToViewLine(offset.y) + 1;

    final buffer = StringBuffer();
    buffer.writeCharCode(0x1b);
    buffer.write('[M');
    buffer.writeCharCode(btn + 32);
    buffer.writeCharCode(px + 32);
    buffer.writeCharCode(py + 32);
    terminal.backend?.write(buffer.toString());
  }
}
