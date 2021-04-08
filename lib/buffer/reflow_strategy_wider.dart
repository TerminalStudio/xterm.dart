import 'dart:math';

import 'package:xterm/buffer/buffer.dart';
import 'package:xterm/buffer/buffer_line.dart';
import 'package:xterm/buffer/reflow_strategy.dart';
import 'package:xterm/utli/circular_list.dart';

class ReflowStrategyWider extends ReflowStrategy {
  ReflowStrategyWider(Buffer buffer) : super(buffer);

  @override
  void reflow(int newCols, int newRows, int oldCols, int oldRows) {
    for (var i = 0; i < buffer.lines.length; i++) {
      final line = buffer.lines[i];
      for (var offset = 1; i + offset < buffer.lines.length; offset++) {
        final nextLine = buffer.lines[i + offset];
        if (!nextLine.isWrapped) {
          break;
        }
        final lineLength = line.getTrimmedLength(oldCols);
        final spaceOnLine = newCols - lineLength;
        if (spaceOnLine <= 0) {
          // no more space to unwrap
          break;
        }
        final nextLineLength = nextLine.getTrimmedLength(oldCols);
        final moveCount = min(spaceOnLine, nextLineLength);
        line.copyCellsFrom(nextLine, 0, lineLength, moveCount);
        if (moveCount == nextLineLength) {
          if (i + offset <= buffer.cursorY) {
            //TODO: adapt scrolling
            buffer.moveCursorY(-1);
          }
          // if we unwrapped all cells off the next line, delete it
          buffer.lines.remove(i + offset);
          offset--;
        } else {
          // otherwise just remove the characters we moved up a line
          nextLine.removeN(0, moveCount);
        }
      }
    }
    //buffer doesn't have enough lines
    if (buffer.lines.length < buffer.terminal.viewHeight) {
      // Add an extra row at the bottom of the viewport
      buffer.lines.push(BufferLine());
    }
  }
}
