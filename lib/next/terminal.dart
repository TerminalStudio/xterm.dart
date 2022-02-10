import 'dart:convert';
import 'dart:typed_data';

import 'package:xterm/next/core/buffer.dart';
import 'package:xterm/next/core/cursor.dart';
import 'package:xterm/next/core/escape/emitter.dart';
import 'package:xterm/next/core/escape/handler.dart';
import 'package:xterm/next/core/escape/parser.dart';
import 'package:xterm/next/core/line.dart';
import 'package:xterm/next/core/mouse.dart';
import 'package:xterm/next/core/state.dart';
import 'package:xterm/next/core/tabs.dart';
import 'package:xterm/util/circular_list.dart';
import 'package:xterm/util/observable.dart';

class Terminal with Observable implements TerminalState, EscapeHandler {
  final int maxLines;

  final void Function()? onBell;

  final void Function(String)? onTitleChange;

  final void Function(String)? onIconChange;

  final void Function(String)? onOutput;

  Terminal({
    this.maxLines = 1000,
    this.onBell,
    this.onTitleChange,
    this.onIconChange,
    this.onOutput,
  });

  late final _parser = EscapeParser(this);

  final _emitter = const EscapeEmitter();

  late var _buffer = _mainBuffer;

  late final _mainBuffer = Buffer(this, maxLines: maxLines, reflow: true);

  late final _altBuffer = Buffer(this, maxLines: maxLines, reflow: false);

  final tabStops = TabStops();

  /* TerminalState */

  int _viewWidth = 80;

  int _viewHeight = 25;

  CursorStyle _cursorStyle = CursorStyle();

  bool _insertMode = false;

  bool _lineFeedMode = false;

  bool _cursorKeysMode = false;

  bool _reverseDisplayMode = false;

  bool _originMode = false;

  bool _autoWrapMode = false;

  MouseMode _mouseMode = MouseMode.none;

  MouseReportMode _mouseReportMode = MouseReportMode.normal;

  bool _cursorBlinkMode = false;

  bool _cursorVisibleMode = true;

  bool _appKeypadMode = false;

  bool _reportFocusMode = false;

  bool _altBufferMouseScrollMode = false;

  bool _bracketedPasteMode = false;

  /* State getters */

  int get viewWidth => _viewWidth;

  int get viewHeight => _viewHeight;

  CursorStyle get cursor => _cursorStyle;

  bool get insertMode => _insertMode;

  bool get lineFeedMode => _lineFeedMode;

  bool get cursorKeysMode => _cursorKeysMode;

  bool get reverseDisplayMode => _reverseDisplayMode;

  bool get originMode => _originMode;

  bool get autoWrapMode => _autoWrapMode;

  MouseMode get mouseMode => _mouseMode;

  MouseReportMode get mouseReportMode => _mouseReportMode;

  bool get cursorBlinkMode => _cursorBlinkMode;

  bool get cursorVisibleMode => _cursorVisibleMode;

  bool get appKeypadMode => _appKeypadMode;

  bool get reportFocusMode => _reportFocusMode;

  bool get altBufferMouseScrollMode => _altBufferMouseScrollMode;

  bool get bracketedPasteMode => _bracketedPasteMode;

  Buffer get buffer => _buffer;

  CircularList<BufferLine> get lines => _buffer.lines;

  void write(String data) {
    _parser.write(data);
    notifyListeners();
  }

  /* Handlers */

  @override
  void writeChar(int char) {
    _buffer.writeChar(char);
  }

  /* SBC */

  @override
  void bell() {
    onBell?.call();
  }

  @override
  void backspaceReturn() {
    _buffer.moveCursorX(-1);
  }

  @override
  void tab() {
    final nextStop = tabStops.find(_buffer.cursorX, _viewWidth);
    _buffer.setCursorX(nextStop ?? _viewWidth);
  }

  @override
  void lineFeed() {
    _buffer.lineFeed();
  }

  @override
  void carriageReturn() {
    _buffer.setCursorX(0);
  }

  @override
  void shiftOut() {
    _buffer.charset.use(1);
  }

  @override
  void shiftIn() {
    _buffer.charset.use(0);
  }

  @override
  void unkownSBC(int char) {
    // no-op
  }

  /* ANSI sequence */

  @override
  void saveCursor() {
    _buffer.saveCursor();
  }

  @override
  void restoreCursor() {
    _buffer.restoreCursor();
  }

  @override
  void index() {
    _buffer.index();
  }

  @override
  void nextLine() {
    _buffer.index();
    _buffer.setCursorX(0);
  }

  @override
  void setTapStop() {
    tabStops.isSetAt(_buffer.cursorX);
  }

  @override
  void reverseIndex() {
    _buffer.reverseIndex();
  }

  @override
  void designateCharset(int charset) {
    _buffer.charset.use(charset);
  }

  @override
  void unkownEscape(int char) {
    // no-op
  }

  /* CSI */

  @override
  void setCursor(int x, int y) {
    _buffer.setCursor(x, y);
  }

  @override
  void setCursorX(int x) {
    _buffer.setCursorX(x);
  }

  @override
  void setCursorY(int y) {
    _buffer.setCursorY(y);
  }

  @override
  void moveCursorX(int offset) {
    _buffer.moveCursorX(offset);
  }

  @override
  void moveCursorY(int n) {
    _buffer.moveCursorY(n);
  }

  @override
  void clearTabStopUnderCursor() {
    tabStops.clearAt(_buffer.cursorX);
  }

  @override
  void clearAllTabStops() {
    tabStops.clearAll();
  }

  @override
  void sendPrimaryDeviceAttributes() {
    onOutput?.call(_emitter.primaryDeviceAttributes());
  }

  @override
  void sendSecondaryDeviceAttributes() {
    onOutput?.call(_emitter.secondaryDeviceAttributes());
  }

  @override
  void sendTertiaryDeviceAttributes() {
    onOutput?.call(_emitter.tertiaryDeviceAttributes());
  }

  @override
  void sendOperatingStatus() {
    onOutput?.call(_emitter.operatingStatus());
  }

  @override
  void sendCursorPosition() {
    onOutput?.call(_emitter.cursorPosition(_buffer.cursorX, _buffer.cursorY));
  }

  @override
  void setMargins(int top, [int? bottom]) {
    _buffer.setVerticalMargins(top, bottom ?? viewHeight - 1);
  }

  @override
  void cursorNextLine(int amount) {
    _buffer.moveCursorY(amount);
    _buffer.setCursorX(0);
  }

  @override
  void cursorPrecedingLine(int amount) {
    _buffer.moveCursorY(-amount);
    _buffer.setCursorX(0);
  }

  @override
  void eraseDisplayBelow() {
    _buffer.eraseDisplayFromCursor();
  }

  @override
  void eraseDisplayAbove() {
    _buffer.eraseDisplayToCursor();
  }

  @override
  void eraseDisplay() {
    _buffer.eraseDisplay();
  }

  @override
  void eraseScrollbackOnly() {
    _buffer.clearScrollback();
  }

  @override
  void eraseLineRight() {
    _buffer.eraseLineFromCursor();
  }

  @override
  void eraseLineLeft() {
    _buffer.eraseLineToCursor();
  }

  @override
  void eraseLine() {
    _buffer.eraseLine();
  }

  @override
  void insertLines(int amount) {
    _buffer.insertLines(amount);
  }

  @override
  void deleteLines(int amount) {
    _buffer.deleteLines(amount);
  }

  @override
  void deleteChars(int amount) {
    _buffer.deleteChars(amount);
  }

  @override
  void scrollUp(int amount) {
    _buffer.scrollUp(amount);
  }

  @override
  void scrollDown(int amount) {
    _buffer.scrollDown(amount);
  }

  @override
  void eraseChars(int amount) {
    _buffer.eraseChars(amount);
  }

  @override
  void insertBlankChars(int amount) {
    _buffer.insertBlankChars(amount);
  }

  @override
  void unkownCSI(int finalByte) {
    // no-op
  }

  /* Modes */

  @override
  void setInsertMode(bool enabled) {
    _insertMode = enabled;
  }

  @override
  void setLineFeedMode(bool enabled) {
    _lineFeedMode = enabled;
  }

  @override
  void setUnknownMode(int mode, bool enabled) {
    // no-op
  }

  /* DEC Private modes */

  @override
  void setCursorKeysMode(bool enabled) {
    _cursorKeysMode = enabled;
  }

  @override
  void setReverseDisplayMode(bool enabled) {
    _reverseDisplayMode = enabled;
  }

  @override
  void setOriginMode(bool enabled) {
    _originMode = enabled;
  }

  @override
  void setColumnMode(bool enabled) {
    // no-op
  }

  @override
  void setAutoWrapMode(bool enabled) {
    _autoWrapMode = enabled;
  }

  @override
  void setMouseMode(MouseMode mode) {
    _mouseMode = mode;
  }

  @override
  void setCursorBlinkMode(bool enabled) {
    _cursorBlinkMode = enabled;
  }

  @override
  void setCursorVisibleMode(bool enabled) {
    _cursorVisibleMode = enabled;
  }

  @override
  void useAltBuffer() {
    _buffer = _altBuffer;
  }

  @override
  void useMainBuffer() {
    _buffer = _mainBuffer;
  }

  @override
  void clearAltBuffer() {
    _altBuffer.clear();
  }

  @override
  void setAppKeypadMode(bool enabled) {
    _appKeypadMode = enabled;
  }

  @override
  void setReportFocusMode(bool enabled) {
    _reportFocusMode = enabled;
  }

  @override
  void setMouseReportMode(MouseReportMode mode) {
    _mouseReportMode = mode;
  }

  @override
  void setAltBufferMouseScrollMode(bool enabled) {
    _altBufferMouseScrollMode = enabled;
  }

  @override
  void setBracketedPasteMode(bool enabled) {
    _bracketedPasteMode = enabled;
  }

  @override
  void setUnknownDecMode(int mode, bool enabled) {
    // no-op
  }

  /* Select Graphic Rendition (SGR) */

  @override
  void resetCursorStyle() {
    _cursorStyle.reset();
  }

  @override
  void setCursorBold() {
    _cursorStyle.setBold();
  }

  @override
  void setCursorFaint() {
    _cursorStyle.setFaint();
  }

  @override
  void setCursorItalic() {
    _cursorStyle.setItalic();
  }

  @override
  void setCursorUnderline() {
    _cursorStyle.setUnderline();
  }

  @override
  void setCursorBlink() {
    _cursorStyle.setBlink();
  }

  @override
  void setCursorInverse() {
    _cursorStyle.setInverse();
  }

  @override
  void setCursorInvisible() {
    _cursorStyle.setInvisible();
  }

  @override
  void setCursorStrikethrough() {
    _cursorStyle.setStrikethrough();
  }

  @override
  void unsetCursorBold() {
    _cursorStyle.unsetBold();
  }

  @override
  void unsetCursorFaint() {
    _cursorStyle.unsetFaint();
  }

  @override
  void unsetCursorItalic() {
    _cursorStyle.unsetItalic();
  }

  @override
  void unsetCursorUnderline() {
    _cursorStyle.unsetUnderline();
  }

  @override
  void unsetCursorBlink() {
    _cursorStyle.unsetBlink();
  }

  @override
  void unsetCursorInverse() {
    _cursorStyle.unsetInverse();
  }

  @override
  void unsetCursorInvisible() {
    _cursorStyle.unsetInvisible();
  }

  @override
  void unsetCursorStrikethrough() {
    _cursorStyle.unsetStrikethrough();
  }

  @override
  void setForegroundColor16(int color) {
    _cursorStyle.setForegroundColor16(color);
  }

  @override
  void setForegroundColor256(int index) {
    _cursorStyle.setForegroundColor256(index);
  }

  @override
  void setForegroundColorRgb(int r, int g, int b) {
    _cursorStyle.setForegroundColorRgb(r, g, b);
  }

  @override
  void resetForeground() {
    _cursorStyle.resetForegroundColor();
  }

  @override
  void setBackgroundColor16(int color) {
    _cursorStyle.setBackgroundColor16(color);
  }

  @override
  void setBackgroundColor256(int index) {
    _cursorStyle.setBackgroundColor256(index);
  }

  @override
  void setBackgroundColorRgb(int r, int g, int b) {
    _cursorStyle.setBackgroundColorRgb(r, g, b);
  }

  @override
  void resetBackground() {
    _cursorStyle.resetBackgroundColor();
  }

  @override
  void unsupportedStyle(int param) {
    // no-op
  }

  /* OSC */

  @override
  void setTitle(String name) {
    onTitleChange?.call(name);
  }

  @override
  void setIconName(String name) {
    onIconChange?.call(name);
  }

  @override
  void unknownOSC(String ps) {
    // no-op
  }
}
