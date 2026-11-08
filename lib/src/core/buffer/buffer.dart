import 'dart:math' show max, min;

import 'package:xterm/src/core/buffer/cell_offset.dart';
import 'package:xterm/src/core/buffer/line.dart';
import 'package:xterm/src/core/buffer/range_line.dart';
import 'package:xterm/src/core/buffer/range.dart';
import 'package:xterm/src/core/cell.dart';
import 'package:xterm/src/core/charset.dart';
import 'package:xterm/src/core/cursor.dart';
import 'package:xterm/src/core/reflow.dart';
import 'package:xterm/src/core/state.dart';
import 'package:xterm/src/utils/circular_buffer.dart';
import 'package:xterm/src/utils/unicode_width.dart';

class Buffer {
  final TerminalState terminal;

  final int maxLines;

  final bool isAltBuffer;

  /// Characters that break selection when calling [getWordBoundary]. If null,
  /// defaults to [defaultWordSeparators].
  final Set<int>? wordSeparators;

  Buffer(
    this.terminal, {
    required this.maxLines,
    required this.isAltBuffer,
    this.wordSeparators,
  }) {
    for (int i = 0; i < terminal.viewHeight; i++) {
      lines.push(_newEmptyLine());
    }

    resetVerticalMargins();
  }

  int _cursorX = 0;

  int _cursorY = 0;

  late int _marginTop;

  late int _marginBottom;

  var _savedCursorX = 0;

  var _savedCursorY = 0;

  final _savedCursorStyle = CursorStyle();

  /// The modes DECSC saves with the cursor. Each screen has its own, like the
  /// cursor itself.
  var savedOriginMode = false;

  var savedAutoWrapMode = true;

  final charset = Charset();

  /// Width of the viewport in columns. Also the index of the last column.
  int get viewWidth => terminal.viewWidth;

  /// Height of the viewport in rows. Also the index of the last line.
  int get viewHeight => terminal.viewHeight;

  /// lines of the buffer. the length of [lines] should always be equal or
  /// greater than [viewHeight].
  late final lines = IndexAwareCircularBuffer<BufferLine>(
    max(maxLines + viewHeight, viewHeight),
  );

  /// Total number of lines in the buffer. Always equal or greater than
  /// [viewHeight].
  int get height => lines.length;

  /// Horizontal position of the cursor relative to the top-left cornor of the
  /// screen, starting from 0.
  int get cursorX => _cursorX.clamp(0, terminal.viewWidth - 1);

  /// Vertical position of the cursor relative to the top-left cornor of the
  /// screen, starting from 0.
  int get cursorY => _cursorY;

  /// Index of the first line in the scroll region.
  int get marginTop => _marginTop;

  /// Index of the last line in the scroll region.
  int get marginBottom => _marginBottom;

  /// The number of lines above the viewport.
  int get scrollBack => height - viewHeight;

  /// Vertical position of the cursor relative to the top of the buffer,
  /// starting from 0.
  int get absoluteCursorY => _cursorY + scrollBack;

  /// Absolute index of the first line in the scroll region.
  int get absoluteMarginTop => _marginTop + scrollBack;

  /// Absolute index of the last line in the scroll region.
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
  /// Returns the code point that was written after charset translation, or
  /// null if the code point did not become a cell of its own, because it
  /// joined the cluster of the cell before it or because there was no such
  /// cell and it was dropped. `repeatPreviousCharacter` reads that return
  /// value, and a combining mark is not what REP should repeat.
  ///
  /// See also: [Terminal.writeChar]
  int? writeChar(int codePoint, {bool translate = true}) {
    if (translate) {
      codePoint = charset.translate(codePoint);
    }

    var cellWidth = unicodeWidth.wcwidth(codePoint);

    if (codePoint != 0 && (cellWidth == 0 || _continuesCluster(codePoint))) {
      // The code point belongs to the character before it rather than to a
      // column of its own. Appending leaves the cursor where it is, which is
      // where the program that wrote it believes the cursor to be.
      _appendToCluster(codePoint);
      return null;
    }

    if (_cursorX >= terminal.viewWidth) {
      if (terminal.autoWrapMode) {
        index();
        setCursorX(0);
        currentLine.isWrapped = true;
      } else {
        setCursorX(terminal.viewWidth - 1);
      }
    }

    if (cellWidth == 2 && _cursorX == terminal.viewWidth - 1) {
      if (terminal.autoWrapMode) {
        index();
        setCursorX(0);
        currentLine.isWrapped = true;
      } else {
        codePoint = 0x20;
        cellWidth = 1;
      }
    }

    final line = currentLine;
    if (codePoint != 0 && cellWidth > 0) {
      _prepareOverwrite(line, cellWidth);
    }
    if (terminal.insertMode && codePoint != 0 && cellWidth > 0) {
      line.insertCells(_cursorX, cellWidth, terminal.cursor);
    }
    line.setCell(_cursorX, codePoint, cellWidth, terminal.cursor);

    if (_cursorX < viewWidth) {
      _cursorX++;
    }

    if (cellWidth == 2) {
      writeChar(0, translate: false);
    }

    return codePoint;
  }

  /// The most UTF-16 code units one cell's text may grow to.
  ///
  /// Nothing legible needs anywhere near this many; the limit is there because
  /// a program can send combining marks indefinitely, and without it one column
  /// would hold a string that keeps growing.
  static const _maxClusterUnits = 32;

  static const _zeroWidthJoiner = 0x200D;

  /// Whether [codePoint] belongs to the cluster of the cell before the cursor
  /// even though it has a column width of its own.
  ///
  /// Two cases, neither of which the width table can express:
  ///
  /// - Anything following a zero width joiner. `👨‍👩‍👧` is three emoji and two
  ///   joiners, and every emoji after a joiner is East Asian Wide.
  /// - An emoji modifier, U+1F3FB to U+1F3FF, the skin tones. Also Wide, and
  ///   only ever rendered as part of the emoji before it.
  ///
  /// Regional indicators are deliberately absent. A flag is two of them and
  /// draws as one two-column glyph, but the width table gives each one column,
  /// so joining the pair would leave a two-column glyph in a one-column cell
  /// and push the rest of the line off the grid.
  bool _continuesCluster(int codePoint) {
    if (codePoint >= 0x1F3FB && codePoint <= 0x1F3FF) {
      return true;
    }

    final target = _clusterTarget();
    if (target == null) {
      return false;
    }

    // A joiner is itself zero width, so it is only ever inside a cluster, and
    // a cell without one cannot be holding it. That check is a single array
    // read, which is what this costs for ordinary text.
    final (line, x) = target;
    if (line.getContent(x) & CellContent.clusterFlag == 0) {
      return false;
    }

    // The flag is the gate and the text is the answer. They cannot disagree,
    // but reading the one that can be absent is what keeps a hole in that
    // invariant from being a crash rather than a missing mark.
    final cluster = line.getCluster(x);
    return cluster != null &&
        cluster.codeUnitAt(cluster.length - 1) == _zeroWidthJoiner;
  }

  /// Appends [codePoint] to the text of the cell it belongs to, if there is
  /// one. Dropping it is the alternative: giving it a cell of its own would
  /// advance the cursor past a column it does not fill.
  void _appendToCluster(int codePoint) {
    final target = _clusterTarget();
    if (target == null) {
      return;
    }

    final (line, x) = target;
    final existing =
        line.getCluster(x) ?? String.fromCharCode(line.getCodePoint(x));

    if (existing.length >= _maxClusterUnits) {
      return;
    }

    line.setCluster(x, existing + String.fromCharCode(codePoint));
  }

  /// The cell a zero-width or continuing code point attaches to, or null when
  /// there is none: at the start of the buffer, or after a column nothing has
  /// been written to.
  (BufferLine, int)? _clusterTarget() {
    var line = currentLine;
    var x = min(_cursorX, terminal.viewWidth) - 1;

    if (x < 0) {
      // A mark can arrive in the first column of a line the terminal wrapped,
      // in which case its base is the last cell of the line above.
      if (!line.isWrapped || absoluteCursorY == 0) {
        return null;
      }
      line = lines[absoluteCursorY - 1];
      x = line.length - 1;
      if (x < 0) {
        return null;
      }
    }

    // The right half of a wide character carries no code point; the base is the
    // column before it. An empty cell looks the same from here, so what
    // distinguishes them is the cell to the left being two columns wide.
    if (line.getCodePoint(x) == 0 && x > 0 && line.getWidth(x - 1) == 2) {
      x--;
    }

    if (line.getCodePoint(x) == 0) {
      return null;
    }

    return (line, x);
  }

  void _prepareOverwrite(BufferLine line, int cellWidth) {
    if (_cursorX > 0 && line.getWidth(_cursorX - 1) == 2) {
      line.eraseCell(_cursorX - 1, terminal.cursor);
    }

    if (terminal.insertMode) {
      return;
    }

    if (_cursorX < viewWidth - 1 &&
        (cellWidth == 2 || line.getWidth(_cursorX) == 2)) {
      line.eraseCell(_cursorX + 1, terminal.cursor);
    }
  }

  /// The line at the current cursor position.
  BufferLine get currentLine {
    return lines[absoluteCursorY];
  }

  void backspace() {
    if (_cursorX == 0 && currentLine.isWrapped) {
      currentLine.isWrapped = false;
      moveCursor(viewWidth - 1, -1);
    } else if (_cursorX >= viewWidth) {
      setCursorX(viewWidth - 1);
    } else {
      moveCursor(-1, 0);
    }
  }

  /// Erases the viewport from the cursor position to the end of the buffer,
  /// including the cursor position.
  void eraseDisplayFromCursor() {
    eraseLineFromCursor();

    for (var i = absoluteCursorY + 1; i < height; i++) {
      final line = lines[i];
      line.isWrapped = false;
      line.eraseRange(0, viewWidth, terminal.cursor);
    }
  }

  /// Erases the viewport from the top-left corner to the cursor, including the
  /// cursor.
  void eraseDisplayToCursor() {
    eraseLineToCursor();

    for (var i = 0; i < _cursorY; i++) {
      final line = lines[i + scrollBack];
      line.isWrapped = false;
      line.eraseRange(0, viewWidth, terminal.cursor);
    }
  }

  /// Erases the whole viewport.
  void eraseDisplay() {
    for (var i = 0; i < viewHeight; i++) {
      final line = lines[i + scrollBack];
      line.isWrapped = false;
      line.eraseRange(0, viewWidth, terminal.cursor);
    }
  }

  /// Erases the line from the cursor to the end of the line, including the
  /// cursor position.
  void eraseLineFromCursor() {
    // From the last column when a wrap is pending, as xterm does.
    _clearPendingWrap();
    currentLine.isWrapped = false;
    currentLine.eraseRange(_cursorX, viewWidth, terminal.cursor);
  }

  /// Erases the line from the start of the line to the cursor, including the
  /// cursor.
  void eraseLineToCursor() {
    currentLine.isWrapped = false;
    currentLine.eraseRange(0, _cursorX + 1, terminal.cursor);
  }

  /// Erases the line at the current cursor position.
  void eraseLine() {
    currentLine.isWrapped = false;
    currentLine.eraseRange(0, viewWidth, terminal.cursor);
  }

  /// Erases [count] cells starting at the cursor position.
  void eraseChars(int count) {
    _clearPendingWrap();
    if (count <= 0) {
      return;
    }

    final start = _cursorX;
    currentLine.eraseRange(start, start + count, terminal.cursor);
  }

  // Lines are moved with `swap`, as [insertLines] does, never by assigning one
  // slot's line to another: that leaves the line in both until the first slot
  // is overwritten, which detaches it from the second as well, and a detached
  // line in the buffer breaks the next insert or remove that moves it
  // (SERVERBOX-28). The empty line swapped in is the one the slot ends with,
  // so only a slot nothing was moved out of needs a new one.

  void scrollDown(int lines) {
    for (var i = absoluteMarginBottom; i >= absoluteMarginTop; i--) {
      if (i >= absoluteMarginTop + lines) {
        this.lines[i] = this.lines.swap(i - lines, _newEmptyLine());
      } else if (i > absoluteMarginBottom - lines) {
        this.lines[i] = _newEmptyLine();
      }
    }
  }

  void scrollUp(int lines) {
    for (var i = absoluteMarginTop; i <= absoluteMarginBottom; i++) {
      if (i <= absoluteMarginBottom - lines) {
        this.lines[i] = this.lines.swap(i + lines, _newEmptyLine());
      } else if (i < absoluteMarginTop + lines) {
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
    _clearPendingWrap();

    if (isInVerticalMargin) {
      if (_cursorY == _marginBottom) {
        if (marginTop == 0 && !isAltBuffer) {
          lines.insert(absoluteMarginBottom + 1, _newEmptyLine());
        } else {
          scrollUp(1);
        }
      } else {
        moveCursorY(1);
      }
      return;
    }

    // Outside the scroll region, which is then not the whole screen: nothing
    // scrolls, and at the last row the cursor stays put.
    if (_cursorY < viewHeight - 1) {
      moveCursorY(1);
    }
  }

  void lineFeed() {
    index();
    if (terminal.lineFeedMode) {
      setCursorX(0);
    }
  }

  void backIndex() {
    if (_cursorX == 0) {
      currentLine.insertCells(0, 1, terminal.cursor);
    } else {
      moveCursorX(-1);
    }
  }

  void forwardIndex() {
    if (_cursorX >= viewWidth - 1) {
      currentLine.removeCells(0, 1, terminal.cursor);
    } else {
      moveCursorX(1);
    }
  }

  /// https://terminalguide.namepad.de/seq/a_esc_cm/
  void reverseIndex() {
    _clearPendingWrap();

    if (isInVerticalMargin) {
      if (_cursorY == _marginTop) {
        scrollDown(1);
      } else {
        moveCursorY(-1);
      }
    } else {
      moveCursorY(-1);
    }
  }

  void cursorGoForward() {
    _cursorX = min(_cursorX + 1, viewWidth);
  }

  void _clearPendingWrap() {
    if (_cursorX >= viewWidth) {
      setCursorX(viewWidth - 1);
    }
  }

  void setCursorX(int cursorX) {
    _cursorX = cursorX.clamp(0, viewWidth - 1);
  }

  void setCursorY(int cursorY) {
    _clearPendingWrap();
    _cursorY = cursorY.clamp(0, viewHeight - 1);
  }

  void moveCursorX(int offset) {
    setCursorX(_cursorX + offset);
  }

  void moveCursorY(int offset) {
    _clearPendingWrap();

    final cursorY = _cursorY + offset;
    if (terminal.originMode) {
      _cursorY = cursorY.clamp(_marginTop, _marginBottom);
      return;
    }
    // A margin stops the cursor from the side it is on, as in xterm: one
    // within the region stays within it, and one outside crosses nothing.
    final top = _cursorY < _marginTop ? 0 : _marginTop;
    final bottom = _cursorY > _marginBottom ? viewHeight - 1 : _marginBottom;
    _cursorY = cursorY.clamp(top, bottom);
  }

  void setCursor(int cursorX, int cursorY) {
    var maxCursorY = viewHeight - 1;

    if (terminal.originMode) {
      cursorY += _marginTop;
      maxCursorY = _marginBottom;
    }

    _cursorX = cursorX.clamp(0, viewWidth - 1);
    _cursorY = cursorY.clamp(0, maxCursorY);
  }

  void moveCursor(int offsetX, int offsetY) {
    setCursorX(_cursorX + offsetX);
    moveCursorY(offsetY);
  }

  /// Save cursor position, charmap and text attributes.
  void saveCursor() {
    _savedCursorX = _cursorX;
    _savedCursorY = _cursorY;
    _savedCursorStyle.foreground = terminal.cursor.foreground;
    _savedCursorStyle.background = terminal.cursor.background;
    _savedCursorStyle.attrs = terminal.cursor.attrs;
    savedOriginMode = terminal.originMode;
    savedAutoWrapMode = terminal.autoWrapMode;
    charset.save();
  }

  /// Restore cursor position, charmap and text attributes.
  void restoreCursor() {
    _cursorX = _savedCursorX.clamp(0, viewWidth - 1);
    _cursorY = _savedCursorY.clamp(0, viewHeight - 1);
    terminal.cursor.foreground = _savedCursorStyle.foreground;
    terminal.cursor.background = _savedCursorStyle.background;
    terminal.cursor.attrs = _savedCursorStyle.attrs;
    charset.restore();
  }

  /// Sets the vertical scrolling margin to [top] and [bottom].
  /// Both values must be between 0 and [viewHeight] - 1.
  void setVerticalMargins(int top, int bottom) {
    _marginTop = top.clamp(0, viewHeight - 1);
    _marginBottom = bottom.clamp(0, viewHeight - 1);

    _marginTop = min(_marginTop, _marginBottom);
    _marginBottom = max(_marginTop, _marginBottom);
  }

  bool get isInVerticalMargin {
    return _cursorY >= _marginTop && _cursorY <= _marginBottom;
  }

  void resetVerticalMargins() {
    setVerticalMargins(0, viewHeight - 1);
  }

  void deleteChars(int count) {
    _clearPendingWrap();
    if (count <= 0) {
      return;
    }

    final start = _cursorX.clamp(0, viewWidth);
    count = min(count, viewWidth - start);
    currentLine.removeCells(start, count, terminal.cursor);
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
    for (int i = 0; i < viewHeight; i++) {
      lines.push(_newEmptyLine());
    }
  }

  void screenAlignmentPattern() {
    const codePoint = 0x45; // E
    for (var y = 0; y < viewHeight; y++) {
      final line = lines[scrollBack + y];
      line.isWrapped = false;
      for (var x = 0; x < viewWidth; x++) {
        line.setCell(x, codePoint, 1, terminal.cursor);
      }
    }
    // And, as in xterm, the margins reset and the cursor home.
    resetVerticalMargins();
    _cursorX = 0;
    _cursorY = 0;
  }

  /// Soft-resets state associated with this buffer without clearing content.
  /// DECSTR leaves the cursor where it is; only the saved one goes home.
  void softReset() {
    resetVerticalMargins();
    _savedCursorX = 0;
    _savedCursorY = 0;
    _savedCursorStyle.reset();
    savedOriginMode = false;
    savedAutoWrapMode = true;
    charset.reset();
  }

  /// Resets this buffer to its initial state.
  void reset() {
    clear();
    softReset();
    _cursorX = 0;
    _cursorY = 0;
  }

  void insertBlankChars(int count) {
    _clearPendingWrap();
    if (count <= 0) {
      return;
    }

    currentLine.insertCells(_cursorX, count, terminal.cursor);
  }

  void insertLines(int count) {
    if (count <= 0 || !isInVerticalMargin) {
      return;
    }

    setCursorX(0);

    // Number of lines from the cursor to the bottom of the scrollable region
    // including the cursor itself.
    final linesBelow = absoluteMarginBottom - absoluteCursorY + 1;

    // Number of empty lines to insert.
    final linesToInsert = min(count, linesBelow);

    // Number of lines to move up.
    final linesToMove = linesBelow - linesToInsert;

    for (var i = 0; i < linesToMove; i++) {
      final index = absoluteMarginBottom - i;
      lines[index] = lines.swap(index - linesToInsert, _newEmptyLine());
    }

    for (var i = linesToMove; i < linesToInsert; i++) {
      lines[absoluteCursorY + i] = _newEmptyLine();
    }
  }

  /// Remove [count] lines starting at the current cursor position. Lines below
  /// the removed lines are shifted up. This only affects the scrollable region.
  /// Lines outside the scrollable region are not affected.
  void deleteLines(int count) {
    if (count <= 0 || !isInVerticalMargin) {
      return;
    }

    setCursorX(0);

    count = min(count, absoluteMarginBottom - absoluteCursorY + 1);

    final linesToMove = absoluteMarginBottom - absoluteCursorY + 1 - count;

    // `swap`, for the reason given above [scrollDown].
    for (var i = 0; i < linesToMove; i++) {
      final index = absoluteCursorY + i;
      lines[index] = lines.swap(index + count, _newEmptyLine());
    }

    // Slots a line was moved out of already hold the empty line swapped in.
    for (var i = 0; i < count; i++) {
      final index = absoluteMarginBottom - i;
      if (index - count < absoluteCursorY) lines[index] = _newEmptyLine();
    }
  }

  void resize(int oldWidth, int oldHeight, int newWidth, int newHeight) {
    final requiredMaxLength = max(maxLines + newHeight, newHeight);
    if (lines.maxLength < requiredMaxLength) {
      lines.maxLength = requiredMaxLength;
    }

    // 1. Adjust the height.
    if (newHeight > oldHeight) {
      // Grow larger
      for (var i = 0; i < newHeight - oldHeight; i++) {
        if (newHeight > lines.length) {
          lines.push(_newEmptyLine(newWidth));
        } else {
          _cursorY++;
        }
      }
    } else {
      // Shrink smaller
      for (var i = 0; i < oldHeight - newHeight; i++) {
        if (_cursorY > newHeight - 1) {
          _cursorY--;
        } else {
          lines.pop();
        }
      }
    }

    // Ensure cursor is within the screen.
    _cursorY = _cursorY.clamp(0, newHeight - 1);

    // 2. Adjust the width.
    if (newWidth != oldWidth) {
      if (terminal.reflowEnabled && !isAltBuffer) {
        // The cursor goes where the text it is in goes. `viewHeight` is still
        // the old height here, so the screen's top is worked out by hand.
        final cursor = lines[_cursorY + lines.length - newHeight].createAnchor(
          _cursorX,
        );

        final reflowResult = reflow(lines, oldWidth, newWidth);

        while (reflowResult.length < newHeight) {
          reflowResult.add(_newEmptyLine(newWidth));
        }

        lines.replaceWith(reflowResult);

        if (cursor.attached) {
          _cursorX = cursor.x;
          _cursorY = (cursor.y - (lines.length - newHeight)).clamp(
            0,
            newHeight - 1,
          );
        }
        cursor.dispose();
      } else {
        lines.forEach((item) => item.resize(newWidth, keepHidden: true));
      }
    }

    _cursorX = _cursorX.clamp(0, newWidth - 1);
  }

  /// Create a new [CellAnchor] at the specified [x] and [y] coordinates.
  CellAnchor createAnchor(int x, int y) {
    return lines[y].createAnchor(x);
  }

  /// Create a new [CellAnchor] at the specified [x] and [y] coordinates.
  ///
  /// Clamped to the nearest cell that exists. A selection holds offsets across
  /// frames, and the buffer can lose rows under it — a clear, a switch to the
  /// alternate screen, a reflow — so an offset taken a moment ago may point
  /// past the end by the time it is anchored (SERVERBOX-20P, SERVERBOX-R).
  CellAnchor createAnchorFromOffset(CellOffset offset) {
    final line = lines[offset.y.clamp(0, lines.length - 1)];
    return line.createAnchor(offset.x.clamp(0, line.length));
  }

  CellAnchor createAnchorFromCursor() {
    return createAnchor(cursorX, absoluteCursorY);
  }

  /// Create a new empty [BufferLine] with the current [viewWidth] if [width]
  /// is not specified.
  BufferLine _newEmptyLine([int? width]) {
    final line = BufferLine(width ?? viewWidth);
    return line;
  }

  static final defaultWordSeparators = <int>{
    0,
    r' '.codeUnitAt(0),
    r'.'.codeUnitAt(0),
    r':'.codeUnitAt(0),
    r'-'.codeUnitAt(0),
    r'\'.codeUnitAt(0),
    r'"'.codeUnitAt(0),
    r'*'.codeUnitAt(0),
    r'+'.codeUnitAt(0),
    r'/'.codeUnitAt(0),
    r'\'.codeUnitAt(0),
  };

  BufferRangeLine? getWordBoundary(CellOffset position) {
    var separators = wordSeparators ?? defaultWordSeparators;
    if (position.y >= lines.length) {
      return null;
    }

    var line = lines[position.y];
    var start = position.x;
    var end = position.x;

    // The second column of a wide character holds no code point, which reads
    // as 0, a separator; it is part of the character to its left.
    bool isSeparator(int x) {
      final char = line.getCodePoint(x);
      if (char == 0 && x > 0 && line.getWidth(x - 1) == 2) {
        return separators.contains(line.getCodePoint(x - 1));
      }
      return separators.contains(char);
    }

    do {
      if (start == 0) {
        break;
      }
      if (isSeparator(start - 1)) {
        break;
      }
      start--;
    } while (true);

    do {
      if (end >= viewWidth) {
        break;
      }
      if (isSeparator(end)) {
        break;
      }
      end++;
    } while (true);

    if (start == end) {
      return null;
    }

    return BufferRangeLine(
      CellOffset(start, position.y),
      CellOffset(end, position.y),
    );
  }

  /// Get the plain text content of the buffer including the scrollback.
  /// Accepts an optional [range] to get a specific part of the buffer.
  ///
  /// Blanks inside a line are kept and blanks at the end of one are not. A
  /// hole a tab or a cursor move left is part of what the line looks like and
  /// the columns to its right depend on it; the untouched cells a line ends
  /// with are not something anyone selected, and carrying them into the
  /// clipboard puts a ragged right edge into whatever it is pasted in.
  ///
  /// A wrapped line is one line for that purpose: its parts are joined and
  /// only the end of the last of them is trimmed, so a line that wrapped on a
  /// space keeps it.
  String getText([BufferRange? range]) {
    // The end is exclusive, so the last column is `viewWidth`.
    range ??= BufferRangeLine(
      CellOffset(0, 0),
      CellOffset(viewWidth, height - 1),
    );

    range = range.normalized;

    // Only a line range trims. A block range's right edge is a column the
    // caller named rather than the end of whatever happened to be written, so
    // the blanks up to it are part of what was asked for.
    final trimRight = range is BufferRangeLine;

    final segments = range.toSegments().toList(growable: false);
    final builder = StringBuffer();
    var started = false;

    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];
      if (segment.line < 0 || segment.line >= height) {
        continue;
      }
      final line = lines[segment.line];
      // A block is its rows, each on its own, whether or not they wrapped.
      if (started && (!trimRight || !line.isWrapped)) {
        builder.write("\n");
      }
      started = true;

      final next = i + 1 < segments.length ? segments[i + 1] : null;
      final continues = next != null &&
          next.line >= 0 &&
          next.line < height &&
          lines[next.line].isWrapped;

      builder.write(
        line.getText(segment.start, segment.end, trimRight && !continues),
      );
    }

    return builder.toString();
  }

  /// Returns a debug representation of the buffer.
  @override
  String toString() {
    final builder = StringBuffer();
    final lineNumberLength = lines.length.toString().length;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      builder.write('${i.toString().padLeft(lineNumberLength)}: |${lines[i]}|');

      if (line.isWrapped) {
        builder.write(' (⏎)');
      }

      builder.write('\n');
    }

    return builder.toString();
  }
}
