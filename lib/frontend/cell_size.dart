class CellSize {
  CellSize({
    required this.charWidth,
    required this.charHeight,
    required this.letterSpacing,
    required this.lineSpacing,
    required this.cellWidth,
    required this.cellHeight,
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
