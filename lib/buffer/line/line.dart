import 'dart:math';

import 'package:meta/meta.dart';
import 'package:xterm/buffer/line/line_bytedata_data.dart';
import 'package:xterm/buffer/line/line_list_data.dart';
import 'package:xterm/terminal/cursor.dart';
import 'package:xterm/util/constants.dart';

@sealed
class BufferLine {
  BufferLine({int length = 64, bool isWrapped = false}) {
    _data = BufferLineData(length: length, isWrapped: isWrapped);
  }

  BufferLine.withDataFrom(BufferLine other) {
    _data = other.data;
  }

  late BufferLineData _data;
  final _nonDirtyTags = Set<String>();

  void markTagAsNonDirty(String tag) {
    _nonDirtyTags.add(tag);
  }

  bool isTagDirty(String tag) {
    return !_nonDirtyTags.contains(tag);
  }

  BufferLineData get data => _data;

  bool get isWrapped => _data.isWrapped;

  set isWrapped(bool value) => _data.isWrapped = value;

  void ensure(int length) => _data.ensure(length);

  void insert(int index) {
    _invalidateCaches();
    _data.insert(index);
  }

  void insertN(int index, int count) {
    _invalidateCaches();
    _data.insertN(index, count);
  }

  void removeN(int index, int count) {
    _invalidateCaches();
    _data.removeN(index, count);
  }

  void clear() {
    _invalidateCaches();
    _data.clear();
  }

  void erase(Cursor cursor, int start, int end, [bool resetIsWrapped = false]) {
    _invalidateCaches();
    _data.erase(cursor, start, end);
  }

  void cellClear(int index) {
    _invalidateCaches();
    _data.cellClear(index);
  }

  void cellInitialize(
    int index, {
    required int content,
    required int width,
    required Cursor cursor,
  }) {
    _invalidateCaches();
    _data.cellInitialize(
      index,
      content: content,
      width: width,
      cursor: cursor,
    );
  }

  bool cellHasContent(int index) => _data.cellHasContent(index);

  int cellGetContent(int index) => _data.cellGetContent(index);

  void cellSetContent(int index, int content) {
    _invalidateCaches();
    _data.cellSetContent(index, content);
  }

  int cellGetFgColor(int index) => _data.cellGetFgColor(index);

  void cellSetFgColor(int index, int color) =>
      _data.cellSetFgColor(index, color);

  int cellGetBgColor(int index) => _data.cellGetBgColor(index);

  void cellSetBgColor(int index, int color) =>
      _data.cellSetBgColor(index, color);

  int cellGetFlags(int index) => _data.cellGetFlags(index);

  void cellSetFlags(int index, int flags) => _data.cellSetFlags(index, flags);

  int cellGetWidth(int index) => _data.cellGetWidth(index);

  void cellSetWidth(int index, int width) {
    _invalidateCaches();
    _data.cellSetWidth(index, width);
  }

  void cellClearFlags(int index) => _data.cellClearFlags(index);

  bool cellHasFlag(int index, int flag) => _data.cellHasFlag(index, flag);

  void cellSetFlag(int index, int flag) => _data.cellSetFlag(index, flag);

  void cellErase(int index, Cursor cursor) {
    _invalidateCaches();
    _data.cellErase(index, cursor);
  }

  int getTrimmedLength([int? cols]) => _data.getTrimmedLength(cols);

  void copyCellsFrom(
      covariant BufferLine src, int srcCol, int dstCol, int len) {
    _invalidateCaches();
    _data.copyCellsFrom(src.data, srcCol, dstCol, len);
  }

  void removeRange(int start, int end) {
    _invalidateCaches();
    _data.removeRange(start, end);
  }

  void clearRange(int start, int end) {
    _invalidateCaches();
    _data.clearRange(start, end);
  }

  String toDebugString(int cols) => _data.toDebugString(cols);

  void _invalidateCaches() {
    _searchStringCache = null;
    _nonDirtyTags.clear();
  }

  String? _searchStringCache;
  bool get hasCachedSearchString => _searchStringCache != null;

  String toSearchString(int cols) {
    if (_searchStringCache != null) {
      return _searchStringCache!;
    }
    final searchString = StringBuffer();
    final length = getTrimmedLength();
    for (int i = 0; i < max(cols, length); i++) {
      var code = cellGetContent(i);
      if (code != 0) {
        final cellString = String.fromCharCode(code);
        searchString.write(cellString);
        final widthDiff = cellGetWidth(i) - cellString.length;
        if (widthDiff > 0) {
          searchString.write(''.padRight(widthDiff));
        }
      }
    }
    _searchStringCache = searchString.toString();
    return _searchStringCache!;
  }
}

abstract class BufferLineData {
  factory BufferLineData({int length = 64, bool isWrapped = false}) {
    if (kIsWeb) {
      return ListBufferLineData(length, isWrapped);
    }

    return ByteDataBufferLineData(length, isWrapped);
  }

  bool get isWrapped;

  set isWrapped(bool value);

  void ensure(int length);

  void insert(int index);

  void insertN(int index, int count);

  void removeN(int index, int count);

  void clear();

  void erase(Cursor cursor, int start, int end, [bool resetIsWrapped = false]);

  void cellClear(int index);

  void cellInitialize(
    int index, {
    required int content,
    required int width,
    required Cursor cursor,
  });

  bool cellHasContent(int index);

  int cellGetContent(int index);

  void cellSetContent(int index, int content);

  int cellGetFgColor(int index);

  void cellSetFgColor(int index, int color);

  int cellGetBgColor(int index);

  void cellSetBgColor(int index, int color);

  int cellGetFlags(int index);

  void cellSetFlags(int index, int flags);

  int cellGetWidth(int index);

  void cellSetWidth(int index, int width);

  void cellClearFlags(int index);

  bool cellHasFlag(int index, int flag);

  void cellSetFlag(int index, int flag);

  void cellErase(int index, Cursor cursor);

  int getTrimmedLength([int? cols]);

  void copyCellsFrom(
      covariant BufferLineData src, int srcCol, int dstCol, int len);

  // int cellGetHash(int index);

  void removeRange(int start, int end);

  void clearRange(int start, int end);

  @nonVirtual
  String toDebugString(int cols) {
    final result = StringBuffer();
    final length = getTrimmedLength();
    for (int i = 0; i < max(cols, length); i++) {
      var code = cellGetContent(i);
      if (code == 0) {
        if (cellGetWidth(i) == 0) {
          code = '_'.runes.first;
        } else {
          code = cellGetWidth(i).toString().runes.first;
        }
      }
      result.writeCharCode(code);
    }
    return result.toString();
  }
}
