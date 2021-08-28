import 'dart:math';
import 'dart:typed_data';

import 'package:xterm/buffer/line/line.dart';
import 'package:xterm/terminal/cursor.dart';

/// Line layout:
///   |  cell  |  cell  |  cell  |  cell  | ...
///   (16 bytes per cell)
///
/// Cell layout:
///   | code point |  fg color  |  bg color  | attributes |
///       4bytes       4bytes       4bytes       4bytes
///
/// Attributes layout:
///   |  width  |  flags  | reserved | reserved |
///      1byte     1byte     1byte      1byte

const _cellSize = 16;
const _cellSize64Bit = _cellSize >> 3;

const _cellContent = 0;
const _cellFgColor = 4;
const _cellBgColor = 8;

// const _cellAttributes = 12;
const _cellWidth = 12;
const _cellFlags = 13;

int _nextLength(int lengthRequirement) {
  var nextLength = 2;
  while (nextLength < lengthRequirement) {
    nextLength *= 2;
  }
  return nextLength;
}

/// [ByteData] based [BufferLineData], used in non-web platforms to minimize memory
/// footprint,
class ByteDataBufferLineData with BufferLineData {
  ByteDataBufferLineData(int length, this.isWrapped) {
    _maxCols = _nextLength(length);
    _cells = ByteData(_maxCols * _cellSize);
  }

  late ByteData _cells;

  bool isWrapped;

  int _maxCols = 64;

  void ensure(int length) {
    if (length <= _maxCols) {
      return;
    }

    final nextLength = _nextLength(length);
    final newCells = ByteData(nextLength * _cellSize);
    newCells.buffer.asInt64List().setAll(0, _cells.buffer.asInt64List());
    _cells = newCells;
    _maxCols = nextLength;
  }

  void insert(int index) {
    insertN(index, 1);
  }

  void removeN(int index, int count) {
    final moveStart = index * _cellSize64Bit;
    final moveOffset = count * _cellSize64Bit;
    final moveEnd = (_maxCols - count) * _cellSize64Bit;
    final bufferEnd = _maxCols * _cellSize64Bit;

    // move data backward
    final cells = _cells.buffer.asInt64List();
    for (var i = moveStart; i < moveEnd; i++) {
      cells[i] = cells[i + moveOffset];
    }

    // set empty cells to 0
    for (var i = moveEnd; i < bufferEnd; i++) {
      cells[i] = 0x00;
    }
  }

  void insertN(int index, int count) {
    //                       start
    // +--------------------------|-----------------------------------+
    // |                          |                                   |
    // +--------------------------\--\--------------------------------+ end
    //                             \  \
    //                              \  \
    //                               v  v
    // +--------------------------|--|--------------------------------+
    // |                          |  |                                |
    // +--------------------------|--|--------------------------------+ end
    //                       start   start+offset

    final moveStart = index * _cellSize64Bit;
    final moveOffset = count * _cellSize64Bit;
    final bufferEnd = _maxCols * _cellSize64Bit;

    // move data forward
    final cells = _cells.buffer.asInt64List();
    for (var i = bufferEnd - moveOffset - 1; i >= moveStart; i--) {
      cells[i + moveOffset] = cells[i];
    }

    // set inserted cells to 0
    for (var i = moveStart; i < moveStart + moveOffset; i++) {
      cells[i] = 0x00;
    }
  }

  void clear() {
    clearRange(0, _cells.lengthInBytes ~/ _cellSize);
  }

  void erase(Cursor cursor, int start, int end, [bool resetIsWrapped = false]) {
    ensure(end);
    for (var i = start; i < end; i++) {
      cellErase(i, cursor);
    }
    if (resetIsWrapped) {
      isWrapped = false;
    }
  }

  void cellClear(int index) {
    _cells.setUint64(index * _cellSize, 0x00);
    _cells.setUint64(index * _cellSize + 8, 0x00);
  }

  void cellInitialize(
    int index, {
    required int content,
    required int width,
    required Cursor cursor,
  }) {
    final cell = index * _cellSize;
    _cells.setUint32(cell + _cellContent, content);
    _cells.setUint32(cell + _cellFgColor, cursor.fg);
    _cells.setUint32(cell + _cellBgColor, cursor.bg);
    _cells.setUint8(cell + _cellWidth, width);
    _cells.setUint8(cell + _cellFlags, cursor.flags);
  }

  bool cellHasContent(int index) {
    return cellGetContent(index) != 0;
  }

  int cellGetContent(int index) {
    if (index > _maxCols) {
      return 0;
    }
    return _cells.getUint32(index * _cellSize + _cellContent);
  }

  void cellSetContent(int index, int content) {
    _cells.setInt32(index * _cellSize + _cellContent, content);
  }

  int cellGetFgColor(int index) {
    if (index >= _maxCols) {
      return 0;
    }
    return _cells.getUint32(index * _cellSize + _cellFgColor);
  }

  void cellSetFgColor(int index, int color) {
    _cells.setUint32(index * _cellSize + _cellFgColor, color);
  }

  int cellGetBgColor(int index) {
    if (index >= _maxCols) {
      return 0;
    }
    return _cells.getUint32(index * _cellSize + _cellBgColor);
  }

  void cellSetBgColor(int index, int color) {
    _cells.setUint32(index * _cellSize + _cellBgColor, color);
  }

  int cellGetFlags(int index) {
    if (index >= _maxCols) {
      return 0;
    }
    return _cells.getUint8(index * _cellSize + _cellFlags);
  }

  void cellSetFlags(int index, int flags) {
    _cells.setUint8(index * _cellSize + _cellFlags, flags);
  }

  int cellGetWidth(int index) {
    if (index >= _maxCols) {
      return 1;
    }
    return _cells.getUint8(index * _cellSize + _cellWidth);
  }

  void cellSetWidth(int index, int width) {
    _cells.setUint8(index * _cellSize + _cellWidth, width);
  }

  void cellClearFlags(int index) {
    cellSetFlags(index, 0);
  }

  bool cellHasFlag(int index, int flag) {
    if (index >= _maxCols) {
      return false;
    }
    return cellGetFlags(index) & flag != 0;
  }

  void cellSetFlag(int index, int flag) {
    cellSetFlags(index, cellGetFlags(index) | flag);
  }

  void cellErase(int index, Cursor cursor) {
    cellSetContent(index, 0x00);
    cellSetFgColor(index, cursor.fg);
    cellSetBgColor(index, cursor.bg);
    cellSetFlags(index, cursor.flags);
    cellSetWidth(index, 0);
  }

  int getTrimmedLength([int? cols]) {
    if (cols == null) {
      cols = _maxCols;
    }
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

  void copyCellsFrom(
      ByteDataBufferLineData src, int srcCol, int dstCol, int len) {
    ensure(dstCol + len);

    final intsToCopy = len * _cellSize64Bit;
    final srcStart = srcCol * _cellSize64Bit;
    final dstStart = dstCol * _cellSize64Bit;

    final cells = _cells.buffer.asInt64List();
    final srcCells = src._cells.buffer.asInt64List();
    for (var i = 0; i < intsToCopy; i++) {
      cells[dstStart + i] = srcCells[srcStart + i];
    }
  }

  // int cellGetHash(int index) {
  //   final cell = index * _cellSize;
  //   final a = _cells.getInt64(cell);
  //   final b = _cells.getInt64(cell + 8);
  //   return a ^ b;
  // }

  void removeRange(int start, int end) {
    end = min(end, _maxCols);
    this.removeN(start, end - start);
  }

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
