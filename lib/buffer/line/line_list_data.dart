import 'dart:math';

import 'package:xterm/buffer/line/line.dart';
import 'package:xterm/terminal/cursor.dart';

/// Line layout:
///   |  cell  |  cell  |  cell  |  cell  | ...
///   (4 ints per cell)
///
/// Cell layout:
///   | code point |  fg color  |  bg color  | attributes |
///       1 int        1 int        1 int        1 int
///
/// Attributes layout:
///   |  width  |  flags  | reserved | reserved |
///      1byte     1byte     1byte      1byte

const _cellSize = 4;

const _cellContent = 0;
const _cellFgColor = 1;
const _cellBgColor = 2;
const _cellAttributes = 3;

const _cellWidth = 0;
const _cellFlags = 8;

int _nextLength(int lengthRequirement) {
  var nextLength = 2;
  while (nextLength < lengthRequirement) {
    nextLength *= 2;
  }
  return nextLength;
}

/// [List] based [BufferLineData], used in browser where ByteData is not avaliable.
class ListBufferLineData with BufferLineData {
  ListBufferLineData(int length, this.isWrapped) {
    _maxCols = _nextLength(length);
    _cells = List.filled(_maxCols * _cellSize, 0);
  }

  late List<int> _cells;

  @override
  bool isWrapped;

  int _maxCols = 64;

  @override
  void ensure(int length) {
    if (length <= _maxCols) {
      return;
    }

    final nextLength = _nextLength(length);
    final newCells = List.filled(nextLength * _cellSize, 0);
    newCells.setAll(0, _cells);
    _cells = newCells;
    _maxCols = nextLength;
  }

  @override
  void insert(int index) {
    insertN(index, 1);
  }

  @override
  void removeN(int index, int count) {
    final moveStart = index * _cellSize;
    final moveOffset = count * _cellSize;
    final moveEnd = (_maxCols - count) * _cellSize;
    final bufferEnd = _maxCols * _cellSize;

    // move data backward
    for (var i = moveStart; i < moveEnd; i++) {
      _cells[i] = _cells[i + moveOffset];
    }

    // set empty cells to 0
    for (var i = moveEnd; i < bufferEnd; i++) {
      _cells[i] = 0x00;
    }
  }

  @override
  void insertN(int index, int count) {
    final moveStart = index * _cellSize;
    final moveOffset = count * _cellSize;
    final bufferEnd = _maxCols * _cellSize;

    // move data forward
    for (var i = bufferEnd - moveOffset - 1; i >= moveStart; i--) {
      _cells[i + moveOffset] = _cells[i];
    }

    // set inserted cells to 0
    for (var i = moveStart; i < moveStart + moveOffset; i++) {
      _cells[i] = 0x00;
    }
  }

  @override
  void clear() {
    clearRange(0, _cells.length ~/ _cellSize);
  }

  @override
  void erase(Cursor cursor, int start, int end, [bool resetIsWrapped = false]) {
    ensure(end);
    for (var i = start; i < end; i++) {
      cellErase(i, cursor);
    }
    if (resetIsWrapped) {
      isWrapped = false;
    }
  }

  @override
  void cellClear(int index) {
    _cells.fillRange(index * _cellSize, index * _cellSize + _cellSize, 0);
  }

  @override
  void cellInitialize(
    int index, {
    required int content,
    required int width,
    required Cursor cursor,
  }) {
    final cell = index * _cellSize;
    _cells[cell + _cellContent] = content;
    _cells[cell + _cellFgColor] = cursor.fg;
    _cells[cell + _cellBgColor] = cursor.bg;
    _cells[cell + _cellAttributes] =
        (width << _cellWidth) + (cursor.flags << _cellFlags);
  }

  @override
  bool cellHasContent(int index) {
    return cellGetContent(index) != 0;
  }

  @override
  int cellGetContent(int index) {
    if (index >= _maxCols) return 0;
    return _cells[index * _cellSize + _cellContent];
  }

  @override
  void cellSetContent(int index, int content) {
    _cells[index * _cellSize + _cellContent] = content;
  }

  @override
  int cellGetFgColor(int index) {
    if (index >= _maxCols) return 0;
    return _cells[index * _cellSize + _cellFgColor];
  }

  @override
  void cellSetFgColor(int index, int color) {
    _cells[index * _cellSize + _cellFgColor] = color;
  }

  @override
  int cellGetBgColor(int index) {
    if (index >= _maxCols) return 0;
    return _cells[index * _cellSize + _cellBgColor];
  }

  @override
  void cellSetBgColor(int index, int color) {
    _cells[index * _cellSize + _cellBgColor] = color;
  }

  @override
  int cellGetFlags(int index) {
    if (index >= _maxCols) return 0;
    final offset = index * _cellSize + _cellAttributes;
    return (_cells[offset] >> _cellFlags) & 0xFF;
  }

  @override
  void cellSetFlags(int index, int flags) {
    final offset = index * _cellSize + _cellAttributes;
    var result = _cells[offset];
    result |= 0xFF << _cellFlags;
    result &= flags << _cellFlags;
    _cells[offset] = result;
  }

  @override
  int cellGetWidth(int index) {
    if (index >= _maxCols) return 0;
    final offset = index * _cellSize + _cellAttributes;
    return (_cells[offset] >> _cellWidth) & 0xFF;
  }

  @override
  void cellSetWidth(int index, int width) {
    final offset = index * _cellSize + _cellAttributes;
    var result = _cells[offset];
    result |= 0xFF << _cellWidth;
    result &= width << _cellWidth;
    _cells[offset] = result;
  }

  @override
  void cellClearFlags(int index) {
    cellSetFlags(index, 0);
  }

  @override
  bool cellHasFlag(int index, int flag) {
    if (index >= _maxCols) {
      return false;
    }
    return cellGetFlags(index) & flag != 0;
  }

  @override
  void cellSetFlag(int index, int flag) {
    cellSetFlags(index, cellGetFlags(index) | flag);
  }

  @override
  void cellErase(int index, Cursor cursor) {
    cellSetContent(index, 0x00);
    cellSetFgColor(index, cursor.fg);
    cellSetBgColor(index, cursor.bg);
    cellSetFlags(index, cursor.flags);
    cellSetWidth(index, 0);
  }

  @override
  int getTrimmedLength([int? cols]) {
    cols ??= _maxCols;
    for (var i = cols - 1; i >= 0; i--) {
      if (cellGetContent(i) != 0) {
        // we are at the last cell in this line that has content.
        // the length of this line is the index of this cell + 1
        // the only exception is that if that last cell is wider
        // than 1 then we have to add the diff
        final lastCellWidth = cellGetWidth(i);
        return i + lastCellWidth;
      }
    }
    return 0;
  }

  @override
  void copyCellsFrom(ListBufferLineData src, int srcCol, int dstCol, int len) {
    ensure(dstCol + len);

    final intsToCopy = len * _cellSize;
    final srcStart = srcCol * _cellSize;
    final dstStart = dstCol * _cellSize;

    final cells = _cells;
    final srcCells = src._cells;
    for (var i = 0; i < intsToCopy; i++) {
      cells[dstStart + i] = srcCells[srcStart + i];
    }
  }

  @override
  void removeRange(int start, int end) {
    end = min(end, _maxCols);
    removeN(start, end - start);
  }

  @override
  void clearRange(int start, int end) {
    end = min(end, _maxCols);
    for (var index = start; index < end; index++) {
      cellClear(index);
    }
  }

  @override
  String toString() {
    final result = StringBuffer();
    for (int i = 0; i < _maxCols; i++) {
      final code = cellGetContent(i);
      if (code == 0) {
        continue;
      }
      result.writeCharCode(code);
    }
    return result.toString();
  }
}
