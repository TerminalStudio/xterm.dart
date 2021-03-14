import 'package:xterm/buffer/cell.dart';
import 'package:xterm/buffer/cell_attr.dart';

class BufferLine {
  final _cells = <Cell>[];
  bool _isWrapped = false;

  BufferLine({isWrapped = false}) {
    _isWrapped = isWrapped;
  }

  bool get isWrapped {
    return _isWrapped;
  }

  int get length {
    return _cells.length;
  }

  void add(Cell cell) {
    _cells.add(cell);
  }

  void insert(int index, Cell cell) {
    _cells.insert(index, cell);
  }

  void clear() {
    _cells.clear();
  }

  int getTrimmedLength() {
    int width = 0;
    for (int i = 0; i < _cells.length; i++)
      if (_cells[i].codePoint != null && _cells[i].codePoint != 0) {
        width += _cells[i].width;
      } else {
        return width;
      }
    return width;
  }

  void erase(CellAttr attr, int start, int end) {
    for (var i = start; i < end; i++) {
      if (i >= length) {
        add(Cell(attr: attr));
      } else {
        getCell(i).erase(attr);
      }
    }
  }

  Cell getCell(int index) {
    return _cells[index];
  }

  void removeRange(int start, [int? end]) {
    start = start.clamp(0, _cells.length);
    end ??= _cells.length;
    end = end.clamp(start, _cells.length);
    _cells.removeRange(start, end);
  }

  void copyCellsFrom(BufferLine src, int srcCol, int dstCol, int len) {
    final requiredCells = dstCol + len;
    if(_cells.length < requiredCells) {
      _cells.addAll(List<Cell>.generate(requiredCells - _cells.length, (index) => Cell()));
    }
    for(var i=0; i<len; i++) {
      _cells[dstCol + i] = src._cells[srcCol + i].clone();
    }
  }

  int getWidthAt(int col) {
    if(col >= _cells.length) {
      return 1;
    }
    return _cells[col].width;
  }

  bool hasContentAt(int col) {
    if(col >= _cells.length) {
      return false;
    }
    return _cells[col].codePoint != 0;
  }
}
