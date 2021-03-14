import 'package:xterm/buffer/cell_attr.dart';

class Cell {
  Cell({this.codePoint, this.width = 1, this.attr});

  int? codePoint;
  int width;
  CellAttr? attr;

  void setCodePoint(int codePoint) {
    this.codePoint = codePoint;
  }

  void setAttr(CellAttr attr) {
    this.attr = attr;
  }

  void setWidth(int width) {
    this.width = width;
  }

  void reset(CellAttr attr) {
    codePoint = null;
    this.attr = attr;
  }

  void erase(CellAttr attr) {
    codePoint = null;
    this.attr = attr;
  }

  @override
  String toString() {
    return 'Cell($codePoint)';
  }

  Cell clone() => Cell(codePoint: this.codePoint, width: this.width, attr: this.attr);
}
