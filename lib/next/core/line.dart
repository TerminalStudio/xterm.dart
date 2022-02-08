import 'dart:math' show max, min;
import 'dart:typed_data';

import 'package:xterm/next/core/cell.dart';
import 'package:xterm/next/core/cursor.dart';

/// Note:
/// xterm的实现和xd类似
/// xterm的resize是一定复制 不太理想 len/cap模型会好些？
/// xterm hasContent的实现不错 用了额外的flag
/// 可以用填充celldata的方式减少调用函数调用次数
///
/// Q:
/// xterm的combined是什么意思？？
/// xterm对widechar的处理
///
///
///

const _cellSize = 4;

const _cellForeground = 0;

const _cellBackground = 1;

const _cellAttributes = 2;

const _cellContent = 3;

class BufferLine {
  BufferLine(this._length)
      : _buffer = Uint32List(_calcCapacity(_length) * _cellSize);

  int _length;

  Uint32List _buffer;

  var isWrapped = false;

  int get length => _length;

  int getForeground(int index) {
    return _buffer[index * _cellSize + _cellForeground];
  }

  int getBackground(int index) {
    return _buffer[index * _cellSize + _cellBackground];
  }

  int getAttributes(int index) {
    return _buffer[index * _cellSize + _cellAttributes];
  }

  int getContent(int index) {
    return _buffer[index * _cellSize + _cellContent];
  }

  int getWidth(int index) {
    return _buffer[index * _cellSize + _cellContent] >> CellContent.widthShift;
  }

  void setForeground(int index, int value) {
    _buffer[index * _cellSize + _cellForeground] = value;
  }

  void setBackground(int index, int value) {
    _buffer[index * _cellSize + _cellBackground] = value;
  }

  void setAttributes(int index, int value) {
    _buffer[index * _cellSize + _cellAttributes] = value;
  }

  void setContent(int index, int value) {
    _buffer[index * _cellSize + _cellContent] = value;
  }

  void setCell(int index, int char, int witdh, CursorStyle style) {
    final offset = index * _cellSize;
    _buffer[offset + _cellForeground] = style.foreground;
    _buffer[offset + _cellBackground] = style.background;
    _buffer[offset + _cellAttributes] = style.attrs;
    _buffer[offset + _cellContent] = char | (witdh << CellContent.widthShift);
  }

  void eraseCell(int index, CursorStyle style) {
    final offset = index * _cellSize;
    _buffer[offset + _cellForeground] = style.foreground;
    _buffer[offset + _cellBackground] = style.background;
    _buffer[offset + _cellAttributes] = style.attrs;
    _buffer[offset + _cellContent] = 0;
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
        _buffer[i] = _buffer[i + moveOffset];
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
        _buffer[i + moveOffset] = _buffer[i];
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

    if (newBufferSize > _buffer.length) {
      final newBuffer = Uint32List(newBufferSize);
      newBuffer.setRange(0, _buffer.length, _buffer);
      _buffer = newBuffer;
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
}
