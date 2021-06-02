import 'dart:math';

import 'package:xterm/buffer/line/line_bytedata.dart';
import 'package:xterm/buffer/line/line_list.dart';
import 'package:xterm/terminal/cursor.dart';
import 'package:xterm/util/constants.dart';

abstract class BufferLine {
  factory BufferLine({int length = 64, bool isWrapped = false}) {
    if (kIsWeb) {
      return ListBufferLine(length, isWrapped);
    }

    return ByteDataBufferLine(length, isWrapped);
  }

  bool get isWrapped;

  set isWrapped(bool value);

  void ensure(int length);

  void insert(int index) {
    insertN(index, 1);
  }

  void removeN(int index, int count);

  void insertN(int index, int count);

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

  void copyCellsFrom(covariant BufferLine src, int srcCol, int dstCol, int len);

  // int cellGetHash(int index);

  void removeRange(int start, int end);

  void clearRange(int start, int end);

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
