import 'dart:math';

import 'package:xterm/buffer/buffer.dart';
import 'package:xterm/buffer/buffer_line.dart';
import 'package:xterm/buffer/reflow_strategy.dart';

class ReflowStrategyNarrower extends ReflowStrategy {
  ReflowStrategyNarrower(Buffer buffer) : super(buffer);

  @override
  void reflow(int newCols, int newRows, int oldCols, int oldRows) {
    //print('Reflow narrower $oldCols -> $newCols');
    for (var i = 0; i < buffer.lines.length; i++) {
      final line = buffer.lines[i];
      final lineLength = line.getTrimmedLength();
      if (lineLength > newCols) {
        var moveIndexStart = newCols;
        var cellsToCopy = lineLength - newCols;

        // when we have a double width character and are about to move the "0" placeholder,
        // then we have to move the double width character as well
        if (line.cellGetContent(moveIndexStart) == 0 &&
            line.cellGetWidth(moveIndexStart - 1) == 2) {
          moveIndexStart -= 1;
          cellsToCopy += 1;
        }

        var addZero = false;
        //when the last cell to copy is a double width cell, then add a "0"
        if (line.cellGetWidth(moveIndexStart + cellsToCopy - 1) == 2) {
          addZero = true;
        }

        var alreadyInserted = 0;

        //when we have aggregated a whole new line then insert it now
        while (cellsToCopy > newCols) {
          final newLine = BufferLine(isWrapped: true);
          newLine.ensure(newCols);
          newLine.copyCellsFrom(line, moveIndexStart, 0, newCols);
          // line.clearRange(moveIndexStart, moveIndexStart + newCols);
          line.removeN(moveIndexStart, newCols);

          buffer.lines.insert(i + 1, newLine);

          cellsToCopy -= newCols;
          alreadyInserted++;
        }

        // we need to move cut cells to the next line
        // if the next line is wrapped anyway, we can push them onto the beginning of that line
        // otherwise, we need add a new wrapped line
        final nextLineIndex = i + alreadyInserted + 1;
        if (nextLineIndex < buffer.lines.length) {
          final nextLine = buffer.lines[nextLineIndex];
          if (nextLine.isWrapped) {
            final nextLineLength = nextLine.getTrimmedLength();
            nextLine.ensure(nextLineLength + cellsToCopy + (addZero ? 1 : 0));
            nextLine.insertN(0, cellsToCopy + (addZero ? 1 : 0));
            nextLine.copyCellsFrom(line, moveIndexStart, 0, cellsToCopy);
            // clean the cells that we moved
            line.removeN(moveIndexStart, cellsToCopy);
            // line.erase(buffer.terminal.cursor, moveIndexStart,
            //     moveIndexStart + cellsToCopy);
            //print('M: ${i < 10 ? '0' : ''}$i: ${line.toDebugString(oldCols)}');
            //print(
            //    'N: ${i + 1 < 10 ? '0' : ''}${i + 1}: ${nextLine.toDebugString(oldCols)}');
            continue;
          }
        }

        final newLine = BufferLine(isWrapped: true);
        newLine.ensure(newCols);
        newLine.copyCellsFrom(line, moveIndexStart, 0, cellsToCopy);
        // clean the cells that we moved
        line.removeN(moveIndexStart, cellsToCopy);

        buffer.lines.insert(nextLineIndex, newLine);

        //TODO: scrolling is a bit weird afterwards

        //print('S: ${i < 10 ? '0' : ''}$i: ${line.toDebugString(oldCols)}');
      } else {
        //print('N: ${i < 10 ? '0' : ''}$i: ${line.toDebugString(oldCols)}');
      }
    }
  }
}
