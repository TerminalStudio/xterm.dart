import 'package:xterm/src/core/buffer/cell_offset.dart';
import 'package:xterm/src/core/buffer/segment.dart';

class BufferRange {
  final CellOffset begin;

  final CellOffset end;

  BufferRange(this.begin, this.end);

  BufferRange.collapsed(this.begin) : end = begin;

  bool get isNormalized {
    return begin.isBefore(end) || begin.isEqual(end);
  }

  bool get isCollapsed {
    return begin.isEqual(end);
  }

  BufferRange get normalized {
    if (isNormalized) {
      return this;
    } else {
      return BufferRange(end, begin);
    }
  }

  Iterable<BufferSegment> toSegments() sync* {
    var start = this.begin;
    var end = this.end;

    if (!isNormalized) {
      end = this.begin;
      start = this.end;
    }

    for (var i = start.y; i <= end.y; i++) {
      var startX = i == start.y ? start.x : null;
      var endX = i == end.y ? end.x : null;
      yield BufferSegment(this, i, startX, endX);
    }
  }

  bool contains(CellOffset position) {
    return begin.isBeforeOrSame(position) && end.isAfterOrSame(position);
  }

  BufferRange merge(BufferRange range) {
    final begin = this.begin.isBefore(range.begin) ? this.begin : range.begin;
    final end = this.end.isAfter(range.end) ? this.end : range.end;
    return BufferRange(begin, end);
  }

  BufferRange extend(CellOffset position) {
    final begin = this.begin.isBefore(position) ? position : this.begin;
    final end = this.end.isAfter(position) ? position : this.end;
    return BufferRange(begin, end);
  }

  @override
  operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    if (other is! BufferRange) {
      return false;
    }

    return begin == other.begin && end == other.end;
  }

  @override
  int get hashCode => begin.hashCode ^ end.hashCode;

  @override
  String toString() => 'Range($begin, $end)';
}
