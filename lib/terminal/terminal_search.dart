import 'package:equatable/equatable.dart';
import 'package:xterm/buffer/line/line.dart';
import 'package:xterm/terminal/terminal.dart';
import 'package:xterm/util/constants.dart';

class TerminalSearchResult {
  final _hitsByLine = Map<int, List<TerminalSearchHit>>();
  late final _allHits;
  int _currentSearchHit = 0;

  TerminalSearchResult.fromHits(List<TerminalSearchHit> hits) {
    _allHits = hits;
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
    if (_allHits.length > 0) {
      _currentSearchHit = 1;
    } else {
      _currentSearchHit = 0;
    }
  }

  TerminalSearchResult.empty()
      : _allHits = List<TerminalSearchHit>.empty(growable: false);

  List<TerminalSearchHit> get allHits => _allHits;

  int get currentSearchHit => _currentSearchHit;
  void set currentSearchHit(int currentSearchHit) {
    if (_allHits.length <= 0) {
      _currentSearchHit = 0;
    } else {
      _currentSearchHit = currentSearchHit.clamp(1, _allHits.length).toInt();
    }
  }

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

class TerminalSearchOptions extends Equatable {
  TerminalSearchOptions({
    this.caseSensitive = false,
    this.matchWholeWord = false,
    this.useRegex = false,
  });

  final bool caseSensitive;
  final bool matchWholeWord;
  final bool useRegex;

  TerminalSearchOptions copyWith(
      {bool? caseSensitive, bool? matchWholeWord, bool? useRegex}) {
    return TerminalSearchOptions(
      caseSensitive: caseSensitive ?? this.caseSensitive,
      matchWholeWord: matchWholeWord ?? this.matchWholeWord,
      useRegex: useRegex ?? this.useRegex,
    );
  }

  @override
  bool get stringify => true;

  @override
  List<Object?> get props => [
        caseSensitive,
        matchWholeWord,
        useRegex,
      ];
}

class TerminalSearchTask {
  TerminalSearchTask(this._search, this._terminal, this._dirtyTagName,
      this._terminalSearchOptions);

  final TerminalSearch _search;
  final Terminal _terminal;
  String? _pattern = null;
  bool _isPatternDirty = true;
  RegExp? _searchRegexp = null;
  final String _dirtyTagName;
  TerminalSearchOptions _terminalSearchOptions;

  bool _isActive = false;
  bool get isActive => _isActive;
  void set isActive(bool isActive) {
    _isActive = isActive;
    if (isActive) {
      _invalidate();
    }
  }

  bool? _hasBeenUsingAltBuffer;
  TerminalSearchResult? _lastSearchResult = null;

  bool _isAnyLineDirty() {
    final bufferLength = _terminal.buffer.lines.length;
    for (var i = 0; i < bufferLength; i++) {
      if (_terminal.buffer.lines[i].isTagDirty(_dirtyTagName)) {
        return true;
      }
    }
    return false;
  }

  void _markLinesForSearchDone() {
    final bufferLength = _terminal.buffer.lines.length;
    for (var i = 0; i < bufferLength; i++) {
      _terminal.buffer.lines[i].markTagAsNonDirty(_dirtyTagName);
    }
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

  bool get _isDirty {
    if (_isPatternDirty) {
      return true;
    }
    return _isTerminalStateDirty();
  }

  String? get pattern => _pattern;
  void set pattern(String? newPattern) {
    if (newPattern != _pattern) {
      _pattern = newPattern;
      _invalidate();
    }
  }

  TerminalSearchOptions get options => _terminalSearchOptions;
  void set options(TerminalSearchOptions newOptions) {
    if (_terminalSearchOptions == newOptions) {
      return;
    }
    _terminalSearchOptions = newOptions;
    _invalidate();
  }

  void _invalidate() {
    _isPatternDirty = true;
    _searchRegexp = null;
  }

  TerminalSearchResult get searchResult {
    if (_pattern == null || !_isActive) {
      return TerminalSearchResult.empty();
    }
    if (_lastSearchResult != null && !_isDirty) {
      return _lastSearchResult!;
    }

    final terminalWidth = _terminal.terminalWidth;

    if (_searchRegexp == null) {
      var pattern = _pattern!;
      if (!_terminalSearchOptions.useRegex) {
        pattern = RegExp.escape(_pattern!);
      }
      final regex = '(?<hit>$pattern)';
      _searchRegexp = RegExp(regex,
          caseSensitive: _terminalSearchOptions.caseSensitive,
          multiLine: false);
    }

    final hits = List<TerminalSearchHit>.empty(growable: true);

    for (final match
        in _searchRegexp!.allMatches(_search.terminalSearchString)) {
      final start = match.start;
      final end = match.end;
      final startLineIndex = (start / terminalWidth).floor();
      final endLineIndex = (end / terminalWidth).floor();

      // subtract the lines that got added in order to get the index inside the line
      final startIndex = start - startLineIndex * terminalWidth;
      final endIndex = end - endLineIndex * terminalWidth;

      if (_terminalSearchOptions.matchWholeWord) {
        // we match a whole word when the hit fulfills:
        // 1) starts at a line beginning or has a word-separator before it
        final startIsOK =
            startIndex == 0 || kWordSeparators.contains(match.input[start - 1]);
        // 2) ends with a line or has a word-separator after it
        final endIsOK = endIndex == terminalWidth ||
            kWordSeparators.contains(match.input[end]);

        if (!startIsOK || !endIsOK) {
          continue;
        }
      }

      hits.add(
        TerminalSearchHit(
          startLineIndex,
          startIndex,
          endLineIndex,
          endIndex,
        ),
      );
    }

    _markLinesForSearchDone();

    _isPatternDirty = false;
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

  TerminalSearchTask createSearchTask(String dirtyTagName) {
    return TerminalSearchTask(
        this, _terminal, dirtyTagName, TerminalSearchOptions());
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
