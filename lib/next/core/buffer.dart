import 'dart:math' show max, min;

import 'package:xterm/buffer/line/line.dart';
// import 'package:xterm/buffer/reflow_strategy_narrower.dart';
// import 'package:xterm/buffer/reflow_strategy_wider.dart';
import 'package:xterm/terminal/charset.dart';
import 'package:xterm/terminal/terminal.dart';
import 'package:xterm/util/circular_list.dart';
import 'package:xterm/util/scroll_range.dart';
import 'package:xterm/util/unicode_v11.dart';

class Buffer {
  final Terminal terminal;

  final bool isAltBuffer;

  Buffer({
    required this.terminal,
    required this.isAltBuffer,
  }) {
    for (int i = 0; i < terminal.viewHeight; i++) {
      lines.push(_newEmptyLine());
    }

    resetVerticalMargins();
  }

  int? _savedCursorX;
  int? _savedCursorY;
  int? _savedCellFgColor;
  int? _savedCellBgColor;
  int? _savedCellFlags;

  int _cursorX = 0;

  int _cursorY = 0;

  late int _marginTop;

  late int _marginBottom;

  final charset = Charset();

  /// Width of the viewport in columns.
  int get viewWidth => terminal.viewWidth;

  /// Height of the viewport in rows.
  int get viewHeight => terminal.viewHeight;

  /// lines of the buffer. the length of [lines] should always be equal or
  /// greater than [viewHeight].
  late final lines = CircularList<BufferLine>(terminal.maxLines);

  /// Total number of lines in the buffer. Always equal or greater than
  /// [viewHeight].
  int get height => lines.length;

  /// Horizontal position of the cursor relative to the top-left cornor of the
  /// screen, starting from 0.
  int get cursorX => _cursorX.clamp(0, terminal.viewWidth - 1);

  /// Vertical position of the cursor relative to the top-left cornor of the
  /// screen, starting from 0.
  int get cursorY => _cursorY;

  /// Top margin of the scrolling region relative to the top of the viewport,
  /// starting from 0. 0 <= [marginTop] <= [marginBottom].
  int get marginTop => _marginTop;

  /// Bottom margin of the scrolling region relative to the top of the viewport,
  /// starting from 0. [marginTop] <= [marginBottom] <=  [viewHeight] - 1.
  int get marginBottom => _marginBottom;

  /// The number of lines above the viewport.
  int get scrollBack => height - viewHeight;

  /// Vertical position of the cursor relative to the top of the buffer,
  /// starting from 0.
  int get absoluteCursorY => _cursorY + scrollBack;

  /// Top margin of the scrolling region relative to the top of the buffer.
  int get absoluteMarginTop => _marginTop + scrollBack;

  /// Bottom margin of the scrolling region relative to the top of the buffer.
  int get absoluteMarginBottom => _marginBottom + scrollBack;

  /// Writes data to the _terminal. Terminal sequences or special characters are
  /// not interpreted and directly added to the buffer.
  ///
  /// See also: [Terminal.write]
  void write(String text) {
    for (var char in text.runes) {
      writeChar(char);
    }
  }

  /// Writes a single character to the _terminal. Escape sequences or special
  /// characters are not interpreted and directly added to the buffer.
  ///
  /// See also: [Terminal.writeChar]
  void writeChar(int codePoint) {
    codePoint = charset.translate(codePoint);

    final cellWidth = unicodeV11.wcwidth(codePoint);
    if (_cursorX >= terminal.viewWidth) {
      index();
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

  /// The line at the current cursor position.
  BufferLine get currentLine {
    return lines[absoluteCursorY];
  }

  // void newLine() {
  //   if (terminal.newLineMode) {
  //     setCursorX(0);
  //   }

  //   index();
  // }

  /// Moves the cursor to the start of the current line.
  void carriageReturn() {
    setCursorX(0);
  }

  void backspace() {
    if (_cursorX == 0 && currentLine.isWrapped) {
      currentLine.isWrapped = false;
      moveCursor(viewWidth - 1, -1);
    } else if (_cursorX == terminal.viewWidth) {
      moveCursor(-2, 0);
    } else {
      moveCursor(-1, 0);
    }
  }

  /// Erases the viewport from the cursor position to the end of the buffer,
  /// including the cursor position.
  void eraseDisplayFromCursor() {
    eraseLineFromCursor();

    for (var i = absoluteCursorY; i < height; i++) {
      final line = lines[i];
      line.isWrapped = false;
      line.erase(terminal.cursor, 0, terminal.viewWidth);
    }
  }

  /// Erases the viewport from the top-left corner to the cursor, including the
  /// cursor.
  void eraseDisplayToCursor() {
    eraseLineToCursor();

    for (var i = 0; i < _cursorY; i++) {
      final line = lines[i + scrollBack];
      line.isWrapped = false;
      line.erase(terminal.cursor, 0, terminal.viewWidth);
    }
  }

  /// Erases the whole viewport.
  void eraseDisplay() {
    for (var i = 0; i < viewHeight; i++) {
      final line = lines[i + scrollBack];
      line.isWrapped = false;
      line.erase(terminal.cursor, 0, terminal.viewWidth);
    }
  }

  /// Erases the line from the cursor to the end of the line, including the
  /// cursor position.
  void eraseLineFromCursor() {
    currentLine.isWrapped = false;
    currentLine.erase(terminal.cursor, _cursorX, terminal.viewWidth);
  }

  /// Erases the line from the start of the line to the cursor, including the
  /// cursor.
  void eraseLineToCursor() {
    currentLine.isWrapped = false;
    currentLine.erase(terminal.cursor, 0, _cursorX);
  }

  /// Erases the line at the current cursor position.
  void eraseLine() {
    currentLine.isWrapped = false;
    currentLine.erase(terminal.cursor, 0, terminal.viewWidth);
  }

  /// Erases [count] cells starting at the cursor position.
  void eraseCharacters(int count) {
    final start = _cursorX;
    currentLine.erase(terminal.cursor, start, start + count);
  }

  ScrollRange getAreaScrollRange() {
    var top = absoluteMarginTop;
    var bottom = absoluteMarginBottom + 1;
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

  void setCursor(int cursorX, int cursorY) {
    var maxLine = terminal.viewHeight - 1;

    if (terminal.originMode) {
      cursorY += _marginTop;
      maxLine = _marginBottom;
    }

    _cursorX = cursorX.clamp(0, terminal.viewWidth - 1);
    _cursorY = cursorY.clamp(0, maxLine);
  }

  void moveCursor(int offsetX, int offsetY) {
    final cursorX = _cursorX + offsetX;
    final cursorY = _cursorY + offsetY;
    setCursor(cursorX, cursorY);
  }

  /// Save cursor position, charmap and text attributes.
  void saveCursor() {
    _savedCellFlags = terminal.cursor.flags;
    _savedCellFgColor = terminal.cursor.fg;
    _savedCellBgColor = terminal.cursor.bg;
    _savedCursorX = _cursorX;
    _savedCursorY = _cursorY;
    charset.save();
  }

  /// Restore cursor position, charmap and text attributes.
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

  /// Sets the vertical scrolling margin to [top] and [bottom].
  /// Both values must be between 0 and [terminal.viewHeight] - 1.
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

  /// Remove all lines above the top of the viewport.
  void clearScrollback() {
    if (height <= viewHeight) {
      return;
    }

    lines.trimStart(scrollBack);
  }

  /// Clears the viewport and scrollback buffer. Then fill with empty lines.
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
      final newLine = _newEmptyLine();
      lines.insert(absoluteCursorY, newLine);
    } else {
      final newLine = _newEmptyLine();
      lines.insert(_cursorY, newLine);
    }
  }

  // void deleteLines(int count) {
  //   if (hasScrollableRegion && !isInScrollableRegion) {
  //     return;
  //   }

  //   setCursorX(0);

  //   for (var i = 0; i < count; i++) {
  //     deleteLine();
  //   }
  // }

  // void deleteLine() {
  //   final index = convertViewLineToRawLine(_cursorX);

  //   if (index >= height) {
  //     return;
  //   }

  //   lines.remove(index);
  // }

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

    // if (!isAltBuffer) {
    //   final reflowStrategy = newWidth > oldWidth
    //       ? ReflowStrategyWider(this)
    //       : ReflowStrategyNarrower(this);
    //   reflowStrategy.reflow(newWidth, newHeight, oldWidth, oldHeight);
    // }
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
