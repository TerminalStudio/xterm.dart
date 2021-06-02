import 'dart:math';

import 'package:xterm/buffer/buffer.dart';
import 'package:xterm/buffer/line/line.dart';
import 'package:xterm/buffer/reflow_strategy.dart';

class ReflowStrategyWider extends ReflowStrategy {
  ReflowStrategyWider(Buffer buffer) : super(buffer);

  @override
  void reflow(int newCols, int newRows, int oldCols, int oldRows) {
    final linesAfterReflow = <BufferLine>[];

    for (var i = 0; i < buffer.lines.length; i++) {
      final line = buffer.lines[i];
      line.ensure(newCols);
      linesAfterReflow.add(line);

      var linesToSkip = 0;
      for (var offset = 1; i + offset < buffer.lines.length; offset++) {
        final nextLine = buffer.lines[i + offset];
        if (!nextLine.isWrapped) {
          break;
        }
        // when we are reflowing wider we can be sure that this line and the next all have equal to or less than
        // 'newCols' length => we can pass newCols as the upper limit
        final lineLength = line.getTrimmedLength(newCols);

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
        // when we are reflowing wider we can be sure that this line and the next all have equal to or less than
        // 'newCols' length => we can pass newCols as the upper limit
        final nextLineLength = nextLine.getTrimmedLength(newCols);
        var moveCount = min(spaceOnLine, nextLineLength);
        if (moveCount <= 0) {
          break;
        }

        // when we are about to copy a double width character
        // to the end of the line then we just ignore it as the target width
        // would be too much
        if (nextLine.cellGetWidth(moveCount - 1) == 2) {
          moveCount -= 1;
        }
        line.copyCellsFrom(nextLine, 0, copyDestIndex, moveCount);
        if (moveCount >= nextLineLength) {
          // if we unwrapped all cells off the next line, skip it
          linesToSkip++;
        } else {
          // otherwise just remove the characters we moved up a line
          nextLine.removeN(0, moveCount);
        }
      }

      // skip empty lines.
      i += linesToSkip;
    }
    //buffer doesn't have enough lines
    while (linesAfterReflow.length < buffer.terminal.viewHeight) {
      linesAfterReflow.add(BufferLine(length: buffer.terminal.viewWidth));
    }

    buffer.lines.replaceWith(linesAfterReflow);
  }
}
