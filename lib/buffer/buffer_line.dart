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
  BufferLine() {
    const initLength = 64;
    _cells = ByteData(initLength * _cellSize);
  }

  late ByteData _cells;

  bool get isWrapped => _isWrapped;
  bool _isWrapped = false;

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
  }

  void insert(int index) {
    insertN(index, 1);
  }

  void insertN(int index, int count) {
    // TODO: implement insertN()
  }

  void clear() {
    _cells.buffer.asInt64List().clear();
  }

  void erase(Cursor cursor, int start, int end) {
    ensure(end);
    for (var i = start; i < end; i++) {
      cellErase(i, cursor);
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

  int cellGetContent(int index) {
    return _cells.getInt32(index * _cellSize + _cellContent);
  }

  void cellSetContent(int index, int content) {
    return _cells.setInt32(index * _cellSize + _cellContent, content);
  }

  int cellGetFgColor(int index) {
    return _cells.getInt32(index * _cellSize + _cellFgColor);
  }

  void cellSetFgColor(int index, int color) {
    _cells.setInt32(index * _cellSize + _cellFgColor, color);
  }

  int cellGetBgColor(int index) {
    return _cells.getInt32(index * _cellSize + _cellBgColor);
  }

  void cellSetBgColor(int index, int color) {
    _cells.setInt32(index * _cellSize + _cellBgColor, color);
  }

  int cellGetFlags(int index) {
    return _cells.getInt8(index * _cellSize + _cellFlags);
  }

  void cellSetFlags(int index, int flags) {
    _cells.setInt8(index * _cellSize + _cellFlags, flags);
  }

  int cellGetWidth(int index) {
    return _cells.getInt8(index * _cellSize + _cellWidth);
  }

  void cellSetWidth(int index, int width) {
    _cells.setInt8(index * _cellSize + _cellWidth, width);
  }

  void cellClearFlags(int index) {
    cellSetFlags(index, 0);
  }

  bool cellHasFlag(int index, int flag) {
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

  // int cellGetHash(int index) {
  //   final cell = index * _cellSize;
  //   final a = _cells.getInt64(cell);
  //   final b = _cells.getInt64(cell + 8);
  //   return a ^ b;
  // }

  void removeRange(int start, int end) {
    // start = start.clamp(0, _cells.length);
    // end ??= _cells.length;
    // end = end.clamp(start, _cells.length);
    // _cells.removeRange(start, end);
    for (var index = start; index < end; index++) {
      cellSetContent(index, 0x00);
    }
  }
}
