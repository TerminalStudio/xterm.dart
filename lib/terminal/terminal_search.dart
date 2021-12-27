import 'package:equatable/equatable.dart';
import 'package:xterm/buffer/line/line.dart';
import 'package:xterm/terminal/terminal_search_interaction.dart';
import 'package:xterm/util/constants.dart';
import 'package:xterm/util/unicode_v11.dart';

/// Represents a search result.
/// This instance will be replaced as a whole when the search has to be re-triggered
/// It stores the hits the search produced and the navigation state inside
/// the search results
class TerminalSearchResult {
  late final _allHits;
  int? _currentSearchHit;

  /// creates a new search result instance from the given hits
  TerminalSearchResult.fromHits(List<TerminalSearchHit> hits) {
    _allHits = hits;

    if (_allHits.length > 0) {
      _currentSearchHit = _allHits.length;
    } else {
      _currentSearchHit = null;
    }
  }

  /// creates an empty search result
  TerminalSearchResult.empty()
      : _allHits = List<TerminalSearchHit>.empty(growable: false);

  /// returns all hits of this search result
  List<TerminalSearchHit> get allHits => _allHits;

  /// returns the number of the current search hit
  int? get currentSearchHit => _currentSearchHit;

  /// sets the current search hit number
  set currentSearchHit(int? currentSearchHit) {
    if (_allHits.length <= 0) {
      _currentSearchHit = null;
    } else {
      _currentSearchHit = currentSearchHit != null
          ? currentSearchHit.clamp(1, _allHits.length).toInt()
          : null;
    }
  }
}

/// Represents one search hit
class TerminalSearchHit {
  TerminalSearchHit(
      this.startLineIndex, this.startIndex, this.endLineIndex, this.endIndex);

  /// index of the line where the hit starts
  final int startLineIndex;

  /// index of the hit start inside the start line
  final int startIndex;

  /// index of the line where the hit starts
  final int endLineIndex;

  /// index of the hit end inside the end line
  final int endIndex;

  /// checks if the given cell (line / col) is contained in this hit
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

/// represents options for a terminal search
class TerminalSearchOptions extends Equatable {
  TerminalSearchOptions({
    this.caseSensitive = false,
    this.matchWholeWord = false,
    this.useRegex = false,
  });

  /// defines if the search should be case sensitive. If set to [false] then
  /// the search will be case insensitive
  final bool caseSensitive;

  /// defines if the search should match whole words.
  final bool matchWholeWord;

  /// defines if the search should treat the pattern as a regex, or not
  final bool useRegex;

  /// creates a new TerminalSearchOptions instance based on this one changing the
  /// given parameters
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

/// represents a search task.
/// A search task can deliver search results based on the given parameters.
/// It takes care to cache the results as long as possible and re-trigger a
/// search on demand only when necessary
class TerminalSearchTask {
  TerminalSearchTask(this._search, this._terminal, this._dirtyTagName,
      this._terminalSearchOptions);

  final TerminalSearch _search;
  final TerminalSearchInteraction _terminal;
  String? _pattern;
  bool _isPatternDirty = true;
  RegExp? _searchRegexp;
  final String _dirtyTagName;
  TerminalSearchOptions _terminalSearchOptions;

  bool _isActive = false;

  /// indicates if the current search task is active
  bool get isActive => _isActive;

  /// sets the active state of this search task
  set isActive(bool isActive) {
    _isActive = isActive;
    if (isActive) {
      _invalidate();
    }
  }

  bool? _hasBeenUsingAltBuffer;
  TerminalSearchResult? _lastSearchResult;

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

  /// the currently used pattern of this search task
  String? get pattern => _pattern;

  /// sets the pattern to use for this search task
  set pattern(String? newPattern) {
    if (newPattern != _pattern) {
      _pattern = newPattern;
      _invalidate();
    }
  }

  /// the currently used search options
  TerminalSearchOptions get options => _terminalSearchOptions;

  /// sets the search options to use
  set options(TerminalSearchOptions newOptions) {
    if (_terminalSearchOptions == newOptions) {
      return;
    }
    _terminalSearchOptions = newOptions;
    _invalidate();
  }

  /// returns the hit that is currently the selected one (based on the search
  /// result navigation)
  TerminalSearchHit? get currentSearchHitObject {
    if (searchResult.currentSearchHit == null) {
      return null;
    }
    if (searchResult.allHits.length >= searchResult.currentSearchHit! &&
        searchResult.currentSearchHit! > 0) {
      return searchResult.allHits[searchResult.currentSearchHit! - 1];
    }
    return null;
  }

  /// the number of search hits in the current search result
  int get numberOfSearchHits => searchResult.allHits.length;

  /// number of the hit that is currently selected
  int? get currentSearchHit => searchResult.currentSearchHit;

  /// sets the hit number that shall be selected
  set currentSearchHit(int? currentSearchHit) {
    searchResult.currentSearchHit = currentSearchHit;
  }

  void _invalidate() {
    _isPatternDirty = true;
    _searchRegexp = null;
    _lastSearchResult = null;
  }

  String _createRegexPattern(String inputPattern) {
    final result = StringBuffer();

    for (final rune in inputPattern.runes) {
      final runeString = String.fromCharCode(rune);
      result.write(runeString);
      final cellWidth = unicodeV11.wcwidth(rune);
      final widthDiff = cellWidth - runeString.length;
      if (widthDiff > 0) {
        result.write(''.padRight(widthDiff));
      }
    }

    return result.toString();
  }

  /// returns the current search result or triggers a new search if it has to
  /// the result is a up to date search result either way
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
      _searchRegexp = RegExp(_createRegexPattern(pattern),
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

/// main entry for terminal searches. This class is the factory for search tasks
/// and will cache the search string that gets generated out of the terminal content
/// so that all search tasks created by this search can use the same cached search string
class TerminalSearch {
  TerminalSearch(this._terminal);

  final TerminalSearchInteraction _terminal;
  String? _cachedSearchString;
  int? _lastTerminalWidth;

  /// creates a new search task that will use this search to access a cached variant
  /// of the terminal search string
  TerminalSearchTask createSearchTask(String dirtyTagName) {
    return TerminalSearchTask(
        this, _terminal, dirtyTagName, TerminalSearchOptions());
  }

  /// returns the current terminal search string. The search string will be
  /// refreshed on demand if
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
