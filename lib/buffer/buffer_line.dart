import 'package:xterm/buffer/cell.dart';
import 'package:xterm/buffer/cell_attr.dart';

class BufferLine {
  final _cells = <Cell>[];
  bool _isWrapped = false;

  BufferLine({int numOfCells = 0, attr}) {
    _cells.addAll(List<Cell>.generate(numOfCells, (index) => Cell(codePoint: 0, attr: attr)));
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

  int getTrimmedLength () {
    for (int i = _cells.length - 1; i >= 0; --i)
      if (_cells[i].codePoint != 0) {
        int width = 0;
        for (int j = 0; j <= i; j++)
          width += _cells[i].width;
        return width;
      }
    return 0;
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

  void copyCellsFrom (BufferLine src, int srcCol, int dstCol, int len)
  {
    List.copyRange(_cells, dstCol, src._cells, srcCol, srcCol + len);
  }

  int getWidthAt(int col) {
    return _cells[col].width;
  }

  bool hasContentAt(int col) {
    return _cells[col].codePoint != 0;
  }
}
