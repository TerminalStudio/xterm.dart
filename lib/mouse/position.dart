class Position {
  const Position(this.x, this.y);

  final int x;
  final int y;

  bool isBefore(Position another) {
    if (another == null) {
      return false;
    }

    return another.y > y || (another.y == y && another.x > x);
  }

  bool isAfter(Position another) {
    if (another == null) {
      return false;
    }

    return another.y < y || (another.y == y && another.x < x);
  }

  bool isBeforeOrSame(Position another) {
    if (another == null) {
      return false;
    }

    return another.y > y || (another.y == y && another.x >= x);
  }

  bool isAfterOrSame(Position another) {
    if (another == null) {
      return false;
    }

    return another.y < y || (another.y == y && another.x <= x);
  }

  @override
  String toString() {
    return 'MouseOffset($x, $y)';
  }
}
