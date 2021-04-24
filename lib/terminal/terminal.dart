import 'dart:collection';
import 'dart:math' show max, min;

import 'package:xterm/buffer/buffer.dart';
import 'package:xterm/buffer/buffer_line.dart';
import 'package:xterm/mouse/position.dart';
import 'package:xterm/mouse/selection.dart';
import 'package:xterm/input/keys.dart';
import 'package:xterm/input/keytab/keytab.dart';
import 'package:xterm/input/keytab/keytab_escape.dart';
import 'package:xterm/input/keytab/keytab_record.dart';
import 'package:xterm/mouse/mouse_mode.dart';
import 'package:xterm/terminal/ansi.dart';
import 'package:xterm/terminal/cursor.dart';
import 'package:xterm/terminal/platform.dart';
import 'package:xterm/terminal/sbc.dart';
import 'package:xterm/terminal/tabs.dart';
import 'package:xterm/terminal/terminal_backend.dart';
import 'package:xterm/terminal/terminal_ui_interaction.dart';
import 'package:xterm/theme/terminal_color.dart';
import 'package:xterm/theme/terminal_theme.dart';
import 'package:xterm/theme/terminal_themes.dart';
import 'package:xterm/util/debug_handler.dart';
import 'package:xterm/util/observable.dart';

typedef TerminalInputHandler = void Function(String);
typedef BellHandler = void Function();
typedef TitleChangeHandler = void Function(String);
typedef IconChangeHandler = void Function(String);

void _defaultBellHandler() {}
void _defaultTitleHandler(String _) {}
void _defaultIconHandler(String _) {}

class Terminal with Observable implements TerminalUiInteraction {
  Terminal({
    this.backend,
    this.onBell = _defaultBellHandler,
    this.onTitleChange = _defaultTitleHandler,
    this.onIconChange = _defaultIconHandler,
    this.platform = PlatformBehaviors.unix,
    this.theme = TerminalThemes.defaultTheme,
    required int maxLines,
  }) : _maxLines = maxLines {
    backend?.init();
    backend?.out.listen(write);
    _mainBuffer = Buffer(terminal: this, isAltBuffer: false);
    _altBuffer = Buffer(terminal: this, isAltBuffer: true);
    _buffer = _mainBuffer;

    cursor = Cursor(
      fg: theme.foreground,
      bg: TerminalColor.transparent, // transparent
      flags: 0x00, // no flags
    );

    tabs.reset();
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
    return max(viewHeight, _maxLines);
  }

  int _viewWidth = 80;
  int _viewHeight = 25;

  int get viewWidth => _viewWidth;
  int get viewHeight => _viewHeight;

  int get visibleHeight => min(_viewHeight, buffer.height);
  int get invisibleHeight => buffer.height - visibleHeight;

  /// ### Insert/Replace Mode (IRM)
  ///
  /// The terminal displays received characters at the cursor position.
  /// Insert/Replace mode determines how the terminal adds characters to the
  /// screen. Insert mode displays the new character and moves previously
  /// displayed characters to the right. Replace mode adds characters by
  /// replacing the character at the cursor position.
  ///
  /// You can set or reset insert/replace mode as follows.
  bool _replaceMode = true;

  bool _screenMode = false; // DECSCNM (black on white background)
  bool _autoWrapMode = true;
  bool get autoWrapMode => _autoWrapMode;

  /// ### DECOM – Origin Mode (DEC Private)
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

  /// ### LNM – Line Feed/New Line Mode
  ///
  /// This is a parameter applicable to set mode (SM) and reset mode (RM)
  /// control sequences. The reset state causes the interpretation of the line
  /// feed (LF), defined in ANSI Standard X3.4-1977, to imply only vertical
  /// movement of the active position and causes the RETURN key (CR) to send the
  /// single code CR. The set state causes the LF to imply movement to the first
  /// position of the following line and causes the RETURN key to send the two
  /// codes (CR, LF). This is the New Line (NL) option.
  ///
  /// This mode does not affect the index (IND), or next line (NEL) format
  /// effectors.
  bool get lineFeedMode => _lineFeedMode;
  bool _lineFeedMode = true;

  /// See: [lineFeedMode]
  bool get newLineMode => !_lineFeedMode;

  /// ### Bracketed Paste Mode
  ///
  /// When bracketed paste mode is set, pasted text is bracketed with control
  /// sequences so that the program can differentiate pasted text from typed-in
  /// text. When bracketed paste mode is set, the program will receive: `ESC
  /// [200 ~`, followed by the pasted text, followed by `ESC [ 201 ~`.
  bool get bracketedPasteMode => _bracketedPasteMode;
  bool _bracketedPasteMode = false;

  bool _showCursor = true;
  bool get showCursor => _showCursor;

  /// DECCKM – Cursor Keys Mode (DEC Private)
  ///
  /// This is a private parameter applicable to set mode (SM) and reset mode
  /// (RM) control sequences. This mode is only effective when the terminal is
  /// in keypad application mode (see DECKPAM) and the ANSI/VT52 mode (DECANM)
  /// is set (see DECANM). Under these conditions, if the cursor key mode is
  /// reset, the four cursor function keys will send ANSI cursor control
  /// commands. If cursor key mode is set, the four cursor function keys will
  /// send application functions.
  bool get applicationCursorKeys => _applicationCursorKeys;
  bool _applicationCursorKeys = false;

  bool _blinkingCursor = true;
  bool get blinkingCursor => _blinkingCursor;

  late Buffer _buffer;
  late Buffer _mainBuffer;
  late Buffer _altBuffer;

  /// Queue of input characters. addLast() to add, removeFirst() to consume.
  final _queue = ListQueue<int>(81920);

  bool _slowMotion = false;
  bool get slowMotion => _slowMotion;

  MouseMode _mouseMode = MouseMode.none;
  MouseMode get mouseMode => _mouseMode;

  final TerminalTheme theme;

  // final cellAttr = CellAttrTemplate();
  late final Cursor cursor;

  final keytab = Keytab.defaultKeytab();
  final _selection = Selection();
  final tabs = Tabs();
  final debug = DebugHandler();

  final TerminalBackend? backend;
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

  void setScrollOffsetFromBottom(int scrollOffset) {
    final oldOffset = _buffer.scrollOffsetFromBottom;
    _buffer.setScrollOffsetFromBottom(scrollOffset);
    if (oldOffset != scrollOffset) {
      _dirty = true;
      refresh();
    }
  }

  /// Writes data to the terminal. Terminal sequences and special characters are
  /// interpreted.
  ///
  /// See also: [Buffer.write]
  void write(String text) {
    _queue.addAll(text.runes);
    _processInput();
    refresh();
  }

  /// Writes data to the terminal. Special characters are interpreted.
  ///
  /// See also: [Buffer.writeChar]
  void writeChar(int codePoint) {
    _queue.addLast(codePoint);
    _processInput();
    refresh();
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
        final finished = ansiHandler(_queue, this);

        // Terminal sequence in the queue is not completed, and no charater is
        // consumed.
        if (!finished) {
          _queue.addFirst(esc);
          break;
        }

        continue;
      }

      _processChar(char);
    }
  }

  void _processChar(int codePoint) {
    // If the character doesn't have special effect. Write it directly to the
    // buffer.
    if (codePoint > sbcMaxCodePoint) {
      debug.onChar(codePoint);
      _buffer.writeChar(codePoint);
      return;
    }

    // The character may have special effect.
    final sbcHandler = sbcHandlers[codePoint];
    if (sbcHandler != null) {
      debug.onSbc(codePoint);
      sbcHandler(codePoint, this);
    }
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
    _lineFeedMode = false;
  }

  void setLineFeedMode() {
    _lineFeedMode = true;
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

  /// Resize the terminal screen. [newWidth] and [newHeight] should be greater
  /// than 0. Text reflow is currently not implemented and will be avaliable in
  /// the future.
  void resize(int newWidth, int newHeight) {
    backend?.resize(newWidth, newHeight);
    newWidth = max(newWidth, 1);
    newHeight = max(newHeight, 1);

    final oldWidth = _viewWidth;
    final oldHeight = _viewHeight;
    _viewWidth = newWidth;
    _viewHeight = newHeight;

    //we need to resize both buffers so that they are ready when we switch between them
    _altBuffer.resize(oldWidth, oldHeight, newWidth, newHeight);
    _mainBuffer.resize(oldWidth, oldHeight, newWidth, newHeight);

    // maybe reflow should happen here.
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
    bool mac = false,
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

      if (record.mac != null && record.mac != mac) {
        continue;
      }

      // TODO: support VT52
      if (record.ansi == false) {
        continue;
      }

      if (record.action.type == KeytabActionType.input) {
        debug.onMsg('input: ${record.action.value}');
        final input = keytabUnescape(record.action.value);
        backend?.write(input);
        return;
      }
    }

    if (ctrl) {
      if (key.index >= TerminalKey.keyA.index &&
          key.index <= TerminalKey.keyZ.index) {
        final input = key.index - TerminalKey.keyA.index + 1;
        backend?.write(String.fromCharCode(input));
        return;
      }
    }

    if (alt) {
      if (key.index >= TerminalKey.keyA.index &&
          key.index <= TerminalKey.keyZ.index) {
        final input = [0x1b, key.index - TerminalKey.keyA.index + 65];
        backend?.write(String.fromCharCodes(input));
        return;
      }
    }
  }

  String? getSelectedText() {
    if (_selection.isEmpty) {
      return null;
    }

    final builder = StringBuffer();

    for (var row = _selection.start!.y; row <= _selection.end!.y; row++) {
      if (row >= buffer.height) {
        break;
      }

      final line = buffer.lines[row];

      var xStart = 0;
      var xEnd = viewWidth - 1;

      if (row == _selection.start!.y) {
        xStart = _selection.start!.x;
      } else if (!line.isWrapped) {
        builder.write("\n");
      }

      if (row == _selection.end!.y) {
        xEnd = _selection.end!.x;
      }

      for (var col = xStart; col <= xEnd; col++) {
        // if (col >= line.length) {
        //   break;
        // }

        if (line.cellGetWidth(col) == 0) {
          continue;
        }

        var char = line.cellGetContent(col);

        if (char == 0x00) {
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

    backend?.write(data);
  }

  void selectWord(int x, int y) {}

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

  @override
  int get backgroundColor => theme.background;

  @override
  int get bufferHeight => buffer.height;

  @override
  void clearSelection() {
    selection?.clear();
  }

  @override
  int convertViewLineToRawLine(int viewLine) {
    if (viewHeight > buffer.height) {
      return viewLine;
    }

    return viewLine + (buffer.height - viewHeight);
  }

  @override
  BufferLine? get currentLine => buffer.currentLine;

  @override
  int get cursorColor => theme.cursor;

  @override
  bool get isReady => true;

  @override
  void onMouseTap(Position position) {
    mouseMode.onTap(this, position);
  }

  @override
  void onPanStart(Position position) {
    mouseMode.onPanStart(this, position);
  }

  @override
  void onPanUpdate(Position position) {
    mouseMode.onPanUpdate(this, position);
  }

  @override
  int get scrollOffsetFromBottom => buffer.scrollOffsetFromBottom;

  @override
  int get scrollOffsetFromTop => buffer.scrollOffsetFromTop;

  @override
  int get terminalHeight => viewHeight;

  @override
  int get terminalWidth => viewWidth;

  @override
  Selection? get selection => _selection;

  @override
  void raiseOnInput(String input) {
    backend?.write(input);
  }
}
