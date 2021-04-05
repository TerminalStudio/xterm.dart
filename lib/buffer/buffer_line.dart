import 'dart:math';
import 'dart:typed_data';

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

const _cellContent = 0;
const _cellFgColor = 4;
const _cellBgColor = 8;

// const _cellAttributes = 12;
const _cellWidth = 12;
const _cellFlags = 13;

class BufferLine {
  BufferLine({this.isWrapped = false}) {
    _cells = ByteData(_maxCols * _cellSize);
  }

  late ByteData _cells;

  bool isWrapped;

  int _maxCols = 64;

  void ensure(int length) {
    final expectedLengthInBytes = length * _cellSize;

    if (expectedLengthInBytes < _cells.lengthInBytes) {
      return;
    }

    var newLengthInBytes = _cells.lengthInBytes;
    while (newLengthInBytes < expectedLengthInBytes) {
      newLengthInBytes *= 2;
    }

    final newCells = ByteData(newLengthInBytes);
    newCells.buffer.asInt64List().setAll(0, _cells.buffer.asInt64List());
    _cells = newCells;
    _maxCols = (newLengthInBytes / _cellSize).floor();
  }

  void insert(int index) {
    insertN(index, 1);
  }

  void insertN(int index, int count) {
    //                       start
    // +--------------------------|-----------------------------------+
    // |                          |                                   |
    // +--------------------------\--\--------------------------------+
    //                             \  \
    //                              \  \
    //                               v  v
    // +--------------------------|--|--------------------------------+
    // |                          |  |                                |
    // +--------------------------|--|--------------------------------+
    //                       start   start+offset

    final start = (index * _cellSize).clamp(0, _cells.lengthInBytes);
    final offset = (count * _cellSize).clamp(0, _cells.lengthInBytes - start);

    // move data forward
    final cells = _cells.buffer.asInt8List();
    for (var i = _cells.lengthInBytes - offset - 1; i >= start; i++) {
      cells[i + offset] = cells[i];
    }

    // set inserted cells to 0
    for (var i = start; i < start + offset; i++) {
      cells[i] = 0x00;
    }
  }

  void clear() {
    removeRange(0, (_cells.lengthInBytes / _cellSize).floor());
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

  void cellInitialize(
    int index, {
    required int content,
    required int width,
    required Cursor cursor,
  }) {
    final cell = index * _cellSize;
    _cells.setInt32(cell + _cellContent, content);
    _cells.setInt32(cell + _cellFgColor, cursor.fg);
    _cells.setInt32(cell + _cellBgColor, cursor.bg);
    _cells.setInt8(cell + _cellWidth, width);
    _cells.setInt8(cell + _cellFlags, cursor.flags);
  }

  bool cellHasContent(int index) {
    return cellGetContent(index) != 0;
  }

  int cellGetContent(int index) {
    if (index >= _maxCols) {
      return 0;
    }
    return _cells.getInt32(index * _cellSize + _cellContent);
  }

  void cellSetContent(int index, int content) {
    return _cells.setInt32(index * _cellSize + _cellContent, content);
  }

  int cellGetFgColor(int index) {
    if (index >= _maxCols) {
      return 0;
    }
    return _cells.getInt32(index * _cellSize + _cellFgColor);
  }

  void cellSetFgColor(int index, int color) {
    _cells.setInt32(index * _cellSize + _cellFgColor, color);
  }

  int cellGetBgColor(int index) {
    if (index >= _maxCols) {
      return 0;
    }
    return _cells.getInt32(index * _cellSize + _cellBgColor);
  }

  void cellSetBgColor(int index, int color) {
    _cells.setInt32(index * _cellSize + _cellBgColor, color);
  }

  int cellGetFlags(int index) {
    if (index >= _maxCols) {
      return 0;
    }
    return _cells.getInt8(index * _cellSize + _cellFlags);
  }

  void cellSetFlags(int index, int flags) {
    _cells.setInt8(index * _cellSize + _cellFlags, flags);
  }

  int cellGetWidth(int index) {
    if (index >= _maxCols) {
      return 1;
    }
    return _cells.getInt8(index * _cellSize + _cellWidth);
  }

  void cellSetWidth(int index, int width) {
    _cells.setInt8(index * _cellSize + _cellWidth, width);
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
  }

  int getTrimmedLength(int cols) {
    for (int i = cols; i >= 0; i--) {
      if (cellGetContent(i) != 0) {
        int length = 0;
        for (int j = 0; j <= i; j++) {
          length += cellGetWidth(j);
        }
        return length;
      }
    }
    return 0;
  }

  copyCellsFrom(BufferLine src, int srcCol, int dstCol, int len) {
    final dstOffset = dstCol * _cellSize;
    final srcOffset = srcCol * _cellSize;
    final byteLen = len * _cellSize;

    final srcCopyView = src._cells.buffer.asUint8List(srcOffset, byteLen);

    _cells.buffer.asUint8List().setAll(dstOffset, srcCopyView);
  }

  // int cellGetHash(int index) {
  //   final cell = index * _cellSize;
  //   final a = _cells.getInt64(cell);
  //   final b = _cells.getInt64(cell + 8);
  //   return a ^ b;
  // }

  void removeRange(int start, int end) {
    end = min(end, _maxCols);
    // start = start.clamp(0, _cells.length);
    // end ??= _cells.length;
    // end = end.clamp(start, _cells.length);
    // _cells.removeRange(start, end);
    for (var index = start; index < end; index++) {
      cellSetContent(index, 0x00);
    }
  }
}
