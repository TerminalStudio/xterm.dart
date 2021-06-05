import 'dart:math' show max, min;

import 'package:xterm/buffer/line/line.dart';
import 'package:xterm/buffer/reflow_strategy_narrower.dart';
import 'package:xterm/buffer/reflow_strategy_wider.dart';
import 'package:xterm/terminal/charset.dart';
import 'package:xterm/terminal/terminal.dart';
import 'package:xterm/util/circular_list.dart';
import 'package:xterm/util/scroll_range.dart';
import 'package:xterm/util/unicode_v11.dart';

class Buffer {
  Buffer({
    required this.terminal,
    required this.isAltBuffer,
  }) {
    resetVerticalMargins();

    lines = CircularList(
      terminal.maxLines,
    );
    for (int i = 0; i < terminal.viewHeight; i++) {
      lines.push(_newEmptyLine());
    }
  }

  final Terminal terminal;
  final bool isAltBuffer;
  final charset = Charset();

  /// lines of the buffer. the length of [lines] should always be equal or
  /// greater than [Terminal.viewHeight].
  late final CircularList<BufferLine> lines;

  int? _savedCursorX;
  int? _savedCursorY;
  int? _savedCellFgColor;
  int? _savedCellBgColor;
  int? _savedCellFlags;

  // Indicates how far the bottom of the viewport is from the bottom of the
  // entire buffer. 0 if the viewport overlaps the terminal screen.
  int get scrollOffsetFromBottom => _scrollOffsetFromBottom;
  int _scrollOffsetFromBottom = 0;

  // Indicates how far the top of the viewport is from the top of the entire
  // buffer. 0 if the viewport is scrolled to the top.
  int get scrollOffsetFromTop {
    return terminal.invisibleHeight - scrollOffsetFromBottom;
  }

  /// Indicated whether the terminal should automatically scroll to bottom when
  /// new lines are added. When user is scrolling, [isUserScrolling] is true and
  /// the automatical scroll-to-bottom behavior is disabled.
  bool get isUserScrolling {
    return _scrollOffsetFromBottom != 0;
  }

  /// Horizontal position of the cursor relative to the top-left cornor of the
  /// screen, starting from 0.
  int get cursorX => _cursorX.clamp(0, terminal.viewWidth - 1);
  int _cursorX = 0;

  /// Vertical position of the cursor relative to the top-left cornor of the
  /// screen, starting from 0.
  int get cursorY => _cursorY;
  int _cursorY = 0;

  int get marginTop => _marginTop;
  late int _marginTop;

  int get marginBottom => _marginBottom;
  late int _marginBottom;

  /// Writes data to the terminal. Terminal sequences or special characters are
  /// not interpreted and directly added to the buffer.
  ///
  /// See also: [Terminal.write]
  void write(String text) {
    for (var char in text.runes) {
      writeChar(char);
    }
  }

  /// Writes a single character to the terminal. Special chatacters are not
  /// interpreted and directly added to the buffer.
  ///
  /// See also: [Terminal.writeChar]
  void writeChar(int codePoint) {
    codePoint = charset.translate(codePoint);

    final cellWidth = unicodeV11.wcwidth(codePoint);
    if (_cursorX >= terminal.viewWidth) {
      newLine();
      setCursorX(0);
      if (terminal.autoWrapMode) {
        currentLine.isWrapped = true;
      }
    }

    final line = currentLine;
    line.ensure(_cursorX + 1);

    line.cellInitialize(
      _cursorX,
      content: codePoint,
      width: cellWidth,
      cursor: terminal.cursor,
    );

    if (_cursorX < terminal.viewWidth) {
      _cursorX++;
    }

    if (cellWidth == 2) {
      writeChar(0);
    }
  }

  /// get line in the viewport. [index] starts from 0, must be smaller than
  /// [Terminal.viewHeight].
  BufferLine getViewLine(int index) {
    index = index.clamp(0, terminal.viewHeight - 1);
    return lines[convertViewLineToRawLine(index)];
  }

  BufferLine get currentLine {
    return getViewLine(_cursorY);
  }

  int get height {
    return lines.length;
  }

  int convertViewLineToRawLine(int viewLine) {
    if (terminal.viewHeight > height) {
      return viewLine;
    }

    return viewLine + (height - terminal.viewHeight);
  }

  int convertRawLineToViewLine(int rawLine) {
    if (terminal.viewHeight > height) {
      return rawLine;
    }

    return rawLine - (height - terminal.viewHeight);
  }

  void newLine() {
    if (terminal.newLineMode) {
      setCursorX(0);
    }

    index();
  }

  void carriageReturn() {
    setCursorX(0);
  }

  void backspace() {
    if (_cursorX == 0 && currentLine.isWrapped) {
      currentLine.isWrapped = false;
      movePosition(terminal.viewWidth - 1, -1);
    } else if (_cursorX == terminal.viewWidth) {
      movePosition(-2, 0);
    } else {
      movePosition(-1, 0);
    }
  }

  List<BufferLine> getVisibleLines() {
    if (height < terminal.viewHeight) {
      return lines.toList();
    }

    final result = <BufferLine>[];

    for (var i = height - terminal.viewHeight; i < height; i++) {
      final y = i - scrollOffsetFromBottom;
      if (y >= 0 && y < height) {
        result.add(lines[y]);
      }
    }

    return result;
  }

  void eraseDisplayFromCursor() {
    eraseLineFromCursor();

    for (var i = _cursorY + 1; i < terminal.viewHeight; i++) {
      final line = getViewLine(i);
      line.isWrapped = false;
      line.erase(terminal.cursor, 0, terminal.viewWidth);
    }
  }

  void eraseDisplayToCursor() {
    eraseLineToCursor();

    for (var i = 0; i < _cursorY; i++) {
      final line = getViewLine(i);
      line.isWrapped = false;
      line.erase(terminal.cursor, 0, terminal.viewWidth);
    }
  }

  void eraseDisplay() {
    for (var i = 0; i < terminal.viewHeight; i++) {
      final line = getViewLine(i);
      line.isWrapped = false;
      line.erase(terminal.cursor, 0, terminal.viewWidth);
    }
  }

  void eraseLineFromCursor() {
    currentLine.isWrapped = false;
    currentLine.erase(terminal.cursor, _cursorX, terminal.viewWidth);
  }

  void eraseLineToCursor() {
    currentLine.isWrapped = false;
    currentLine.erase(terminal.cursor, 0, _cursorX);
  }

  void eraseLine() {
    currentLine.isWrapped = false;
    currentLine.erase(terminal.cursor, 0, terminal.viewWidth);
  }

  void eraseCharacters(int count) {
    final start = _cursorX;
    currentLine.erase(terminal.cursor, start, start + count);
  }

  ScrollRange getAreaScrollRange() {
    var top = convertViewLineToRawLine(_marginTop);
    var bottom = convertViewLineToRawLine(_marginBottom) + 1;
    if (bottom > lines.length) {
      bottom = lines.length;
    }
    return ScrollRange(top, bottom);
  }

  void areaScrollDown(int lines) {
    final scrollRange = getAreaScrollRange();

    for (var i = scrollRange.bottom; i > scrollRange.top;) {
      i--;
      if (i >= scrollRange.top + lines) {
        this.lines[i] = this.lines[i - lines];
      } else {
        this.lines[i] = _newEmptyLine();
      }
    }
  }

  void areaScrollUp(int lines) {
    final scrollRange = getAreaScrollRange();

    for (var i = scrollRange.top; i < scrollRange.bottom; i++) {
      if (i + lines < scrollRange.bottom) {
        this.lines[i] = this.lines[i + lines];
      } else {
        this.lines[i] = _newEmptyLine();
      }
    }
  }

  /// https://vt100.net/docs/vt100-ug/chapter3.html#IND IND – Index
  ///
  /// ESC D
  ///
  /// [index] causes the active position to move downward one line without
  /// changing the column position. If the active position is at the bottom
  /// margin, a scroll up is performed.
  void index() {
    if (isInScrollableRegion) {
      if (_cursorY < _marginBottom) {
        moveCursorY(1);
      } else {
        areaScrollUp(1);
      }
      return;
    }

    // the cursor is not in the scrollable region
    if (_cursorY >= terminal.viewHeight - 1) {
      // we are at the bottom so a new line is created.
      lines.push(_newEmptyLine());

      // keep viewport from moving if user is scrolling.
      if (isUserScrolling) {
        _scrollOffsetFromBottom++;
      }
    } else {
      // there're still lines so we simply move cursor down.
      moveCursorY(1);
    }
  }

  /// https://vt100.net/docs/vt100-ug/chapter3.html#RI
  void reverseIndex() {
    if (_cursorY == _marginTop) {
      areaScrollDown(1);
    } else if (_cursorY > 0) {
      moveCursorY(-1);
    }
  }

  void cursorGoForward() {
    setCursorX(_cursorX + 1);
  }

  void setCursorX(int cursorX) {
    _cursorX = cursorX.clamp(0, terminal.viewWidth - 1);
  }

  void setCursorY(int cursorY) {
    _cursorY = cursorY.clamp(0, terminal.viewHeight - 1);
  }

  void moveCursorX(int offset) {
    setCursorX(_cursorX + offset);
  }

  void moveCursorY(int offset) {
    setCursorY(_cursorY + offset);
  }

  void setPosition(int cursorX, int cursorY) {
    var maxLine = terminal.viewHeight - 1;

    if (terminal.originMode) {
      cursorY += _marginTop;
      maxLine = _marginBottom;
    }

    _cursorX = cursorX.clamp(0, terminal.viewWidth - 1);
    _cursorY = cursorY.clamp(0, maxLine);
  }

  void movePosition(int offsetX, int offsetY) {
    final cursorX = _cursorX + offsetX;
    final cursorY = _cursorY + offsetY;
    setPosition(cursorX, cursorY);
  }

  void setScrollOffsetFromBottom(int offsetFromBottom) {
    if (height < terminal.viewHeight) return;
    final maxOffsetFromBottom = height - terminal.viewHeight;
    _scrollOffsetFromBottom = offsetFromBottom.clamp(0, maxOffsetFromBottom);
  }

  void setScrollOffsetFromTop(int offsetFromTop) {
    final bottomOffset = terminal.invisibleHeight - offsetFromTop;
    setScrollOffsetFromBottom(bottomOffset);
  }

  void screenScrollUp(int lines) {
    setScrollOffsetFromBottom(scrollOffsetFromBottom + lines);
  }

  void screenScrollDown(int lines) {
    setScrollOffsetFromBottom(scrollOffsetFromBottom - lines);
  }

  void saveCursor() {
    _savedCellFlags = terminal.cursor.flags;
    _savedCellFgColor = terminal.cursor.fg;
    _savedCellBgColor = terminal.cursor.bg;
    _savedCursorX = _cursorX;
    _savedCursorY = _cursorY;
    charset.save();
  }

  void restoreCursor() {
    if (_savedCellFlags != null) {
      terminal.cursor.flags = _savedCellFlags!;
    }

    if (_savedCellFgColor != null) {
      terminal.cursor.fg = _savedCellFgColor!;
    }

    if (_savedCellBgColor != null) {
      terminal.cursor.bg = _savedCellBgColor!;
    }

    if (_savedCursorX != null) {
      _cursorX = _savedCursorX!;
    }

    if (_savedCursorY != null) {
      _cursorY = _savedCursorY!;
    }

    charset.restore();
  }

  void setVerticalMargins(int top, int bottom) {
    _marginTop = top.clamp(0, terminal.viewHeight - 1);
    _marginBottom = bottom.clamp(0, terminal.viewHeight - 1);

    _marginTop = min(_marginTop, _marginBottom);
    _marginBottom = max(_marginTop, _marginBottom);
  }

  bool get hasScrollableRegion {
    return _marginTop > 0 || _marginBottom < (terminal.viewHeight - 1);
  }

  bool get isInScrollableRegion {
    return hasScrollableRegion &&
        _cursorY >= _marginTop &&
        _cursorY <= _marginBottom;
  }

  void resetVerticalMargins() {
    setVerticalMargins(0, terminal.viewHeight - 1);
  }

  void deleteChars(int count) {
    final start = _cursorX.clamp(0, terminal.viewWidth);
    final end = min(_cursorX + count, terminal.viewWidth);
    currentLine.removeRange(start, end);
  }

  void clearScrollback() {
    if (lines.length <= terminal.viewHeight) {
      return;
    }

    lines.trimStart(lines.length - terminal.viewHeight);
  }

  void clear() {
    lines.clear();
    for (int i = 0; i < terminal.viewHeight; i++) {
      lines.push(_newEmptyLine());
    }
  }

  void insertBlankCharacters(int count) {
    for (var i = 0; i < count; i++) {
      currentLine.insert(_cursorX + i);
      currentLine.cellSetFlags(_cursorX + i, terminal.cursor.flags);
    }
  }

  void insertLines(int count) {
    if (hasScrollableRegion && !isInScrollableRegion) {
      return;
    }

    setCursorX(0);

    for (var i = 0; i < count; i++) {
      insertLine();
    }
  }

  void insertLine() {
    if (!isInScrollableRegion) {
      final index = convertViewLineToRawLine(_cursorX);
      final newLine = _newEmptyLine();
      lines.insert(index, newLine);
    } else {
      final newLine = _newEmptyLine();
      lines.insert(_cursorY, newLine);
    }
  }

  void deleteLines(int count) {
    if (hasScrollableRegion && !isInScrollableRegion) {
      return;
    }

    setCursorX(0);

    for (var i = 0; i < count; i++) {
      deleteLine();
    }
  }

  void deleteLine() {
    final index = convertViewLineToRawLine(_cursorX);

    if (index >= height) {
      return;
    }

    lines.remove(index);
  }

  void resize(int oldWidth, int oldHeight, int newWidth, int newHeight) {
    if (newWidth > oldWidth) {
      lines.forEach((item) => item.ensure(newWidth));
    }

    if (newHeight > oldHeight) {
      while (lines.length < newHeight) {
        lines.push(_newEmptyLine());
      }
      // Grow larger
      for (var i = 0; i < newHeight - oldHeight; i++) {
        if (_cursorY < oldHeight - 1) {
          lines.push(_newEmptyLine());
        } else {
          _cursorY++;
        }
      }
    } else {
      // Shrink smaller
      for (var i = 0; i < oldHeight - newHeight; i++) {
        if (_cursorY < oldHeight - 1) {
          lines.pop();
        } else {
          _cursorY++;
        }
      }
    }

    // Ensure cursor is within the screen.
    _cursorX = _cursorX.clamp(0, newWidth - 1);
    _cursorY = _cursorY.clamp(0, newHeight - 1);

    if (!isAltBuffer) {
      final reflowStrategy = newWidth > oldWidth
          ? ReflowStrategyWider(this)
          : ReflowStrategyNarrower(this);
      reflowStrategy.reflow(newWidth, newHeight, oldWidth, oldHeight);
    }
  }

  BufferLine _newEmptyLine() {
    final line = BufferLine(length: terminal.viewWidth);
    return line;
  }

  adjustSavedCursor(int dx, int dy) {
    if (_savedCursorX != null) {
      _savedCursorX = _savedCursorX! + dx;
    }
    if (_savedCursorY != null) {
      _savedCursorY = _savedCursorY! + dy;
    }
  }
}
