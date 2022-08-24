class Position {
  const Position(this.x, this.y);

  final int x;
  final int y;

  bool isBefore(Position another) {
    return another.y > y || (another.y == y && another.x > x);
  }

  bool isAfter(Position another) {
    return another.y < y || (another.y == y && another.x < x);
  }

  bool isBeforeOrSame(Position another) {
    return another.y > y || (another.y == y && another.x >= x);
  }

  bool isAfterOrSame(Position another) {
    return another.y < y || (another.y == y && another.x <= x);
  }

  bool isWithinRectangle(Position a, Position b) {
    return ((a.x <= x && x <= b.x) || (b.x <= x && x <= a.x)) &&
        ((a.y <= y && y <= b.y) || (b.y <= y && y <= a.y));
  }

  @override
  String toString() {
    return 'MouseOffset($x, $y)';
  }
}
