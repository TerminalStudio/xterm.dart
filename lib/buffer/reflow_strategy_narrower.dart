import 'dart:math';

import 'package:flutter/material.dart';
import 'package:xterm/buffer/buffer.dart';
import 'package:xterm/buffer/buffer_line.dart';
import 'package:xterm/buffer/reflow_strategy.dart';
import 'package:xterm/utli/circular_list.dart';

class ReflowStrategyNarrower extends ReflowStrategy {
  ReflowStrategyNarrower(Buffer buffer) : super(buffer);

  @override
  void reflow(int newCols, int newRows, int oldCols, int oldRows) {
    for (var i = 0; i < buffer.lines.length; i++) {
      final line = buffer.lines[i];
      final lineLength = line.getTrimmedLength(oldCols);
      if (lineLength > newCols) {
        var moveIndexStart = newCols;
        var cellsToCopy = oldCols - newCols;

        // when we have a double width character and are about to move the "0" placeholder,
        // then we have to move the double width character as well
        if (line.cellGetContent(moveIndexStart) == 0 &&
            line.cellGetWidth(moveIndexStart - 1) == 2) {
          moveIndexStart -= 1;
          cellsToCopy += 1;
        }

        // we need to move cut cells to the next line
        // if the next line is wrapped anyway, we can push them onto the beginning of that line
        // otherwise, we need add a new wrapped line
        if (i + 1 < buffer.lines.length) {
          final nextLine = buffer.lines[i + 1];
          if (nextLine.isWrapped) {
            nextLine.ensure(oldCols + cellsToCopy); //to be safe
            nextLine.insertN(0, cellsToCopy);
            nextLine.copyCellsFrom(line, moveIndexStart, 0, cellsToCopy);
            // clean the cells that we moved
            line.erase(buffer.terminal.cursor, moveIndexStart, oldCols);
            continue;
          }
        }

        final newLine = BufferLine(isWrapped: true);
        newLine.ensure(max(newCols, cellsToCopy));
        newLine.copyCellsFrom(line, moveIndexStart, 0, cellsToCopy);
        // clean the cells that we moved
        line.erase(buffer.terminal.cursor, moveIndexStart, oldCols);

        buffer.lines.insert(i + 1, newLine);

        //TODO: scrolling is a bit weird afterwards
      }
    }
  }
}
