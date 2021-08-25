import 'package:meta/meta.dart';
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

class TerminalSearchTask {
  TerminalSearchTask(this._search, this._terminal, this._markSearchDoneFunc,
      this._isSearchDirtyFunc);

  final TerminalSearch _search;
  final Terminal _terminal;
  String? _pattern = null;
  bool _isPatternDirty = true;
  RegExp? _searchRegexp = null;
  final MarkSearchDoneFunc _markSearchDoneFunc;
  final IsSearchDirtyFunc _isSearchDirtyFunc;

  bool? _hasBeenUsingAltBuffer;
  TerminalSearchResult? _lastSearchResult = null;

  bool _isAnyLineDirty() {
    final bufferLength = _terminal.buffer.lines.length;
    for (var i = 0; i < bufferLength; i++) {
      if (_isSearchDirtyFunc(_terminal.buffer.lines[i])) {
        return true;
      }
    }
    return false;
  }

  bool _isTerminalStateDirty() {
    if (_isAnyLineDirty()) {
      return true;
    }
    if (_hasBeenUsingAltBuffer != null &&
        _hasBeenUsingAltBuffer! != _terminal.isUsingAltBuffer()) {
      return true;
    }
    return false;
  }

  bool get isDirty {
    if (_isPatternDirty) {
      return true;
    }
    return _isTerminalStateDirty();
  }

  String? get pattern => _pattern;
  void set pattern(String? newPattern) {
    if (newPattern != _pattern) {
      _pattern = newPattern;
      _isPatternDirty = true;
      _searchRegexp = null;
    }
  }

  TerminalSearchResult get searchResult {
    if (_pattern == null) {
      return TerminalSearchResult.empty();
    }
    if (_lastSearchResult != null && !isDirty) {
      return _lastSearchResult!;
    }
    _isPatternDirty = false;

    final terminalWidth = _terminal.terminalWidth;

    //TODO: make caseSensitive an option
    if (_searchRegexp == null) {
      _searchRegexp = RegExp(_pattern!, caseSensitive: false, multiLine: false);
    }

    final hits = List<TerminalSearchHit>.empty(growable: true);

    for (final match
        in _searchRegexp!.allMatches(_search.terminalSearchString)) {
      final startLineIndex = (match.start / terminalWidth).floor();
      final endLineIndex = (match.end / terminalWidth).floor();

      // subtract the lines that got added in order to get the index inside the line
      final startIndex = match.start - startLineIndex * terminalWidth;
      final endIndex = match.end - endLineIndex * terminalWidth;

      hits.add(
        TerminalSearchHit(
          startLineIndex,
          startIndex,
          endLineIndex,
          endIndex,
        ),
      );
    }

    _lastSearchResult = TerminalSearchResult.fromHits(hits);
    _hasBeenUsingAltBuffer = _terminal.isUsingAltBuffer();
    return _lastSearchResult!;
  }
}

class TerminalSearch {
  TerminalSearch(this._terminal);

  final Terminal _terminal;
  String? _cachedSearchString;
  int? _lastTerminalWidth;

  TerminalSearchTask createSearchTask(MarkSearchDoneFunc markSearchDoneFunc,
      IsSearchDirtyFunc isSearchDirtyFunc) {
    return TerminalSearchTask(
        this, _terminal, markSearchDoneFunc, isSearchDirtyFunc);
  }

  String get terminalSearchString {
    final bufferLength = _terminal.buffer.lines.length;
    final terminalWidth = _terminal.terminalWidth;

    var isAnySearchStringInvalid = false;
    for (var i = 0; i < bufferLength; i++) {
      if (!_terminal.buffer.lines[i].hasCachedSearchString) {
        isAnySearchStringInvalid = true;
      }
    }

    late String completeSearchString;
    if (_cachedSearchString != null &&
        _lastTerminalWidth != null &&
        _lastTerminalWidth! == terminalWidth &&
        !isAnySearchStringInvalid) {
      completeSearchString = _cachedSearchString!;
    } else {
      final bufferContent = StringBuffer();
      for (var i = 0; i < bufferLength; i++) {
        final BufferLine line = _terminal.buffer.lines[i];
        final searchString = line.toSearchString(terminalWidth);
        bufferContent.write(searchString);
        if (searchString.length < terminalWidth) {
          // fill up so that the row / col can be mapped back later on
          bufferContent.writeAll(
              List<String>.filled(terminalWidth - searchString.length, ' '));
        }
      }
      completeSearchString = bufferContent.toString();
      _cachedSearchString = completeSearchString;
      _lastTerminalWidth = terminalWidth;
    }

    return completeSearchString;
  }
}
