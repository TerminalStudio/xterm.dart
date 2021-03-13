import 'dart:math';

import 'package:xterm/buffer/cell_attr.dart';

import 'buffer.dart';
import 'buffer_line.dart';

class LayoutResult {
  LayoutResult(this.layout, this.removedCount);

  final List<int> layout;
  final int removedCount;
}

class InsertionSet {
  InsertionSet({this.lines, this.start, this.isNull = false});

  final List<BufferLine>? lines;
  final int? start;
  final bool isNull;

  static InsertionSet nullValue = InsertionSet(isNull: true);
}

class BufferReflow {
  BufferReflow(this._buffer, this._emptyCellAttr);

  final Buffer _buffer;
  final CellAttr _emptyCellAttr;

  void doReflow(int colsBefore, int colsAfter) {
    if (colsBefore == colsAfter) {
      return;
    }

    if (colsAfter > colsBefore) {
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
      var newLayoutResult =
          _reflowLargerCreateNewLayout(_buffer.lines, toRemove);
      _reflowLargerApplyNewLayout(_buffer.lines, newLayoutResult.layout);
      _reflowLargerAdjustViewport(
          colsBefore, colsAfter, newLayoutResult.removedCount);
    }
  }

  void _reflowSmaller(int colsBefore, int colsAfter) {
    // Gather all BufferLines that need to be inserted into the Buffer here so that they can be
    // batched up and only committed once
    List<InsertionSet> toInsert = [];
    int countToInsert = 0;

    // Go backwards as many lines may be trimmed and this will avoid considering them
    for (int y = _buffer.lines.length - 1; y >= 0; y--) {
      // Check whether this line is a problem or not, if not skip it
      BufferLine nextLine = _buffer.lines[y];
      int lineLength = nextLine.getTrimmedLength();
      if (!nextLine.isWrapped && lineLength <= colsAfter) {
        continue;
      }

      // Gather wrapped lines and adjust y to be the starting line
      List<BufferLine> wrappedLines = [];
      wrappedLines.add(nextLine);
      while (nextLine.isWrapped && y > 0) {
        nextLine = _buffer.lines[--y];
        wrappedLines.insert(0, nextLine);
      }

      // If these lines contain the cursor don't touch them, the program will handle fixing up
      // wrapped lines with the cursor
      final absoluteY = _buffer.cursorY - _buffer.scrollOffsetFromBottom;

      if (absoluteY >= y && absoluteY < y + wrappedLines.length) {
        continue;
      }

      int lastLineLength = wrappedLines.last.getTrimmedLength();
      List<int> destLineLengths =
          _getNewLineLengths(wrappedLines, colsBefore, colsAfter);
      int linesToAdd = destLineLengths.length - wrappedLines.length;

      // Add the new lines
      List<BufferLine> newLines = [];
      for (int i = 0; i < linesToAdd; i++) {
        BufferLine newLine = BufferLine(numOfCells: colsAfter);
        newLines.add(newLine);
      }

      if (newLines.length > 0) {
        toInsert.add(InsertionSet(
            start: y + wrappedLines.length + countToInsert, lines: newLines));

        countToInsert += newLines.length;
      }

      newLines.forEach((l) => wrappedLines.add(l));

      // Copy buffer data to new locations, this needs to happen backwards to do in-place
      int destLineIndex =
          destLineLengths.length - 1; // Math.floor(cellsNeeded / newCols);
      int destCol = destLineLengths[destLineIndex]; // cellsNeeded % newCols;
      if (destCol == 0) {
        destLineIndex--;
        destCol = destLineLengths[destLineIndex];
      }

      int srcLineIndex = wrappedLines.length - linesToAdd - 1;
      int srcCol = lastLineLength;
      while (srcLineIndex >= 0) {
        int cellsToCopy = min(srcCol, destCol);
        wrappedLines[destLineIndex].copyCellsFrom(wrappedLines[srcLineIndex],
            srcCol - cellsToCopy, destCol - cellsToCopy, cellsToCopy);
        destCol -= cellsToCopy;
        if (destCol == 0) {
          destLineIndex--;
          if (destLineIndex >= 0) destCol = destLineLengths[destLineIndex];
        }

        srcCol -= cellsToCopy;
        if (srcCol == 0) {
          srcLineIndex--;
          int wrappedLinesIndex = max(srcLineIndex, 0);
          srcCol = _getWrappedLineTrimmedLengthRow(
              wrappedLines, wrappedLinesIndex, colsBefore);
        }
      }

      // Null out the end of the line ends if a wide character wrapped to the following line
      for (int i = 0; i < wrappedLines.length; i++) {
        if (destLineLengths[i] < colsAfter) {
          wrappedLines[i].removeRange(destLineLengths[i]);
        }
      }

      // Adjust viewport as needed
      //TODO: probably nothing to do here because of the way the ViewPort is handled compared to the xterm.js project
      // int viewportAdjustments = linesToAdd;
      // while (viewportAdjustments-- > 0) {
      //   if (Buffer.YBase == 0) {
      //     if (Buffer.Y < newRows - 1) {
      //       Buffer.Y++;
      //       Buffer.Lines.Pop();
      //     } else {
      //       Buffer.YBase++;
      //       Buffer.YDisp++;
      //     }
      //   } else {
      //     // Ensure ybase does not exceed its maximum value
      //     if (Buffer.YBase <
      //         Math.Min(Buffer.Lines.MaxLength,
      //                 Buffer.Lines.Length + countToInsert) -
      //             newRows) {
      //       if (Buffer.YBase == Buffer.YDisp) {
      //         Buffer.YDisp++;
      //       }
      //
      //       Buffer.YBase++;
      //     }
      //   }
      // }

      _buffer.adjustSavedCursor(0, linesToAdd);
      //TODO: maybe row count has to be handled here?
    }

    _rearrange(toInsert, countToInsert);
  }

  void _rearrange(List<InsertionSet> toInsert, int countToInsert) {
    // Rearrange lines in the buffer if there are any insertions, this is done at the end rather
    // than earlier so that it's a single O(n) pass through the buffer, instead of O(n^2) from many
    // costly calls to CircularList.splice.
    if (toInsert.length > 0) {
      // Record buffer insert events and then play them back backwards so that the indexes are
      // correct
      List<int> insertEvents = [];

      // Record original lines so they don't get overridden when we rearrange the list
      List<BufferLine> originalLines = List<BufferLine>.from(_buffer.lines);
      _buffer.lines.addAll(List<BufferLine>.generate(countToInsert,
          (index) => BufferLine(numOfCells: _buffer.terminal.viewWidth)));

      int originalLinesLength = originalLines.length;

      int originalLineIndex = originalLinesLength - 1;
      int nextToInsertIndex = 0;
      InsertionSet nextToInsert = toInsert[nextToInsertIndex];

      //TODO: remove rows that now are "too much"

      int countInsertedSoFar = 0;
      for (int i = originalLinesLength + countToInsert - 1; i >= 0; i--) {
        if (!nextToInsert.isNull &&
            nextToInsert.start != null &&
            nextToInsert.lines != null &&
            nextToInsert.start! > originalLineIndex + countInsertedSoFar) {
          // Insert extra lines here, adjusting i as needed
          for (int nextI = nextToInsert.lines!.length - 1;
              nextI >= 0;
              nextI--) {
            if (i < 0) {
              // if we reflow and the content has to be scrolled back past the beginning
              // of the buffer then we end up loosing those lines
              break;
            }

            _buffer.lines[i--] = nextToInsert.lines![nextI];
          }

          i++;

          countInsertedSoFar += nextToInsert.lines!.length;
          if (nextToInsertIndex < toInsert.length - 1) {
            nextToInsert = toInsert[++nextToInsertIndex];
          } else {
            nextToInsert = InsertionSet.nullValue;
          }
        } else {
          _buffer.lines[i] = originalLines[originalLineIndex--];
        }
      }
    }
  }

  /// <summary>
  /// Gets the new line lengths for a given wrapped line. The purpose of this function it to pre-
  /// compute the wrapping points since wide characters may need to be wrapped onto the following line.
  /// This function will return an array of numbers of where each line wraps to, the resulting array
  /// will only contain the values `newCols` (when the line does not end with a wide character) and
  /// `newCols - 1` (when the line does end with a wide character), except for the last value which
  /// will contain the remaining items to fill the line.
  /// Calling this with a `newCols` value of `1` will lock up.
  /// </summary>
  List<int> _getNewLineLengths(
      List<BufferLine> wrappedLines, int oldCols, int newCols) {
    List<int> newLineLengths = [];

    int cellsNeeded = 0;
    for (int i = 0; i < wrappedLines.length; i++) {
      cellsNeeded += _getWrappedLineTrimmedLengthRow(wrappedLines, i, oldCols);
    }

    // Use srcCol and srcLine to find the new wrapping point, use that to get the cellsAvailable and
    // linesNeeded
    int srcCol = 0;
    int srcLine = 0;
    int cellsAvailable = 0;
    while (cellsAvailable < cellsNeeded) {
      if (cellsNeeded - cellsAvailable < newCols) {
        // Add the final line and exit the loop
        newLineLengths.add(cellsNeeded - cellsAvailable);
        break;
      }

      srcCol += newCols;
      int oldTrimmedLength =
          _getWrappedLineTrimmedLengthRow(wrappedLines, srcLine, oldCols);
      if (srcCol > oldTrimmedLength) {
        srcCol -= oldTrimmedLength;
        srcLine++;
      }

      bool endsWithWide = wrappedLines[srcLine].getWidthAt(srcCol - 1) == 2;
      if (endsWithWide) {
        srcCol--;
      }

      int lineLength = endsWithWide ? newCols - 1 : newCols;
      newLineLengths.add(lineLength);
      cellsAvailable += lineLength;
    }

    return newLineLengths;
  }

  void _reflowLargerAdjustViewport(
      int colsBefore, int colsAfter, int countRemoved) {
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
          _buffer.lines
              .add(new BufferLine(numOfCells: colsAfter, attr: _emptyCellAttr));
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

  void _reflowLargerApplyNewLayout(
      List<BufferLine> lines, List<int> newLayout) {
    var newLayoutLines = List<BufferLine>.empty();

    for (int i = 0; i < newLayout.length; i++) {
      newLayoutLines.add(lines[newLayout[i]]);
    }

    // Rearrange the list
    for (int i = 0; i < newLayoutLines.length; i++) {
      lines[i] = newLayoutLines[i];
    }

    lines.removeRange(newLayoutLines.length, lines.length - 1);
  }

  LayoutResult _reflowLargerCreateNewLayout(
      List<BufferLine> lines, List<int> toRemove) {
    var layout = List<int>.empty();

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

        nextToRemoveStart = lines.length + 1;
        if (nextToRemoveIndex < toRemove.length - 1)
          nextToRemoveStart = toRemove[++nextToRemoveIndex];
      } else {
        layout.add(i);
      }
    }

    return LayoutResult(layout, countRemovedSoFar);
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
      int destCol = _getWrappedLineTrimmedLengthRow(
          _buffer.lines, destLineIndex, colsBefore);
      int srcLineIndex = 1;
      int srcCol = 0;
      while (srcLineIndex < wrappedLines.length) {
        int srcTrimmedTineLength = _getWrappedLineTrimmedLengthRow(
            wrappedLines, srcLineIndex, colsBefore);
        int srcRemainingCells = srcTrimmedTineLength - srcCol;
        int destRemainingCells = colsAfter - destCol;
        int cellsToCopy = min(srcRemainingCells, destRemainingCells);

        wrappedLines[destLineIndex].copyCellsFrom(
            wrappedLines[srcLineIndex], srcCol, destCol, cellsToCopy);

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
          if (wrappedLines[destLineIndex - 1].getWidthAt(colsAfter - 1) == 2) {
            wrappedLines[destLineIndex].copyCellsFrom(
                wrappedLines[destLineIndex - 1], colsAfter - 1, destCol++, 1);
            // Null out the end of the last row
            wrappedLines[destLineIndex - 1]
                .erase(_emptyCellAttr, colsAfter - 1, colsAfter);
          }
        }
      }

      // Clear out remaining cells or fragments could remain;
      wrappedLines[destLineIndex].erase(_emptyCellAttr, destCol, colsAfter);

      // Work backwards and remove any rows at the end that only contain null cells
      int countToRemove = 0;
      for (int ix = wrappedLines.length - 1; ix > 0; ix--) {
        if (ix > destLineIndex || wrappedLines[ix].getTrimmedLength() == 0) {
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

  int _getWrappedLineTrimmedLengthRow(
      List<BufferLine> lines, int row, int cols) {
    return _getWrappedLineTrimmedLength(
        lines[row], row == lines.length - 1 ? null : lines[row + 1], cols);
  }

  int _getWrappedLineTrimmedLength(
      BufferLine line, BufferLine? nextLine, int cols) {
    // If this is the last row in the wrapped line, get the actual trimmed length
    if (nextLine == null) {
      return line.getTrimmedLength();
    }

    // Detect whether the following line starts with a wide character and the end of the current line
    // is null, if so then we can be pretty sure the null character should be excluded from the line
    // length]
    bool endsInNull =
        !(line.hasContentAt(cols - 1)) && line.getWidthAt(cols - 1) == 1;
    bool followingLineStartsWithWide = nextLine.getWidthAt(0) == 2;

    if (endsInNull && followingLineStartsWithWide) {
      return cols - 1;
    }

    return cols;
  }
}
