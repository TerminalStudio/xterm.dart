class CellSize {
  CellSize({
    this.charWidth,
    this.charHeight,
    this.letterSpacing,
    this.lineSpacing,
    this.cellWidth,
    this.cellHeight,
  });

  final double charWidth;
  final double charHeight;
  final double cellWidth;
  final double cellHeight;
  final double letterSpacing;
  final double lineSpacing;

  @override
  String toString() {
    final data = {
      'charWidth': charWidth,
      'charHeight': charHeight,
      'letterSpacing': letterSpacing,
      'lineSpacing': lineSpacing,
      'cellWidth': cellWidth,
      'cellHeight': cellHeight,
    };
    return 'CellSize$data';
  }
}
