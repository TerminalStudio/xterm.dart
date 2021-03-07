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

  @override
  String toString() {
    return 'MouseOffset($x, $y)';
  }
}
