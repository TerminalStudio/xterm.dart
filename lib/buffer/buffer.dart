import 'dart:math' show max, min;

import 'package:xterm/buffer/buffer_line.dart';
import 'package:xterm/buffer/cell.dart';
import 'package:xterm/buffer/cell_attr.dart';
import 'package:xterm/terminal/charset.dart';
import 'package:xterm/terminal/terminal.dart';
import 'package:xterm/utli/scroll_range.dart';
import 'package:xterm/utli/unicode_v11.dart';

class Buffer {
  Buffer(this.terminal) {
    resetVerticalMargins();
  }

  final Terminal terminal;
  final lines = <BufferLine>[];
  final charset = Charset();

  int _cursorX = 0;
  int _cursorY = 0;
  int _savedCursorX;
  int _savedCursorY;
  int _scrollLinesFromBottom = 0;
  int _marginTop;
  int _marginBottom;
  CellAttr _savedCellAttr;

  int get cursorX => _cursorX.clamp(0, terminal.viewWidth - 1);
  int get cursorY => _cursorY;
  int get marginTop => _marginTop;
  int get marginBottom => _marginBottom;

  void write(String text) {
    for (var char in text.runes) {
      writeChar(char);
    }
  }

  void writeChar(int codePoint) {
    codePoint = charset.translate(codePoint);

    final cellWidth = unicodeV11.wcwidth(codePoint);
    if (_cursorX >= terminal.viewWidth) {
      newLine();
      setCursorX(0);
    }

    final line = currentLine;
    while (line.length <= _cursorX) {
      line.add(Cell());
    }

    final cell = line.getCell(_cursorX);
    cell.setCodePoint(codePoint);
    cell.setWidth(cellWidth);
    cell.setAttr(terminal.cellAttr.copy());

    if (_cursorX < terminal.viewWidth) {
      _cursorX++;
    }

    if (cellWidth == 2) {
      writeChar(0);
    }
  }

  BufferLine getViewLine(int index) {
    if (index > terminal.viewHeight) {
      return lines.last;
    }

    while (index >= lines.length) {
      final newLine = BufferLine();
      lines.add(newLine);
    }

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
    if (terminal.lineFeed == false) {
      setCursorX(0);
    }

    index();
  }

  void carriageReturn() {
    setCursorX(0);
  }

  void backspace() {
    if (_cursorX == 0 && currentLine.isWrapped) {
      movePosition(terminal.viewWidth - 1, -1);
    } else if (_cursorX == terminal.viewWidth) {
      movePosition(-2, 0);
    } else {
      movePosition(-1, 0);
    }
  }

  List<BufferLine> getVisibleLines() {
    final result = <BufferLine>[];

    for (var i = height - terminal.viewHeight; i < height; i++) {
      final y = i - scrollOffset;
      if (y >= 0 && y < height) {
        result.add(lines[y]);
      }
    }

    return result;
  }

  void eraseDisplayFromCursor() {
    eraseLineFromCursor();

    for (var i = _cursorY + 1; i < terminal.viewHeight; i++) {
      getViewLine(i).erase(terminal.cellAttr.copy(), 0, terminal.viewWidth);
    }
  }

  void eraseDisplayToCursor() {
    eraseLineToCursor();

    for (var i = 0; i < _cursorY; i++) {
      getViewLine(i).erase(terminal.cellAttr.copy(), 0, terminal.viewWidth);
    }
  }

  void eraseDisplay() {
    for (var i = 0; i < terminal.viewHeight; i++) {
      final line = getViewLine(i);
      line.erase(terminal.cellAttr.copy(), 0, terminal.viewWidth);
    }
  }

  void eraseLineFromCursor() {
    currentLine.erase(terminal.cellAttr.copy(), _cursorX, terminal.viewWidth);
  }

  void eraseLineToCursor() {
    currentLine.erase(terminal.cellAttr.copy(), 0, _cursorX);
  }

  void eraseLine() {
    currentLine.erase(terminal.cellAttr.copy(), 0, terminal.viewWidth);
  }

  void eraseCharacters(int count) {
    final start = _cursorX;
    for (var i = start; i < start + count; i++) {
      if (i >= currentLine.length) {
        currentLine.add(Cell(attr: terminal.cellAttr.copy()));
      } else {
        currentLine.getCell(i).erase(terminal.cellAttr.copy());
      }
    }
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
        this.lines[i] = BufferLine();
      }
    }
  }

  void areaScrollUp(int lines) {
    final scrollRange = getAreaScrollRange();

    for (var i = scrollRange.top; i < scrollRange.bottom; i++) {
      if (i + lines < scrollRange.bottom) {
        this.lines[i] = this.lines[i + lines];
      } else {
        this.lines[i] = BufferLine();
      }
    }
  }

  /// https://vt100.net/docs/vt100-ug/chapter3.html#IND
  void index() {
    if (isInScrollableRegion) {
      if (_cursorY < _marginBottom) {
        moveCursorY(1);
      } else {
        areaScrollUp(1);
      }
      return;
    }

    if (_cursorY >= terminal.viewHeight - 1) {
      lines.add(BufferLine());
      if (terminal.maxLines != null && lines.length > terminal.maxLines) {
        lines.removeRange(0, lines.length - terminal.maxLines);
      }
    } else {
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

  Cell getCell(int col, int row) {
    final rawRow = convertViewLineToRawLine(row);
    return getRawCell(col, rawRow);
  }

  Cell getRawCell(int col, int rawRow) {
    if (col < 0 || rawRow < 0 || rawRow >= lines.length) {
      return null;
    }

    final line = lines[rawRow];
    if (col >= line.length) {
      return null;
    }

    return line.getCell(col);
  }

  Cell getCellUnderCursor() {
    return getCell(cursorX, cursorY);
  }

  void cursorGoForward() {
    setCursorX(_cursorX + 1);
    terminal.refresh();
  }

  void setCursorX(int cursorX) {
    _cursorX = cursorX.clamp(0, terminal.viewWidth - 1);
    terminal.refresh();
  }

  void setCursorY(int cursorY) {
    _cursorY = cursorY.clamp(0, terminal.viewHeight - 1);
    terminal.refresh();
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

  int get scrollOffset {
    return _scrollLinesFromBottom;
  }

  void setScrollOffset(int offset) {
    if (height < terminal.viewHeight) return;
    final maxOffset = height - terminal.viewHeight;
    _scrollLinesFromBottom = offset.clamp(0, maxOffset);
    terminal.refresh();
  }

  void screenScrollUp(int lines) {
    setScrollOffset(scrollOffset + lines);
  }

  void screenScrollDown(int lines) {
    setScrollOffset(scrollOffset - lines);
  }

  void saveCursor() {
    _savedCellAttr = terminal.cellAttr.copy();
    _savedCursorX = _cursorX;
    _savedCursorY = _cursorY;
    charset.save();
  }

  void restoreCursor() {
    if (_savedCellAttr != null) {
      terminal.cellAttr = _savedCellAttr.copy();
    }

    if (_savedCursorX != null) {
      _cursorX = _savedCursorX;
    }

    if (_savedCursorY != null) {
      _cursorY = _savedCursorY;
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
    final start = _cursorX.clamp(0, currentLine.length);
    final end = min(_cursorX + count, currentLine.length);
    currentLine.removeRange(start, end);
  }

  void clearScrollback() {
    if (lines.length <= terminal.viewHeight) {
      return;
    }

    lines.removeRange(0, lines.length - terminal.viewHeight);
  }

  void clear() {
    lines.clear();
  }

  void insertBlankCharacters(int count) {
    for (var i = 0; i < count; i++) {
      final cell = Cell(attr: terminal.cellAttr.copy());
      currentLine.insert(_cursorX + i, cell);
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
      final newLine = BufferLine();
      lines.insert(index, newLine);

      if (terminal.maxLines != null && lines.length > terminal.maxLines) {
        lines.removeRange(0, lines.length - terminal.maxLines);
      }
    } else {
      final bottom = convertViewLineToRawLine(marginBottom);

      final movedLines = lines.getRange(_cursorY, bottom - 1);
      lines.setRange(_cursorY + 1, bottom, movedLines);

      final newLine = BufferLine();
      lines[_cursorY] = newLine;
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

    lines.removeAt(index);
  }
}
