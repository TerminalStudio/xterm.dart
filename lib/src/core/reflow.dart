import 'package:xterm/src/core/buffer/line.dart';
import 'package:xterm/src/utils/circular_list.dart';

class _LineBuilder {
  _LineBuilder([this._capacity = 80]) {
    _result = BufferLine(_capacity);
  }

  final int _capacity;

  late BufferLine _result;

  int _length = 0;

  int get length => _length;

  bool get isEmpty => _length == 0;

  bool get isNotEmpty => _length != 0;

  void add(BufferLine src, int start, int length) {
    _result.copyFrom(src, start, _length, length);
    _length += length;
  }

  void setBuffer(BufferLine line, int length) {
    _result = line;
    _length = length;
  }

  BufferLine take({required bool wrapped}) {
    final result = _result;
    result.isWrapped = wrapped;
    result.resize(_length);

    _result = BufferLine(_capacity);
    _length = 0;

    return result;
  }
}

class _LineReflow {
  final int oldWidth;

  final int newWidth;

  _LineReflow(this.oldWidth, this.newWidth);

  final _lines = <BufferLine>[];

  late final _builder = _LineBuilder(newWidth);

  void add(BufferLine line) {
    final length = line.getTrimmedLength(oldWidth);

    if (length == 0) {
      _lines.add(line);
      return;
    }

    if (_lines.isNotEmpty || _builder.isNotEmpty) {
      _addRange(line, 0, length);
      return;
    }

    if (newWidth >= oldWidth) {
      _builder.setBuffer(line, length);
    } else {
      _lines.add(line);

      if (line.getWidth(newWidth - 1) == 2) {
        _addRange(line, newWidth - 1, length);
      } else {
        _addRange(line, newWidth, length);
      }
    }

    line.resize(newWidth);

    if (line.getWidth(newWidth - 1) == 2) {
      line.resetCell(newWidth - 1);
    }
  }

  void _addRange(BufferLine line, int start, int end) {
    var cellsLeft = end - start;

    while (cellsLeft > 0) {
      final spaceLeft = newWidth - _builder.length;

      var lineFilled = false;

      var cellsToCopy = cellsLeft;

      if (cellsToCopy >= spaceLeft) {
        cellsToCopy = spaceLeft;
        lineFilled = true;
      }

      // Avoid breaking wide characters
      if (cellsToCopy == spaceLeft &&
          line.getWidth(start + cellsToCopy - 1) == 2) {
        cellsToCopy--;
      }

      _builder.add(line, start, cellsToCopy);

      start += cellsToCopy;
      cellsLeft -= cellsToCopy;

      if (lineFilled) {
        _lines.add(_builder.take(wrapped: _lines.isNotEmpty));
      }
    }
  }

  List<BufferLine> finish() {
    if (_builder.isNotEmpty) {
      _lines.add(_builder.take(wrapped: _lines.isNotEmpty));
    }

    return _lines;
  }
}

List<BufferLine> reflow(
  CircularList<BufferLine> lines,
  int oldWidth,
  int newWidth,
) {
  final result = <BufferLine>[];

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];

    final reflow = _LineReflow(oldWidth, newWidth);

    reflow.add(line);

    for (var offset = i + 1; offset < lines.length; offset++) {
      final nextLine = lines[offset];

      if (!nextLine.isWrapped) {
        break;
      }

      i++;

      reflow.add(nextLine);
    }

    result.addAll(reflow.finish());
  }

  for (var line in result) {
    line.resize(newWidth);
  }

  return result;
}
