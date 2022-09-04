import 'package:xterm/core/buffer/position.dart';
import 'package:xterm/core/buffer/range.dart';

class BufferSegment {
  /// The range that this segment belongs to.
  final BufferRange range;

  /// The line that this segment resides on.
  final int line;

  /// The start position of this segment.
  final int? start;

  /// The end position of this segment. [null] if this segment is not closed.
  final int? end;

  const BufferSegment(this.range, this.line, this.start, this.end);

  bool isWithin(BufferPosition position) {
    if (position.y != line) {
      return false;
    }

    if (start != null && position.x < start!) {
      return false;
    }

    if (end != null && position.x > end!) {
      return false;
    }

    return true;
  }

  @override
  String toString() => 'Segment($line, $start, $end)';

  @override
  int get hashCode =>
      range.hashCode ^ line.hashCode ^ start.hashCode ^ end.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BufferSegment &&
          runtimeType == other.runtimeType &&
          range == other.range &&
          line == other.line &&
          start == other.start &&
          end == other.end;
}
