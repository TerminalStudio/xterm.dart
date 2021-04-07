import 'dart:math';

import 'package:xterm/buffer/buffer.dart';
import 'package:xterm/buffer/buffer_line.dart';
import 'package:xterm/buffer/reflow_strategy.dart';
import 'package:xterm/utli/circular_list.dart';

class ReflowStrategyWider extends ReflowStrategy {
  ReflowStrategyWider(Buffer buffer) : super(buffer);

  @override
  void reflow(int newCols, int newRows, int oldCols, int oldRows) {
    final toRemove = _getLinesToRemove(buffer.lines, oldCols, newCols);
    if (toRemove.length > 0) {
      final newLayoutResult = _createNewLayout(buffer.lines, toRemove);
      _applyNewLayout(buffer.lines, newLayoutResult.layout);
      _adjustViewport(newCols, newRows, newLayoutResult.removedCount);
    }
  }

  /// <summary>
  /// Evaluates and returns indexes to be removed after a reflow larger occurs. Lines will be removed
  /// when a wrapped line unwraps.
  /// </summary>
  /// <param name="lines">The buffer lines</param>
  /// <param name="oldCols">The columns before resize</param>
  /// <param name="newCols">The columns after resize</param>
  /// <param name="bufferAbsoluteY"></param>
  /// <param name="nullCharacter"></param>
  List<int> _getLinesToRemove(
      CircularList<BufferLine> lines, int oldCols, int newCols) {
    // Gather all BufferLines that need to be removed from the Buffer here so that they can be
    // batched up and only committed once
    final toRemove = List<int>.empty(growable: true);

    for (int y = 0; y < lines.length - 1; y++) {
      // Check if this row is wrapped
      int i = y;
      BufferLine nextLine = lines[++i];
      if (!nextLine.isWrapped) {
        continue;
      }

      // Check how many lines it's wrapped for
      final wrappedLines = List<BufferLine>.empty(growable: true);
      wrappedLines.add(lines[y]);
      while (i < lines.length && nextLine.isWrapped) {
        wrappedLines.add(nextLine);
        nextLine = lines[++i];
      }

      final bufferAbsoluteY = buffer.cursorY + buffer.scrollOffsetFromTop;

      // If these lines contain the cursor don't touch them, the program will handle fixing up wrapped
      // lines with the cursor
      if (bufferAbsoluteY >= y && bufferAbsoluteY < i) {
        y += wrappedLines.length - 1;
        continue;
      }

      // Copy buffer data to new locations
      int destLineIndex = 0;
      int destCol = ReflowStrategy.getWrappedLineTrimmedLengthFromCircularList(
          buffer.lines, destLineIndex, oldCols);
      int srcLineIndex = 1;
      int srcCol = 0;
      while (srcLineIndex < wrappedLines.length) {
        int srcTrimmedTineLength =
            ReflowStrategy.getWrappedLineTrimmedLengthFromLines(
                wrappedLines, srcLineIndex, oldCols);
        int srcRemainingCells = srcTrimmedTineLength - srcCol;
        int destRemainingCells = newCols - destCol;
        int cellsToCopy = min(srcRemainingCells, destRemainingCells);

        wrappedLines[destLineIndex].copyCellsFrom(
            wrappedLines[srcLineIndex], srcCol, destCol, cellsToCopy);

        destCol += cellsToCopy;
        if (destCol == newCols) {
          destLineIndex++;
          destCol = 0;
        }

        srcCol += cellsToCopy;
        if (srcCol == srcTrimmedTineLength) {
          srcLineIndex++;
          srcCol = 0;
        }

        // Make sure the last cell isn't wide, if it is copy it to the current dest
        if (destCol == 0 && destLineIndex != 0) {
          if (wrappedLines[destLineIndex - 1].cellGetWidth(newCols - 1) == 2) {
            wrappedLines[destLineIndex].copyCellsFrom(
                wrappedLines[destLineIndex - 1], newCols - 1, destCol++, 1);
            // Null out the end of the last row
            wrappedLines[destLineIndex - 1]
                .erase(buffer.terminal.cursor, newCols - 1, newCols, false);
          }
        }
      }

      // Clear out remaining cells or fragments could remain;
      wrappedLines[destLineIndex]
          .erase(buffer.terminal.cursor, destCol, newCols);

      // Work backwards and remove any rows at the end that only contain null cells
      int countToRemove = 0;
      for (int ix = wrappedLines.length - 1; ix > 0; ix--) {
        if (ix > destLineIndex ||
            wrappedLines[ix].getTrimmedLength(oldCols) == 0) {
          countToRemove++;
        } else {
          break;
        }
      }

      if (countToRemove > 0) {
        toRemove.add(y + wrappedLines.length - countToRemove); // index
        toRemove.add(countToRemove);
      }

      y += wrappedLines.length - 1;
    }

    return toRemove;
  }

  LayoutResult _createNewLayout(
      CircularList<BufferLine> lines, List<int> toRemove) {
    var layout = new CircularList<int>(lines.length);

    // First iterate through the list and get the actual indexes to use for rows
    int nextToRemoveIndex = 0;
    int nextToRemoveStart = toRemove[nextToRemoveIndex];
    int countRemovedSoFar = 0;

    for (int i = 0; i < lines.length; i++) {
      if (nextToRemoveStart == i) {
        int countToRemove = toRemove[++nextToRemoveIndex];

        // Tell markers that there was a deletion
        //lines.onDeleteEmitter.fire ({
        //	index: i - countRemovedSoFar,
        //	amount: countToRemove
        //});

        i += countToRemove - 1;
        countRemovedSoFar += countToRemove;

        nextToRemoveStart = lines.length + 1; //was: int.max
        if (nextToRemoveIndex < toRemove.length - 1)
          nextToRemoveStart = toRemove[++nextToRemoveIndex];
      } else {
        layout.push(i);
      }
    }

    return new LayoutResult(layout, countRemovedSoFar);
  }

  void _applyNewLayout(
      CircularList<BufferLine> lines, CircularList<int> newLayout) {
    var newLayoutLines = new CircularList<BufferLine>(lines.length);

    for (int i = 0; i < newLayout.length; i++) {
      newLayoutLines.push(lines[newLayout[i]]);
    }

    // Rearrange the list
    for (int i = 0; i < newLayoutLines.length; i++) {
      lines[i] = newLayoutLines[i];
    }

    lines.length = newLayout.length;
  }

  void _adjustViewport(int newCols, int newRows, int countRemoved) {
    int viewportAdjustments = countRemoved;
    while (viewportAdjustments-- > 0) {
      if (buffer.lines.length <= buffer.terminal.viewHeight) {
        //cursor is not at the top
        if (buffer.cursorY > 0) {
          buffer.moveCursorY(-1);
        }
        //buffer doesn't have enough lines
        if (buffer.lines.length < buffer.terminal.viewHeight) {
          // Add an extra row at the bottom of the viewport
          buffer.lines.push(BufferLine());
        }
      }
    }

    buffer.adjustSavedCursor(0, -countRemoved);
  }
}

class LayoutResult {
  CircularList<int> layout;
  int removedCount;

  LayoutResult(this.layout, this.removedCount);
}
