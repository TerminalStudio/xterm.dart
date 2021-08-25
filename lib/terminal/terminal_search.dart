import 'package:xterm/buffer/line/line.dart';
import 'package:xterm/terminal/terminal.dart';

class TerminalSearchResult {
  final _hitsByLine = Map<int, List<TerminalSearchHit>>();

  TerminalSearchResult.fromHits(List<TerminalSearchHit> hits) {
    for (final hit in hits) {
      if (!_hitsByLine.containsKey(hit.startLineIndex)) {
        _hitsByLine[hit.startLineIndex] =
            List<TerminalSearchHit>.empty(growable: true);
      }
      if (!_hitsByLine.containsKey(hit.endLineIndex)) {
        _hitsByLine[hit.endLineIndex] =
            List<TerminalSearchHit>.empty(growable: true);
      }
      _hitsByLine[hit.startLineIndex]!.add(hit);
      if (hit.startLineIndex != hit.endLineIndex) {
        _hitsByLine[hit.endLineIndex]!.add(hit);
      }
    }
  }

  TerminalSearchResult.empty();

  bool hasEntriesForLine(int line) {
    return _hitsByLine.containsKey(line);
  }

  List<TerminalSearchHit> getEntriesForLine(int line) {
    return _hitsByLine[line] ?? List<TerminalSearchHit>.empty(growable: false);
  }

  bool contains(int line, int col) {
    return _hitsByLine[line]?.any((hit) => hit.contains(line, col)) ?? false;
  }
}

class TerminalSearchHit {
  TerminalSearchHit(
      this.startLineIndex, this.startIndex, this.endLineIndex, this.endIndex);

  final int startLineIndex;
  final int startIndex;
  final int endLineIndex;
  final int endIndex;

  bool contains(int line, int col) {
    if (line < startLineIndex || line > endLineIndex) {
      return false;
    }
    if (line == startLineIndex && startLineIndex == endLineIndex) {
      return col >= startIndex && col < endIndex;
    }
    if (line == startLineIndex) {
      return col >= startIndex;
    }
    if (line == endLineIndex) {
      return col < endIndex;
    }
    // here we are sure that the given point is inside a full line match
    return true;
  }
}

typedef MarkSearchDoneFunc = void Function(BufferLine line);
typedef IsSearchDirtyFunc = bool Function(BufferLine line);

class TerminalSearch {
  TerminalSearch(
      this._terminal, this._markSearchDoneFunc, this._isSearchDirtyFunc);

  final Terminal _terminal;
  final MarkSearchDoneFunc _markSearchDoneFunc;
  final IsSearchDirtyFunc _isSearchDirtyFunc;

  String? _lastSearchPattern = null;
  TerminalSearchResult? _lastSearchResult = null;
  bool? _hasBeenUsingAltBuffer;

  TerminalSearchResult doSearch(String searchPattern) {
    final bufferLength = _terminal.buffer.lines.length;
    final terminalWidth = _terminal.terminalWidth;

    var isSearchDirty = false;
    //check if the search is dirty and return if not
    if (_lastSearchPattern != null &&
        _lastSearchPattern == searchPattern &&
        _lastSearchResult != null &&
        _hasBeenUsingAltBuffer != null &&
        _hasBeenUsingAltBuffer! == _terminal.isUsingAltBuffer()) {
      for (var i = 0; i < bufferLength; i++) {
        if (_isSearchDirtyFunc(_terminal.buffer.lines[i])) {
          isSearchDirty = true;
          break;
        }
      }
    } else {
      isSearchDirty = true;
    }

    if (!isSearchDirty) {
      return _lastSearchResult!;
    }

    //TODO: make caseSensitive an option
    final searchRegex =
        RegExp(searchPattern, caseSensitive: false, multiLine: false);

    final result = List<TerminalSearchHit>.empty(growable: true);

    final bufferContent = StringBuffer();
    for (var i = 0; i < bufferLength; i++) {
      final BufferLine line = _terminal.buffer.lines[i];
      final searchString = line.toSearchString(terminalWidth);
      _markSearchDoneFunc(line);
      bufferContent.write(searchString);
      if (searchString.length < terminalWidth) {
        // fill up so that the row / col can be mapped back later on
        bufferContent.writeAll(
            List<String>.filled(terminalWidth - searchString.length, ' '));
      }
    }

    for (final match in searchRegex.allMatches(bufferContent.toString())) {
      final startLineIndex = (match.start / terminalWidth).floor();
      final endLineIndex = (match.end / terminalWidth).floor();

      // subtract the lines that got added in order to get the index inside the line
      final startIndex = match.start - startLineIndex * terminalWidth;
      final endIndex = match.end - endLineIndex * terminalWidth;

      result.add(
        TerminalSearchHit(
          startLineIndex,
          startIndex,
          endLineIndex,
          endIndex,
        ),
      );
    }
    _lastSearchPattern = searchPattern;
    _lastSearchResult = TerminalSearchResult.fromHits(result);
    _hasBeenUsingAltBuffer = _terminal.isUsingAltBuffer();
    return _lastSearchResult!;
  }
}
