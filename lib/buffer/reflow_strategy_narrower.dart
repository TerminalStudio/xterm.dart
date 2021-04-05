import 'dart:math';

import 'package:xterm/buffer/buffer.dart';
import 'package:xterm/buffer/buffer_line.dart';
import 'package:xterm/buffer/reflow_strategy.dart';
import 'package:xterm/utli/circular_list.dart';

class ReflowStrategyNarrower extends ReflowStrategy {
  ReflowStrategyNarrower(Buffer buffer) : super(buffer);

  @override
  void reflow(int newCols, int newRows, int oldCols, int oldRows) {
    // Gather all BufferLines that need to be inserted into the Buffer here so that they can be
    // batched up and only committed once
    List<InsertionSet> toInsert = List<InsertionSet>.empty(growable: true);
    var countToInsert = 0;

    // Go backwards as many lines may be trimmed and this will avoid considering them
    for (int y = buffer.lines.length - 1; y >= 0; y--) {
      // Check whether this line is a problem or not, if not skip it
      BufferLine nextLine = buffer.lines[y]!;
      int lineLength = nextLine.getTrimmedLength(oldCols);
      if (!nextLine.isWrapped && lineLength <= newCols) {
        continue;
      }

      // Gather wrapped lines and adjust y to be the starting line
      final wrappedLines = List<BufferLine>.empty(growable: true);
      wrappedLines.add(nextLine);
      while (nextLine.isWrapped && y > 0) {
        nextLine = buffer.lines[--y]!;
        wrappedLines.insert(0, nextLine);
      }

      // If these lines contain the cursor don't touch them, the program will handle fixing up
      // wrapped lines with the cursor
      final absoluteY = buffer.cursorY + buffer.scrollOffsetFromTop;

      if (absoluteY >= y && absoluteY < y + wrappedLines.length) {
        continue;
      }

      int lastLineLength = wrappedLines.last.getTrimmedLength(oldCols);
      final destLineLengths =
          _getNewLineLengths(wrappedLines, oldCols, newCols);
      int linesToAdd = destLineLengths.length - wrappedLines.length;

      // Add the new lines
      final newLines = List<BufferLine>.empty(growable: true);
      for (int i = 0; i < linesToAdd; i++) {
        BufferLine newLine = BufferLine(isWrapped: true);
        newLines.add(newLine);
      }

      if (newLines.length > 0) {
        toInsert.add(InsertionSet()
          ..start = y + wrappedLines.length + countToInsert
          ..lines = List<BufferLine>.from(newLines));

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
          srcCol = ReflowStrategy.getWrappedLineTrimmedLengthFromLines(
              wrappedLines, wrappedLinesIndex, oldCols);
        }
      }

      // Null out the end of the line ends if a wide character wrapped to the following line
      for (int i = 0; i < wrappedLines.length; i++) {
        if (destLineLengths[i] < newCols) {
          wrappedLines[i].removeRange(destLineLengths[i], oldCols);
        }
      }

      buffer.adjustSavedCursor(0, linesToAdd);
    }

    rearrange(toInsert, countToInsert);
  }

  void rearrange(List<InsertionSet> toInsert, int countToInsert) {
    // Rearrange lines in the buffer if there are any insertions, this is done at the end rather
    // than earlier so that it's a single O(n) pass through the buffer, instead of O(n^2) from many
    // costly calls to CircularList.splice.
    if (toInsert.length > 0) {
      // Record buffer insert events and then play them back backwards so that the indexes are
      // correct
      List<int> insertEvents = List<int>.empty(growable: true);

      // Record original lines so they don't get overridden when we rearrange the list
      CircularList<BufferLine> originalLines =
          new CircularList<BufferLine>(buffer.lines.maxLength);
      for (int i = 0; i < buffer.lines.length; i++) {
        originalLines.push(buffer.lines[i]!);
      }

      int originalLinesLength = buffer.lines.length;

      int originalLineIndex = originalLinesLength - 1;
      int nextToInsertIndex = 0;
      var nextToInsert = toInsert[nextToInsertIndex];
      buffer.lines.length =
          min(buffer.lines.maxLength, buffer.lines.length + countToInsert);

      int countInsertedSoFar = 0;
      for (int i = min(buffer.lines.maxLength - 1,
              originalLinesLength + countToInsert - 1);
          i >= 0;
          i--) {
        if (!nextToInsert.isNull &&
            nextToInsert.start > originalLineIndex + countInsertedSoFar) {
          // Insert extra lines here, adjusting i as needed
          for (int nextI = nextToInsert.lines!.length - 1;
              nextI >= 0;
              nextI--) {
            if (i < 0) {
              // if we reflow and the content has to be scrolled back past the beginning
              // of the buffer then we end up loosing those lines
              break;
            }

            buffer.lines[i--] = nextToInsert.lines![nextI];
          }

          i++;

          // Create insert events for later
          //insertEvents.Add ({
          //	index: originalLineIndex + 1,
          //	amount: nextToInsert.newLines.length
          //});

          countInsertedSoFar += nextToInsert.lines!.length;
          if (nextToInsertIndex < toInsert.length - 1) {
            nextToInsert = toInsert[++nextToInsertIndex];
          } else {
            nextToInsert = InsertionSet.nul;
          }
        } else {
          buffer.lines[i] = originalLines[originalLineIndex--];
        }
      }

      /*
				// Update markers
				let insertCountEmitted = 0;
				for (let i = insertEvents.length - 1; i >= 0; i--) {
					insertEvents [i].index += insertCountEmitted;
					this.lines.onInsertEmitter.fire (insertEvents [i]);
					insertCountEmitted += insertEvents [i].amount;
				}
				const amountToTrim = Math.max (0, originalLinesLength + countToInsert - this.lines.maxLength);
				if (amountToTrim > 0) {
					this.lines.onTrimEmitter.fire (amountToTrim);
				}
				*/
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
    final newLineLengths = List<int>.empty(growable: true);

    int cellsNeeded = 0;
    for (int i = 0; i < wrappedLines.length; i++) {
      cellsNeeded += ReflowStrategy.getWrappedLineTrimmedLengthFromLines(
          wrappedLines, i, oldCols);
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
          ReflowStrategy.getWrappedLineTrimmedLengthFromLines(
              wrappedLines, srcLine, oldCols);
      if (srcCol > oldTrimmedLength) {
        srcCol -= oldTrimmedLength;
        srcLine++;
      }

      bool endsWithWide = wrappedLines[srcLine].cellGetWidth(srcCol - 1) == 2;
      if (endsWithWide) {
        srcCol--;
      }

      int lineLength = endsWithWide ? newCols - 1 : newCols;
      newLineLengths.add(lineLength);
      cellsAvailable += lineLength;
    }

    return newLineLengths;
  }
}

class InsertionSet {
  List<BufferLine>? lines;
  int start = 0;
  bool isNull = false;

  static InsertionSet nul = InsertionSet()..isNull = true;
}
