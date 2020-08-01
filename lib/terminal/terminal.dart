import 'dart:async';
import 'dart:math' show max;

import 'package:async/async.dart';
import 'package:xterm/buffer/buffer.dart';
import 'package:xterm/buffer/buffer_line.dart';
import 'package:xterm/buffer/cell_attr.dart';
import 'package:xterm/mouse/selection.dart';
import 'package:xterm/color/color_default.dart';
import 'package:xterm/input/keys.dart';
import 'package:xterm/input/keytab/keytab.dart';
import 'package:xterm/input/keytab/keytab_escape.dart';
import 'package:xterm/input/keytab/keytab_record.dart';
import 'package:xterm/mouse/mouse_mode.dart';
import 'package:xterm/terminal/ansi.dart';
import 'package:xterm/terminal/sbc.dart';
import 'package:xterm/terminal/tabs.dart';
import 'package:xterm/utli/debug_handler.dart';
import 'package:xterm/utli/observable.dart';

typedef TerminalInputHandler = void Function(String);
typedef BellHandler = void Function();
typedef TitleChangeHandler = void Function(String);
typedef IconChangeHandler = void Function(String);

class Terminal with Observable {
  Terminal({
    this.onInput,
    this.onBell,
    this.onTitleChange,
    this.onIconChange,
    int maxLines,
  }) {
    _maxLines = maxLines;

    _mainBuffer = Buffer(this);
    _altBuffer = Buffer(this);
    _buffer = _mainBuffer;

    _input = StreamController<int>();
    _queue = StreamQueue<int>(_input.stream);

    tabs.reset();

    _processInput();
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

  int _maxLines;
  int get maxLines {
    if (_maxLines == null) return null;
    return max(viewHeight, _maxLines);
  }

  int _viewWidth = 80;
  int _viewHeight = 25;

  int get viewWidth => _viewWidth;
  int get viewHeight => _viewHeight;

  bool _originMode = false;
  bool _replaceMode = false;
  bool _lineFeed = true;
  bool _screenMode = false; // DECSCNM (black on white background)
  bool _autoWrapMode = true;
  bool _bracketedPasteMode = false;

  bool get originMode => _originMode;
  bool get lineFeed => _lineFeed;
  bool get newLineMode => !_lineFeed;

  bool _showCursor = true;
  bool _applicationCursorKeys = false;
  bool _blinkingCursor = true;

  bool get showCursor => _showCursor;
  bool get applicationCursorKeys => _applicationCursorKeys;
  bool get blinkingCursor => _blinkingCursor;

  Buffer _buffer;
  Buffer _mainBuffer;
  Buffer _altBuffer;

  StreamController<int> _input;
  StreamQueue<int> _queue;

  bool _slowMotion = false;
  bool get slowMotion => _slowMotion;

  MouseMode _mouseMode = MouseMode.none;
  MouseMode get mouseMode => _mouseMode;

  final colorScheme = defaultColorScheme;
  var cellAttr = CellAttr(fgColor: defaultColorScheme.foreground);

  final keytab = Keytab.defaultKeytab();
  final selection = Selection();
  final tabs = Tabs();
  final debug = DebugHandler();

  final TerminalInputHandler onInput;
  final BellHandler onBell;
  final TitleChangeHandler onTitleChange;
  final IconChangeHandler onIconChange;

  void close() {
    _input.close();
    _queue.cancel();
  }

  Buffer get buffer {
    return _buffer;
  }

  int get cursorX => buffer.cursorX;
  int get cursorY => buffer.cursorY;
  int get scrollOffset => buffer.scrollOffset;

  void write(String text) async {
    for (var char in text.runes) {
      writeChar(char);
    }
  }

  void writeChar(int codePoint) {
    _input.add(codePoint);
  }

  List<BufferLine> getVisibleLines() {
    return _buffer.getVisibleLines();
  }

  void _processInput() async {
    while (true) {
      if (_slowMotion) {
        await Future.delayed(Duration(milliseconds: 100));
      }

      const esc = 0x1b;
      final char = await _queue.next;

      if (char == esc) {
        await ansiHandler(_queue, this);
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
    _slowMotion = enabled ?? _slowMotion;
  }

  void setOriginMode(bool enabled) {
    _originMode = enabled ?? _originMode;
    buffer.setPosition(0, 0);
  }

  void setScreenMode(bool enabled) {
    _screenMode = true;
  }

  void setApplicationCursorKeys(bool enabled) {
    _applicationCursorKeys = enabled ?? _applicationCursorKeys;
  }

  void setShowCursor(bool showCursor) {
    _showCursor = showCursor ?? _showCursor;
  }

  void setBlinkingCursor(bool enabled) {
    _blinkingCursor = enabled ?? _blinkingCursor;
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
    _mouseMode = mode ?? _mouseMode;
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

  void resize(int width, int heigth) {
    final cursorY = buffer.convertViewLineToRawLine(buffer.cursorY);

    _viewWidth = max(width, 1);
    _viewHeight = max(heigth, 1);

    buffer.setCursorY(buffer.convertRawLineToViewLine(cursorY));

    buffer.resetVerticalMargins();

    if (buffer == _altBuffer) {
      buffer.clearScrollback();
    }
  }

  void input(
    TerminalKey key, {
    bool ctrl,
    bool alt,
    bool shift,
    // bool meta,
  }) {
    if (onInput == null) {
      return;
    }

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

  String getSelectedText() {
    if (selection.isEmpty) {
      return '';
    }

    final builder = StringBuffer();

    for (var row = selection.start.y; row <= selection.end.y; row++) {
      if (row >= buffer.height) {
        break;
      }

      final line = buffer.lines[row];

      var xStart = 0;
      var xEnd = viewWidth - 1;

      if (row == selection.start.y) {
        xStart = selection.start.x;
      } else if (!line.isWrapped) {
        builder.write("\n");
      }

      if (row == selection.end.y) {
        xEnd = selection.end.x;
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
