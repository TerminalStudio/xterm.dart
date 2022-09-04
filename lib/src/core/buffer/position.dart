import 'package:xterm/src/core/buffer/range.dart';

class BufferPosition {
  final int x;

  final int y;

  const BufferPosition(this.x, this.y);

  bool isEqual(BufferPosition other) {
    return other.x == x && other.y == y;
  }

  bool isBefore(BufferPosition other) {
    return y < other.y || (y == other.y && x < other.x);
  }

  bool isAfter(BufferPosition other) {
    return y > other.y || (y == other.y && x > other.x);
  }

  bool isBeforeOrSame(BufferPosition other) {
    return y < other.y || (y == other.y && x <= other.x);
  }

  bool isAfterOrSame(BufferPosition other) {
    return y > other.y || (y == other.y && x >= other.x);
  }

  bool isAtSameRow(BufferPosition other) {
    return y == other.y;
  }

  bool isAtSameColumn(BufferPosition other) {
    return x == other.x;
  }

  bool isWithin(BufferRange range) {
    return range.begin.isBeforeOrSame(this) && range.end.isAfterOrSame(this);
  }

  @override
  String toString() => 'Position($x, $y)';

  @override
  int get hashCode => x.hashCode ^ y.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BufferPosition &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y;
}
