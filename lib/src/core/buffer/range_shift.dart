import 'package:xterm/src/core/buffer/cell_offset.dart';
import 'package:xterm/src/core/buffer/range.dart';
import 'package:xterm/src/core/buffer/segment.dart';

/// A range of cells in the buffer that represents a shift selection.
/// This range is used when the user holds the shift key while selecting text.
class BufferRangeShift extends BufferRange {
  BufferRangeShift(super.begin, super.end);

  @override
  bool get isNormalized => true;

  @override
  bool get isCollapsed => begin == end;

  @override
  BufferRange get normalized {
    if (isNormalized) {
      return this;
    }
    return BufferRangeShift(end, begin);
  }

  @override
  List<BufferSegment> toSegments() {
    final isReversed = begin.y > end.y || (begin.y == end.y && begin.x > end.x);
    final segmentStart = isReversed ? end : begin;
    final segmentEnd = isReversed ? begin : end;

    if (segmentStart.y == segmentEnd.y) {
      return [
        BufferSegment(
          this,
          segmentStart.y,
          segmentStart.x,
          segmentEnd.x,
        ),
      ];
    }

    final segments = <BufferSegment>[];
    final startLine = segmentStart.y;
    final endLine = segmentEnd.y;

    segments.add(BufferSegment(
      this,
      startLine,
      segmentStart.x,
      null,
    ));

    for (var line = startLine + 1; line < endLine; line++) {
      segments.add(BufferSegment(
        this,
        line,
        0,
        null,
      ));
    }

    segments.add(BufferSegment(
      this,
      endLine,
      0,
      segmentEnd.x,
    ));

    return segments;
  }

  @override
  bool contains(CellOffset offset) {
    final minY = begin.y < end.y ? begin.y : end.y;
    final maxY = begin.y > end.y ? begin.y : end.y;

    if (offset.y < minY || offset.y > maxY) {
      return false;
    }

    if (begin.y == end.y) {
      final minX = begin.x < end.x ? begin.x : end.x;
      final maxX = begin.x > end.x ? begin.x : end.x;
      return offset.x >= minX && offset.x <= maxX;
    }

    if (offset.y == begin.y) {
      if (begin.y < end.y) {
        return offset.x >= begin.x;
      } else {
        return offset.x <= begin.x;
      }
    }

    if (offset.y == end.y) {
      if (begin.y < end.y) {
        return offset.x <= end.x;
      } else {
        return offset.x >= end.x;
      }
    }

    return true;
  }

  @override
  BufferRange merge(BufferRange other) {
    if (other is! BufferRangeShift) {
      final normalized = this.normalized;
      final otherNormalized = other.normalized;

      final newBegin = normalized.begin.isBefore(otherNormalized.begin)
          ? normalized.begin
          : otherNormalized.begin;

      final newEnd = normalized.end.isAfter(otherNormalized.end)
          ? normalized.end
          : otherNormalized.end;

      return BufferRangeShift(newBegin, newEnd);
    }

    final normalized = this.normalized;
    final otherNormalized = other.normalized;

    final newBegin = normalized.begin.isBefore(otherNormalized.begin)
        ? normalized.begin
        : otherNormalized.begin;

    final newEnd = normalized.end.isAfter(otherNormalized.end)
        ? normalized.end
        : otherNormalized.end;

    return BufferRangeShift(newBegin, newEnd);
  }

  @override
  BufferRange extend(CellOffset newEnd) {
    if (begin.y < newEnd.y || (begin.y == newEnd.y && begin.x < newEnd.x)) {
      return BufferRangeShift(begin, newEnd);
    } else {
      return BufferRangeShift(newEnd, begin);
    }
  }
}
