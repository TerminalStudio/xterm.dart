import 'dart:math';

import 'package:xterm/buffer/cell_attr.dart';
import 'package:dart_numeric'

import 'buffer.dart';
import 'buffer_line.dart';

class LayoutResult {

  LayoutResult(this.layout, this.removedCount);

  final List<int> layout;
  final int removedCount;
}

class BufferReflow {
  BufferReflow(this._buffer, this._emptyCellAttr);

  final Buffer _buffer;
  final CellAttr _emptyCellAttr;

  void doReflow(int colsBefore, int colsAfter) {
    if(colsBefore == colsAfter) {
      return;
    }

    if(colsAfter > colsBefore) {
      //got larger
      _reflowLarger(colsBefore, colsAfter);
    } else {
      //got smaller
      _reflowSmaller(colsBefore, colsAfter);
    }
  }

  void _reflowLarger(int colsBefore, int colsAfter) {
    var toRemove = _reflowLargerGetLinesToRemove(colsBefore, colsAfter);
    if (toRemove.length > 0) {
      var newLayoutResult = _reflowLargerCreateNewLayout(_buffer.lines, toRemove);
      _reflowLargerApplyNewLayout(_buffer.lines, newLayoutResult.layout);
      _reflowLargerAdjustViewport(colsBefore, colsAfter, newLayoutResult.removedCount);
    }
  }

  void _reflowSmaller(int colsBefore, int colsAfter) {

  }

  void _reflowLargerAdjustViewport(int colsBefore, int colsAfter, int countRemoved) {
    // Adjust viewport based on number of items removed
    var viewportAdjustments = countRemoved;
    while (viewportAdjustments-- > 0) {
      //viewport is at the top
      if (_buffer.lines.length <= _buffer.terminal.viewHeight) {
        //cursor is not at the top
        if (_buffer.cursorY > 0) {
          _buffer.moveCursorY(-1);
        }
        //buffer doesn't have enough lines
        if (_buffer.lines.length < _buffer.terminal.viewHeight) {
          // Add an extra row at the bottom of the viewport
          _buffer.lines.add(new BufferLine(numOfCells: colsAfter, attr: _emptyCellAttr));
        }
      } else {
        //Nothing to do here due to the way scrolling is handled

        // //user didn't scroll
        // if (this.ydisp === this.ybase) {
        //   //scroll viewport according to...
        //   this.ydisp--;
        // }
        // //base window
        // this.ybase--;
      }
    }
    //TODO: adjust buffer content to max length
    _buffer.adjustSavedCursor(0, -countRemoved);
  }

  void _reflowLargerApplyNewLayout(List<BufferLine> lines, List<int> newLayout) {
    var newLayoutLines = List<BufferLine>.empty();

    for (int i = 0; i < newLayout.length; i++) {
      newLayoutLines.add(lines[newLayout [i]]);
    }

    // Rearrange the list
    for (int i = 0; i < newLayoutLines.length; i++) {
      lines[i] = newLayoutLines[i];
    }

    lines.removeRange(newLayoutLines.length, lines.length - 1);
  }

  LayoutResult _reflowLargerCreateNewLayout(List<BufferLine> lines, List<int> toRemove) {
    var layout = List<int>.empty();

    // First iterate through the list and get the actual indexes to use for rows
    int nextToRemoveIndex = 0;
    int nextToRemoveStart = toRemove [nextToRemoveIndex];
    int countRemovedSoFar = 0;

    for (int i = 0; i < lines.length; i++) {
      if (nextToRemoveStart == i) {
        int countToRemove = toRemove [++nextToRemoveIndex];

        // Tell markers that there was a deletion
        //lines.onDeleteEmitter.fire ({
        //	index: i - countRemovedSoFar,
        //	amount: countToRemove
        //});

        i += countToRemove - 1;
        countRemovedSoFar += countToRemove;

        nextToRemoveStart = lines.length + 1;
        if (nextToRemoveIndex < toRemove.length - 1)
          nextToRemoveStart = toRemove [++nextToRemoveIndex];
      } else {
        layout.add(i);
      }
    }

    return LayoutResult (layout, countRemovedSoFar);
  }

  List<int> _reflowLargerGetLinesToRemove(int colsBefore, int colsAfter) {
    List<int> toRemove = List<int>.empty();

    

    for (int y = 0; y < _buffer.lines.length - 1; y++) {
      // Check if this row is wrapped
      int i = y;
      BufferLine nextLine = _buffer.lines[++i];
      if (!nextLine.isWrapped) {
        continue;
      }

      // Check how many lines it's wrapped for
      List<BufferLine> wrappedLines = List<BufferLine>.empty();
      wrappedLines.add(_buffer.lines[y]);
      while (i < _buffer.lines.length && nextLine.isWrapped) {
        wrappedLines.add(nextLine);
        nextLine = _buffer.lines[++i];
      }

      final bufferAbsoluteY = _buffer.cursorY - _buffer.scrollOffsetFromBottom;

      // If these lines contain the cursor don't touch them, the program will handle fixing up wrapped
      // lines with the cursor
      if (bufferAbsoluteY >= y && bufferAbsoluteY < i) {
        y += wrappedLines.length - 1;
        continue;
      }

      // Copy buffer data to new locations
      int destLineIndex = 0;
      int destCol = _getWrappedLineTrimmedLengthRow(_buffer.lines, destLineIndex, colsBefore);
      int srcLineIndex = 1;
      int srcCol = 0;
      while (srcLineIndex < wrappedLines.length) {
        int srcTrimmedTineLength = _getWrappedLineTrimmedLengthRow(wrappedLines, srcLineIndex, colsBefore);
        int srcRemainingCells = srcTrimmedTineLength - srcCol;
        int destRemainingCells = colsAfter - destCol;
        int cellsToCopy = min(srcRemainingCells, destRemainingCells);

        wrappedLines [destLineIndex].copyCellsFrom (wrappedLines [srcLineIndex], srcCol, destCol, cellsToCopy);

        destCol += cellsToCopy;
        if (destCol == colsAfter) {
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
          if (wrappedLines [destLineIndex - 1].getWidthAt(colsAfter - 1) == 2) {
            wrappedLines [destLineIndex].copyCellsFrom (wrappedLines [destLineIndex - 1], colsAfter - 1, destCol++, 1);
            // Null out the end of the last row
            wrappedLines [destLineIndex - 1].erase (_emptyCellAttr, colsAfter - 1, colsAfter);
          }
        }
      }

      // Clear out remaining cells or fragments could remain;
      wrappedLines [destLineIndex].erase(_emptyCellAttr, destCol, colsAfter);

      // Work backwards and remove any rows at the end that only contain null cells
      int countToRemove = 0;
      for (int ix = wrappedLines.length - 1; ix > 0; ix--) {
        if (ix > destLineIndex || wrappedLines [ix].getTrimmedLength () == 0) {
          countToRemove++;
        } else {
          break;
        }
      }

      if (countToRemove > 0) {
        toRemove.add (y + wrappedLines.length - countToRemove); // index
        toRemove.add (countToRemove);
      }

      y += wrappedLines.length - 1;
    }

    return toRemove;
  }


  int _getWrappedLineTrimmedLengthRow(List<BufferLine> lines, int row, int cols)
  {
    return _getWrappedLineTrimmedLength (lines[row], row == lines.length - 1 ? null : lines[row + 1], cols);
  }

  int _getWrappedLineTrimmedLength (BufferLine line, BufferLine? nextLine, int cols)
  {
    // If this is the last row in the wrapped line, get the actual trimmed length
    if (nextLine == null) {
      return line.getTrimmedLength ();
    }

    // Detect whether the following line starts with a wide character and the end of the current line
    // is null, if so then we can be pretty sure the null character should be excluded from the line
    // length]
    bool endsInNull = !(line.hasContentAt(cols - 1)) && line.getWidthAt(cols - 1) == 1;
    bool followingLineStartsWithWide = nextLine.getWidthAt(0) == 2;

    if (endsInNull && followingLineStartsWithWide) {
      return cols - 1;
    }

    return cols;
  }
}