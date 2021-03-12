import 'dart:collection';
import 'dart:math' show max, min;

import 'package:xterm/buffer/buffer.dart';
import 'package:xterm/buffer/buffer_line.dart';
import 'package:xterm/buffer/cell_attr.dart';
import 'package:xterm/mouse/selection.dart';
import 'package:xterm/input/keys.dart';
import 'package:xterm/input/keytab/keytab.dart';
import 'package:xterm/input/keytab/keytab_escape.dart';
import 'package:xterm/input/keytab/keytab_record.dart';
import 'package:xterm/mouse/mouse_mode.dart';
import 'package:xterm/terminal/ansi.dart';
import 'package:xterm/terminal/platform.dart';
import 'package:xterm/terminal/sbc.dart';
import 'package:xterm/terminal/tabs.dart';
import 'package:xterm/theme/terminal_theme.dart';
import 'package:xterm/theme/terminal_themes.dart';
import 'package:xterm/utli/debug_handler.dart';
import 'package:xterm/utli/observable.dart';

typedef TerminalInputHandler = void Function(String);
typedef BellHandler = void Function();
typedef TitleChangeHandler = void Function(String);
typedef IconChangeHandler = void Function(String);

void _defaultInputHandler(String _) {}
void _defaultBellHandler() {}
void _defaultTitleHandler(String _) {}
void _defaultIconHandler(String _) {}

class Terminal with Observable {
  Terminal({
    this.onInput = _defaultInputHandler,
    this.onBell = _defaultBellHandler,
    this.onTitleChange = _defaultTitleHandler,
    this.onIconChange = _defaultIconHandler,
    this.platform = PlatformBehaviors.unix,
    this.theme = TerminalThemes.defaultTheme,
    int? maxLines,
  }) {
    _maxLines = maxLines;

    _mainBuffer = Buffer(this);
    _altBuffer = Buffer(this);
    _buffer = _mainBuffer;

    tabs.reset();

    // _buffer.write('this is magic!');
  }

  bool _dirty = false;
  bool get dirty {
    if (_dirty) {
      _dirty = false;
      return true;
    } else {
      return false;
    }
  }

  int? _maxLines;
  int? get maxLines {
    if (_maxLines == null) return null;
    return max(viewHeight, _maxLines!);
  }

  int _viewWidth = 80;
  int _viewHeight = 25;

  int get viewWidth => _viewWidth;
  int get viewHeight => _viewHeight;

  int get visibleHeight => min(_viewHeight, buffer.height);
  int get invisibleHeight => buffer.height - visibleHeight;

  /// Insert/Replace Mode (IRM)
  ///
  /// The terminal displays received characters at the cursor position.
  /// Insert/Replace mode determines how the terminal adds characters to the
  /// screen. Insert mode displays the new character and moves previously
  /// displayed characters to the right. Replace mode adds characters by
  /// replacing the character at the cursor position.
  ///
  /// You can set or reset insert/replace mode as follows.
  bool _replaceMode = true;

  bool _lineFeed = true;
  bool _screenMode = false; // DECSCNM (black on white background)
  bool _autoWrapMode = true;
  bool _bracketedPasteMode = false;

  /// DECOM – Origin Mode (DEC Private)
  ///
  /// This is a private parameter applicable to set mode (SM) and reset mode
  /// (RM) control sequences. The reset state causes the origin to be at the
  /// upper-left character position on the screen. Line and column numbers are,
  /// therefore, independent of current margin settings. The cursor may be
  /// positioned outside the margins with a cursor position (CUP) or horizontal
  /// and vertical position (HVP) control.
  ///
  /// The set state causes the origin to be at the upper-left character position
  /// within the margins. Line and column numbers are therefore relative to the
  /// current margin settings. The cursor is not allowed to be positioned
  /// outside the margins.
  ///
  /// The cursor is moved to the new home position when this mode is set or
  /// reset.
  ///
  /// Lines and columns are numbered consecutively, with the origin being line
  /// 1, column 1.
  bool get originMode => _originMode;
  bool _originMode = false;

  bool get lineFeed => _lineFeed;
  bool get newLineMode => !_lineFeed;
  bool get bracketedPasteMode => _bracketedPasteMode;

  bool _showCursor = true;
  bool _applicationCursorKeys = false;
  bool _blinkingCursor = true;

  bool get showCursor => _showCursor;
  bool get applicationCursorKeys => _applicationCursorKeys;
  bool get blinkingCursor => _blinkingCursor;

  late Buffer _buffer;
  late Buffer _mainBuffer;
  late Buffer _altBuffer;

  /// Queue of input characters. addLast() to add, removeFirst() to consume.
  final _queue = Queue<int>();

  bool _slowMotion = false;
  bool get slowMotion => _slowMotion;

  MouseMode _mouseMode = MouseMode.none;
  MouseMode get mouseMode => _mouseMode;

  final TerminalTheme theme;
  final cellAttr = CellAttrTemplate();

  final keytab = Keytab.defaultKeytab();
  final selection = Selection();
  final tabs = Tabs();
  final debug = DebugHandler();

  final TerminalInputHandler onInput;
  final BellHandler onBell;
  final TitleChangeHandler onTitleChange;
  final IconChangeHandler onIconChange;
  final PlatformBehavior platform;

  Buffer get buffer {
    return _buffer;
  }

  int get cursorX => buffer.cursorX;
  int get cursorY => buffer.cursorY;
  int get scrollOffset => buffer.scrollOffsetFromBottom;

  void write(String text) async {
    _queue.addAll(text.runes);
    _processInput();
  }

  void writeBytes(Iterable<int> data) async {
    _queue.addAll(data);
    _processInput();
  }

  void writeChar(int codePoint) {
    _queue.addLast(codePoint);
    _processInput();
  }

  List<BufferLine> getVisibleLines() {
    return _buffer.getVisibleLines();
  }

  void _processInput() {
    while (_queue.isNotEmpty) {
      // if (_slowMotion) {
      //   await Future.delayed(Duration(milliseconds: 100));
      // }

      const esc = 0x1b;
      final char = _queue.removeFirst();

      if (char == esc) {
        ansiHandler(_queue, this);
        refresh();
        continue;
      }

      _processChar(char);
    }
  }

  void _processChar(int codePoint) {
    final sbcHandler = sbcHandlers[codePoint];

    if (sbcHandler != null) {
      debug.onSbc(codePoint);
      sbcHandler(codePoint, this);
    } else {
      debug.onChar(codePoint);
      _buffer.writeChar(codePoint);
    }

    refresh();
  }

  void refresh() {
    _dirty = true;
    notifyListeners();
  }

  void setSlowMotion(bool enabled) {
    _slowMotion = enabled;
  }

  void setOriginMode(bool enabled) {
    _originMode = enabled;
    buffer.setPosition(0, 0);
  }

  void setScreenMode(bool enabled) {
    _screenMode = true;
  }

  void setApplicationCursorKeys(bool enabled) {
    _applicationCursorKeys = enabled;
  }

  void setShowCursor(bool showCursor) {
    _showCursor = showCursor;
  }

  void setBlinkingCursor(bool enabled) {
    _blinkingCursor = enabled;
  }

  void setAutoWrapMode(bool enabled) {
    _autoWrapMode = enabled;
  }

  void setBracketedPasteMode(bool enabled) {
    _bracketedPasteMode = enabled;
  }

  void setInsertMode() {
    _replaceMode = false;
  }

  void setReplaceMode() {
    _replaceMode = true;
  }

  void setNewLineMode() {
    _lineFeed = false;
  }

  void setLineFeedMode() {
    _lineFeed = true;
  }

  void setMouseMode(MouseMode mode) {
    _mouseMode = mode;
  }

  void useMainBuffer() {
    _buffer = _mainBuffer;
  }

  void useAltBuffer() {
    _buffer = _altBuffer;
  }

  bool isUsingMainBuffer() {
    return _buffer == _mainBuffer;
  }

  bool isUsingAltBuffer() {
    return _buffer == _altBuffer;
  }

  void resize(int width, int height) {
    _altBuffer.resize(width, height);
    _mainBuffer.resize(width, height);
    final cursorY = buffer.convertViewLineToRawLine(buffer.cursorY);

    _viewWidth = max(width, 1);
    _viewHeight = max(height, 1);

    buffer.setCursorY(buffer.convertRawLineToViewLine(cursorY));

    if (buffer == _altBuffer) {
      buffer.clearScrollback();
    }

    buffer.resetVerticalMargins();
  }

  void keyInput(
    TerminalKey key, {
    bool ctrl = false,
    bool alt = false,
    bool shift = false,
    // bool meta,
  }) {
    debug.onMsg(key);

    for (var record in keytab.records) {
      if (record.key != key) {
        continue;
      }

      if (record.ctrl != null && record.ctrl != ctrl) {
        continue;
      }

      if (record.shift != null && record.shift != shift) {
        continue;
      }

      if (record.alt != null && record.alt != alt) {
        continue;
      }

      if (record.anyModifier == true &&
          (ctrl != true && alt != true && shift != true)) {
        continue;
      }

      if (record.anyModifier == false &&
          !(ctrl != true && alt != true && shift != true)) {
        continue;
      }

      if (record.appScreen != null && record.appScreen != isUsingAltBuffer()) {
        continue;
      }

      if (record.newLine != null && record.newLine != newLineMode) {
        continue;
      }

      if (record.appCursorKeys != null &&
          record.appCursorKeys != applicationCursorKeys) {
        continue;
      }

      // TODO: support VT52
      if (record.ansi == false) {
        continue;
      }

      if (record.action.type == KeytabActionType.input) {
        debug.onMsg('input: ${record.action.value}');
        final input = keytabUnescape(record.action.value);
        onInput(input);
        return;
      }
    }

    if (ctrl) {
      if (key.index >= TerminalKey.keyA.index &&
          key.index <= TerminalKey.keyZ.index) {
        final input = key.index - TerminalKey.keyA.index + 1;
        onInput(String.fromCharCode(input));
        return;
      }
    }

    if (alt) {
      if (key.index >= TerminalKey.keyA.index &&
          key.index <= TerminalKey.keyZ.index) {
        final input = [0x1b, key.index - TerminalKey.keyA.index + 65];
        onInput(String.fromCharCodes(input));
        return;
      }
    }
  }

  String? getSelectedText() {
    if (selection.isEmpty) {
      return null;
    }

    final builder = StringBuffer();

    for (var row = selection.start!.y; row <= selection.end!.y; row++) {
      if (row >= buffer.height) {
        break;
      }

      final line = buffer.lines[row];

      var xStart = 0;
      var xEnd = viewWidth - 1;

      if (row == selection.start!.y) {
        xStart = selection.start!.x;
      } else if (!line.isWrapped) {
        builder.write("\n");
      }

      if (row == selection.end!.y) {
        xEnd = selection.end!.x;
      }

      for (var col = xStart; col <= xEnd; col++) {
        if (col >= line.length) {
          break;
        }

        final cell = line.getCell(col);

        if (cell.width == 0) {
          continue;
        }

        var char = line.getCell(col).codePoint;

        if (char == null || char == 0x00) {
          const blank = 32;
          char = blank;
        }

        builder.writeCharCode(char);
      }
    }

    return builder.toString();
  }

  void paste(String data) {
    if (bracketedPasteMode) {
      data = '\x1b[200~$data\x1b[201~';
    }

    onInput(data);
  }

  int get _tabIndexFromCursor {
    var index = buffer.cursorX;

    if (buffer.cursorX == viewWidth) {
      index = 0;
    }

    return index;
  }

  void tabSetAtCursor() {
    tabs.setAt(_tabIndexFromCursor);
  }

  void tabClearAtCursor() {
    tabs.clearAt(_tabIndexFromCursor);
  }

  void tab() {
    while (buffer.cursorX < viewWidth) {
      buffer.write(' ');

      if (tabs.isSetAt(buffer.cursorX)) {
        break;
      }
    }
  }
}
