import 'package:xterm/src/core/buffer/cell_offset.dart';
import 'package:xterm/src/core/buffer/range.dart';
import 'package:xterm/src/core/buffer/segment.dart';

class BufferRangeLine extends BufferRange {
  BufferRangeLine(super.begin, super.end);

  BufferRangeLine.collapsed(CellOffset begin) : super.collapsed(begin);

  @override
  BufferRangeLine get normalized {
    return isNormalized ? this : BufferRangeLine(end, begin);
  }

  @override
  Iterable<BufferSegment> toSegments() sync* {
    var begin = this.begin;
    var end = this.end;

    if (!isNormalized) {
      end = this.begin;
      begin = this.end;
    }

    for (var i = begin.y; i <= end.y; i++) {
      var startX = i == begin.y ? begin.x : null;
      var endX = i == end.y ? end.x : null;
      yield BufferSegment(this, i, startX, endX);
    }
  }

  @override
  bool contains(CellOffset position) {
    return begin.isBeforeOrSame(position) && end.isAfterOrSame(position);
  }

  @override
  BufferRangeLine merge(BufferRange range) {
    final begin = this.begin.isBefore(range.begin) ? this.begin : range.begin;
    final end = this.end.isAfter(range.end) ? this.end : range.end;
    return BufferRangeLine(begin, end);
  }

  @override
  BufferRangeLine extend(CellOffset position) {
    final begin = this.begin.isBefore(position) ? position : this.begin;
    final end = this.end.isAfter(position) ? position : this.end;
    return BufferRangeLine(begin, end);
  }

  @override
  operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    if (other is! BufferRangeLine) {
      return false;
    }

    return begin == other.begin && end == other.end;
  }

  @override
  int get hashCode => begin.hashCode ^ end.hashCode;

  @override
  String toString() => 'Line Range($begin, $end)';
}
