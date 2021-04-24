import 'dart:async';
import 'dart:isolate';

import 'package:xterm/buffer/buffer_line.dart';
import 'package:xterm/input/keys.dart';
import 'package:xterm/mouse/position.dart';
import 'package:xterm/mouse/selection.dart';
import 'package:xterm/terminal/platform.dart';
import 'package:xterm/terminal/terminal.dart';
import 'package:xterm/terminal/terminal_backend.dart';
import 'package:xterm/terminal/terminal_ui_interaction.dart';
import 'package:xterm/theme/terminal_theme.dart';
import 'package:xterm/theme/terminal_themes.dart';
import 'package:xterm/util/event_debouncer.dart';
import 'package:xterm/util/observable.dart';

enum _IsolateCommand {
  sendPort,
  init,
  write,
  refresh,
  clearSelection,
  mouseTap,
  mousePanStart,
  mousePanUpdate,
  setScrollOffsetFromTop,
  resize,
  onInput,
  keyInput,
  requestNewStateWhenDirty,
  paste,
  terminateBackend
}

enum _IsolateEvent {
  titleChanged,
  iconChanged,
  bell,
  notifyChange,
  newState,
  exit,
}

void terminalMain(SendPort port) async {
  final rp = ReceivePort();
  port.send(rp.sendPort);

  Terminal? _terminal;
  var _needNotify = true;

  await for (var msg in rp) {
    final _IsolateCommand action = msg[0];
    switch (action) {
      case _IsolateCommand.sendPort:
        port = msg[1];
        break;
      case _IsolateCommand.init:
        final TerminalInitData initData = msg[1];
        _terminal = Terminal(
            backend: initData.backend,
            onTitleChange: (String title) {
              port.send([_IsolateEvent.titleChanged, title]);
            },
            onIconChange: (String icon) {
              port.send([_IsolateEvent.iconChanged, icon]);
            },
            onBell: () {
              port.send([_IsolateEvent.bell]);
            },
            platform: initData.platform,
            theme: initData.theme,
            maxLines: initData.maxLines);
        _terminal.addListener(() {
          if (_needNotify) {
            port.send([_IsolateEvent.notifyChange]);
            _needNotify = false;
          }
        });
        _terminal.backendExited
            .then((value) => port.send([_IsolateEvent.exit, value]));
        port.send([_IsolateEvent.notifyChange]);
        break;
      case _IsolateCommand.write:
        _terminal?.write(msg[1]);
        break;
      case _IsolateCommand.refresh:
        _terminal?.refresh();
        break;
      case _IsolateCommand.clearSelection:
        _terminal?.selection!.clear();
        break;
      case _IsolateCommand.mouseTap:
        _terminal?.mouseMode.onTap(_terminal, msg[1]);
        break;
      case _IsolateCommand.mousePanStart:
        _terminal?.mouseMode.onPanStart(_terminal, msg[1]);
        break;
      case _IsolateCommand.mousePanUpdate:
        _terminal?.mouseMode.onPanUpdate(_terminal, msg[1]);
        break;
      case _IsolateCommand.setScrollOffsetFromTop:
        _terminal?.setScrollOffsetFromBottom(msg[1]);
        break;
      case _IsolateCommand.resize:
        _terminal?.resize(msg[1], msg[2]);
        break;
      case _IsolateCommand.onInput:
        _terminal?.backend?.write(msg[1]);
        break;
      case _IsolateCommand.keyInput:
        _terminal?.keyInput(msg[1],
            ctrl: msg[2], alt: msg[3], shift: msg[4], mac: msg[5]);
        break;
      case _IsolateCommand.requestNewStateWhenDirty:
        if (_terminal == null) {
          break;
        }
        if (_terminal.dirty) {
          final newState = TerminalState(
            _terminal.buffer.scrollOffsetFromBottom,
            _terminal.buffer.scrollOffsetFromTop,
            _terminal.buffer.height,
            _terminal.invisibleHeight,
            _terminal.viewHeight,
            _terminal.viewWidth,
            _terminal.selection!,
            _terminal.getSelectedText(),
            _terminal.theme.background,
            _terminal.cursorX,
            _terminal.cursorY,
            _terminal.showCursor,
            _terminal.theme.cursor,
            _terminal.getVisibleLines(),
            _terminal.scrollOffset,
          );
          port.send([_IsolateEvent.newState, newState]);
          _needNotify = true;
        }
        break;
      case _IsolateCommand.paste:
        _terminal?.paste(msg[1]);
        break;
      case _IsolateCommand.terminateBackend:
        _terminal?.terminateBackend();
    }
  }
}

class TerminalInitData {
  PlatformBehavior platform;
  TerminalTheme theme;
  int maxLines;
  TerminalBackend? backend;
  TerminalInitData(this.backend, this.platform, this.theme, this.maxLines);
}

class TerminalState {
  int scrollOffsetFromTop;
  int scrollOffsetFromBottom;

  int bufferHeight;
  int invisibleHeight;

  int viewHeight;
  int viewWidth;

  Selection selection;
  String? selectedText;

  int backgroundColor;

  int cursorX;
  int cursorY;
  bool showCursor;
  int cursorColor;

  List<BufferLine> visibleLines;

  int scrollOffset;

  bool consumed = false;

  TerminalState(
    this.scrollOffsetFromBottom,
    this.scrollOffsetFromTop,
    this.bufferHeight,
    this.invisibleHeight,
    this.viewHeight,
    this.viewWidth,
    this.selection,
    this.selectedText,
    this.backgroundColor,
    this.cursorX,
    this.cursorY,
    this.showCursor,
    this.cursorColor,
    this.visibleLines,
    this.scrollOffset,
  );
}

void _defaultBellHandler() {}
void _defaultTitleHandler(String _) {}
void _defaultIconHandler(String _) {}

class TerminalIsolate with Observable implements TerminalUiInteraction {
  final _receivePort = ReceivePort();
  SendPort? _sendPort;
  late Isolate _isolate;

  final TerminalBackend? backend;
  final BellHandler onBell;
  final TitleChangeHandler onTitleChange;
  final IconChangeHandler onIconChange;
  final PlatformBehavior _platform;

  final TerminalTheme theme;
  final int maxLines;

  final Duration minRefreshDelay;
  final EventDebouncer _refreshEventDebouncer;

  TerminalState? _lastState;

  TerminalState? get lastState {
    return _lastState;
  }

  TerminalIsolate({
    this.backend,
    this.onBell = _defaultBellHandler,
    this.onTitleChange = _defaultTitleHandler,
    this.onIconChange = _defaultIconHandler,
    PlatformBehavior platform = PlatformBehaviors.unix,
    this.theme = TerminalThemes.defaultTheme,
    this.minRefreshDelay = const Duration(milliseconds: 16),
    required this.maxLines,
  })   : _platform = platform,
        _refreshEventDebouncer = EventDebouncer(minRefreshDelay);

  @override
  int get scrollOffsetFromBottom => _lastState!.scrollOffsetFromBottom;

  @override
  int get scrollOffsetFromTop => _lastState!.scrollOffsetFromTop;

  @override
  int get scrollOffset => _lastState!.scrollOffset;

  @override
  int get bufferHeight => _lastState!.bufferHeight;

  @override
  int get terminalHeight => _lastState!.viewHeight;

  @override
  int get terminalWidth => _lastState!.viewWidth;

  @override
  int get invisibleHeight => _lastState!.invisibleHeight;

  @override
  Selection? get selection => _lastState?.selection;

  @override
  bool get showCursor => _lastState?.showCursor ?? true;

  @override
  List<BufferLine> getVisibleLines() {
    if (_lastState == null) {
      return List<BufferLine>.empty();
    }
    return _lastState!.visibleLines;
  }

  @override
  int get cursorY => _lastState?.cursorY ?? 0;

  @override
  int get cursorX => _lastState?.cursorX ?? 0;

  @override
  BufferLine? get currentLine {
    if (_lastState == null) {
      return null;
    }

    int visibleLineIndex =
        _lastState!.cursorY - _lastState!.scrollOffsetFromTop;
    if (visibleLineIndex < 0) {
      visibleLineIndex = _lastState!.cursorY;
    }
    return _lastState!.visibleLines[visibleLineIndex];
  }

  @override
  int get cursorColor => _lastState?.cursorColor ?? 0;

  @override
  int get backgroundColor => _lastState?.backgroundColor ?? 0;

  @override
  bool get dirty {
    if (_lastState == null) {
      return false;
    }
    if (_lastState!.consumed) {
      return false;
    }
    _lastState!.consumed = true;
    return true;
  }

  @override
  PlatformBehavior get platform => _platform;

  @override
  String? get selectedText => _lastState?.selectedText;

  @override
  bool get isReady => _lastState != null;

  void start() async {
    final initialRefreshCompleted = Completer<bool>();
    var firstReceivePort = ReceivePort();
    _isolate = await Isolate.spawn(terminalMain, firstReceivePort.sendPort);
    _sendPort = await firstReceivePort.first;
    _sendPort!.send([_IsolateCommand.sendPort, _receivePort.sendPort]);
    _receivePort.listen((message) {
      _IsolateEvent action = message[0];
      switch (action) {
        case _IsolateEvent.bell:
          this.onBell();
          break;
        case _IsolateEvent.titleChanged:
          this.onTitleChange(message[1]);
          break;
        case _IsolateEvent.iconChanged:
          this.onIconChange(message[1]);
          break;
        case _IsolateEvent.notifyChange:
          _refreshEventDebouncer.notifyEvent(() {
            poll();
          });
          break;
        case _IsolateEvent.newState:
          _lastState = message[1];
          if (!initialRefreshCompleted.isCompleted) {
            initialRefreshCompleted.complete(true);
          }
          this.notifyListeners();
          break;
        case _IsolateEvent.exit:
          _isTerminated = true;
          _backendExited.complete(message[1]);
          break;
      }
    });
    _sendPort!.send([
      _IsolateCommand.init,
      TerminalInitData(this.backend, this.platform, this.theme, this.maxLines)
    ]);
    await initialRefreshCompleted.future;
  }

  void stop() {
    _isolate.kill();
  }

  void poll() {
    _sendPort?.send([_IsolateCommand.requestNewStateWhenDirty]);
  }

  void refresh() {
    _sendPort?.send([_IsolateCommand.refresh]);
  }

  void clearSelection() {
    _sendPort?.send([_IsolateCommand.clearSelection]);
  }

  void onMouseTap(Position position) {
    _sendPort?.send([_IsolateCommand.mouseTap, position]);
  }

  void onPanStart(Position position) {
    _sendPort?.send([_IsolateCommand.mousePanStart, position]);
  }

  void onPanUpdate(Position position) {
    _sendPort?.send([_IsolateCommand.mousePanUpdate, position]);
  }

  void setScrollOffsetFromBottom(int offset) {
    _sendPort?.send([_IsolateCommand.setScrollOffsetFromTop, offset]);
  }

  int convertViewLineToRawLine(int viewLine) {
    if (_lastState == null) {
      return 0;
    }

    if (_lastState!.viewHeight > _lastState!.bufferHeight) {
      return viewLine;
    }

    return viewLine + (_lastState!.bufferHeight - _lastState!.viewHeight);
  }

  void write(String text) {
    _sendPort?.send([_IsolateCommand.write, text]);
  }

  void paste(String data) {
    _sendPort?.send([_IsolateCommand.paste, data]);
  }

  void resize(int newWidth, int newHeight) {
    _sendPort?.send([_IsolateCommand.resize, newWidth, newHeight]);
  }

  void raiseOnInput(String text) {
    _sendPort?.send([_IsolateCommand.onInput, text]);
  }

  void keyInput(
    TerminalKey key, {
    bool ctrl = false,
    bool alt = false,
    bool shift = false,
    bool mac = false,
    // bool meta,
  }) {
    _sendPort?.send([_IsolateCommand.keyInput, key, ctrl, alt, shift, mac]);
  }

  var _isTerminated = false;

  final _backendExited = Completer<int>();
  @override
  Future<int> get backendExited => _backendExited.future;

  @override
  void terminateBackend() {
    if (_isTerminated) {
      return;
    }
    _isTerminated = true;
    _sendPort?.send([_IsolateCommand.terminateBackend]);
  }

  @override
  bool get isTerminated => _isTerminated;
}
