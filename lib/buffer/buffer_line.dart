import 'package:xterm/buffer/cell.dart';
import 'package:xterm/buffer/cell_attr.dart';

class BufferLine {
  final _cells = <Cell>[];
  bool _isWrapped = false;

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
}
