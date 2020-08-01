class CharSize {
  CharSize({
    this.width,
    this.height,
    this.letterSpacing,
    this.lineSpacing,
    this.effectWidth,
    this.effectHeight,
  });

  final double width;
  final double height;
  final double letterSpacing;
  final double lineSpacing;
  final double effectWidth;
  final double effectHeight;

  @override
  String toString() {
    final data = {
      'width': width,
      'height': height,
      'letterSpacing': letterSpacing,
      'lineSpacing': lineSpacing,
      'effectWidth': effectWidth,
      'effectHeight': effectHeight,
    };
    return 'CharSize$data';
  }
}
