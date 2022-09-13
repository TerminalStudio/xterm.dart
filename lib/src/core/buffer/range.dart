import 'package:xterm/src/core/buffer/cell_offset.dart';
import 'package:xterm/src/core/buffer/segment.dart';

abstract class BufferRange {
  final CellOffset begin;

  final CellOffset end;

  const BufferRange(this.begin, this.end);

  BufferRange.collapsed(this.begin) : end = begin;

  bool get isNormalized {
    return begin.isBefore(end) || begin.isEqual(end);
  }

  bool get isCollapsed {
    return begin.isEqual(end);
  }

  BufferRange get normalized;

  Iterable<BufferSegment> toSegments();

  bool contains(CellOffset position);
  BufferRange merge(BufferRange range);
  BufferRange extend(CellOffset position);

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
