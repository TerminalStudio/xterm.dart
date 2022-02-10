import 'dart:math' show min;
import 'dart:typed_data';

import 'package:xterm/next/core/cell.dart';
import 'package:xterm/next/core/cursor.dart';

const _cellSize = 4;

const _cellForeground = 0;

const _cellBackground = 1;

const _cellAttributes = 2;

const _cellContent = 3;

class BufferLine {
  BufferLine(this._length)
      : _data = Uint32List(_calcCapacity(_length) * _cellSize);

  int _length;

  Uint32List _data;

  var isWrapped = false;

  int get length => _length;

  int getForeground(int index) {
    return _data[index * _cellSize + _cellForeground];
  }

  int getBackground(int index) {
    return _data[index * _cellSize + _cellBackground];
  }

  int getAttributes(int index) {
    return _data[index * _cellSize + _cellAttributes];
  }

  int getContent(int index) {
    return _data[index * _cellSize + _cellContent];
  }

  int getCodePoint(int index) {
    return _data[index * _cellSize + _cellContent] & CellContent.codepointMask;
  }

  int getWidth(int index) {
    return _data[index * _cellSize + _cellContent] >> CellContent.widthShift;
  }

  void getCellData(int index, CellData cellData) {
    final offset = index * _cellSize;
    cellData.foreground = _data[offset + _cellForeground];
    cellData.background = _data[offset + _cellBackground];
    cellData.flags = _data[offset + _cellAttributes];
    cellData.content = _data[offset + _cellContent];
  }

  void setForeground(int index, int value) {
    _data[index * _cellSize + _cellForeground] = value;
  }

  void setBackground(int index, int value) {
    _data[index * _cellSize + _cellBackground] = value;
  }

  void setAttributes(int index, int value) {
    _data[index * _cellSize + _cellAttributes] = value;
  }

  void setContent(int index, int value) {
    _data[index * _cellSize + _cellContent] = value;
  }

  void setCell(int index, int char, int witdh, CursorStyle style) {
    final offset = index * _cellSize;
    _data[offset + _cellForeground] = style.foreground;
    _data[offset + _cellBackground] = style.background;
    _data[offset + _cellAttributes] = style.attrs;
    _data[offset + _cellContent] = char | (witdh << CellContent.widthShift);
  }

  void setCellData(int index, CellData cellData) {
    final offset = index * _cellSize;
    _data[offset + _cellForeground] = cellData.foreground;
    _data[offset + _cellBackground] = cellData.background;
    _data[offset + _cellAttributes] = cellData.flags;
    _data[offset + _cellContent] = cellData.content;
  }

  void eraseCell(int index, CursorStyle style) {
    final offset = index * _cellSize;
    _data[offset + _cellForeground] = style.foreground;
    _data[offset + _cellBackground] = style.background;
    _data[offset + _cellAttributes] = style.attrs;
    _data[offset + _cellContent] = 0;
  }

  void eraseRange(int start, int end, CursorStyle style) {
    // reset cell one to the left if start is second cell of a wide char
    if (start > 0 && getWidth(start - 1) == 2) {
      eraseCell(start - 1, style);
    }

    // reset cell one to the right if end is second cell of a wide char
    if (end < _length && getWidth(end - 1) == 2) {
      eraseCell(end - 1, style);
    }

    end = min(end, _length);
    for (var i = start; i < end; i++) {
      eraseCell(i, style);
    }
  }

  void removeCells(int start, int count, CursorStyle style) {
    if (start + count < _length) {
      final moveStart = start * _cellSize;
      final moveEnd = (_length - count) * _cellSize;
      final moveOffset = count * _cellSize;
      for (var i = moveStart; i < moveEnd; i++) {
        _data[i] = _data[i + moveOffset];
      }
    }

    for (var i = _length - count; i < _length; i++) {
      eraseCell(i, style);
    }

    if (start > 0 && getWidth(start - 1) == 2) {
      eraseCell(start - 1, style);
    }
  }

  void insertCells(int start, int count, CursorStyle style) {
    if (start > 0 && getWidth(start - 1) == 2) {
      eraseCell(start - 1, style);
    }

    if (start + count < _length) {
      final moveStart = start * _cellSize;
      final moveEnd = (_length - count) * _cellSize;
      final moveOffset = count * _cellSize;
      for (var i = moveEnd - 1; i >= moveStart; i--) {
        _data[i + moveOffset] = _data[i];
      }
    }

    final end = min(start + count, _length);
    for (var i = start; i < end; i++) {
      eraseCell(i, style);
    }

    if (getWidth(_length - 1) == 2) {
      eraseCell(_length - 1, style);
    }
  }

  void resize(int length) {
    assert(length >= 0);

    if (length == _length) {
      return;
    }

    final newBufferSize = _calcCapacity(length) * _cellSize;

    if (newBufferSize > _data.length) {
      final newBuffer = Uint32List(newBufferSize);
      newBuffer.setRange(0, _data.length, _data);
      _data = newBuffer;
    }

    _length = length;
  }

  static int _calcCapacity(int length) {
    assert(length >= 0);

    var capacity = 64;

    if (length < 256) {
      while (capacity < length) {
        capacity *= 2;
      }
    } else {
      capacity = 256;
      while (capacity < length) {
        capacity += 32;
      }
    }

    return capacity;
  }

  @override
  String toString() {
    final builder = StringBuffer();
    for (var i = 0; i < _length; i++) {
      final codePoint = getCodePoint(i);
      if (codePoint == 0) {
        builder.write(' ');
      } else {
        builder.writeCharCode(codePoint);
      }
    }
    return builder.toString();
  }
}
