import 'package:xterm/buffer/buffer_line.dart';
import 'package:xterm/input/keys.dart';
import 'package:xterm/mouse/position.dart';
import 'package:xterm/mouse/selection.dart';
import 'package:xterm/terminal/platform.dart';
import 'package:xterm/util/observable.dart';

abstract class TerminalUiInteraction with Observable {
  int get scrollOffsetFromBottom;
  int get scrollOffsetFromTop;
  int get scrollOffset;
  int get bufferHeight;
  int get terminalHeight;
  int get terminalWidth;
  int get invisibleHeight;
  Selection? get selection;
  bool get showCursor;
  List<BufferLine> getVisibleLines();
  int get cursorY;
  int get cursorX;
  BufferLine? get currentLine;
  int get cursorColor;
  int get backgroundColor;
  bool get dirty;
  PlatformBehavior get platform;

  bool get isReady;

  void refresh();
  void clearSelection();
  void onMouseTap(Position position);
  void onPanStart(Position position);
  void onPanUpdate(Position position);
  void setScrollOffsetFromBottom(int offset);
  int convertViewLineToRawLine(int viewLine);
  void raiseOnInput(String input);
  void write(String text);
  void paste(String data);
  void resize(int newWidth, int newHeight);
  void keyInput(
    TerminalKey key, {
    bool ctrl = false,
    bool alt = false,
    bool shift = false,
    bool mac = false,
    // bool meta,
  });
}
