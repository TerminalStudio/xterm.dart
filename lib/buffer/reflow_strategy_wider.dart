import 'dart:math';

import 'package:xterm/buffer/buffer.dart';
import 'package:xterm/buffer/buffer_line.dart';
import 'package:xterm/buffer/reflow_strategy.dart';

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
        final lineLength = line.getTrimmedLength();

        var copyDestIndex = lineLength;
        if (copyDestIndex >= 1 &&
            line.cellGetWidth(copyDestIndex - 1) == 2 &&
            line.cellGetContent(copyDestIndex) == 0) {
          //we would override a wide char placeholder => move index one to the right
          copyDestIndex += 1;
        }

        final spaceOnLine = newCols - copyDestIndex;
        if (spaceOnLine <= 0) {
          // no more space to unwrap
          break;
        }
        final nextLineLength = nextLine.getTrimmedLength();
        var moveCount = min(spaceOnLine, nextLineLength);
        if (moveCount <= 0) {
          break;
        }

        // when we are about to copy a double width character
        // to the end of the line then we can include the 0 width placeholder
        // after it
        if (nextLine.cellGetWidth(moveCount - 1) == 2 &&
            nextLine.cellGetContent(moveCount) == 0) {
          moveCount += 1;
        }
        line.copyCellsFrom(nextLine, 0, copyDestIndex, moveCount);
        if (moveCount >= nextLineLength) {
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
    while (buffer.lines.length < buffer.terminal.viewHeight) {
      buffer.lines.push(BufferLine());
    }
  }
}
