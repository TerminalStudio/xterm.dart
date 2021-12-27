import 'package:xterm/buffer/line/line.dart';
import 'package:xterm/input/keys.dart';
import 'package:xterm/mouse/position.dart';
import 'package:xterm/mouse/selection.dart';
import 'package:xterm/terminal/platform.dart';
import 'package:xterm/terminal/terminal_search.dart';
import 'package:xterm/theme/terminal_theme.dart';
import 'package:xterm/util/observable.dart';

/// this interface describes what a Terminal UI needs from a Terminal
abstract class TerminalUiInteraction with Observable {
  /// The theme associated with this Terminal
  TerminalTheme get theme;

  /// the ViewPort scroll offset from the bottom
  int get scrollOffsetFromBottom;

  /// the ViewPort scroll offset from the top
  int get scrollOffsetFromTop;

  /// the total buffer height
  int get bufferHeight;

  /// terminal height (view port)
  int get terminalHeight;

  /// terminal width (view port)
  int get terminalWidth;

  /// the part of the buffer that is not visible (scrollback)
  int get invisibleHeight;

  /// object that describes details about the current selection
  Selection? get selection;

  /// [true] when the cursor shall be shown, otherwise [false]
  bool get showCursor;

  /// returns the visible lines
  List<BufferLine> getVisibleLines();

  /// cursor y coordinate
  int get cursorY;

  /// cursor x coordinate
  int get cursorX;

  /// current line
  BufferLine? get currentLine;

  /// color code for the cursor
  int get cursorColor;

  /// color code for the background
  int get backgroundColor;

  /// flag that indicates if the terminal is dirty (since the last time this
  /// flag has been queried)
  bool get dirty;

  /// platform behavior for this terminal
  PlatformBehavior get platform;

  /// selected text defined by [selection]
  String? get selectedText;

  /// flag that indicates if the Terminal is ready
  bool get isReady;

  /// refreshes the Terminal (notifies listeners and sets it to dirty)
  void refresh();

  /// clears the selection
  void clearSelection();

  /// select the whole buffer
  void selectAll();

  /// notify the Terminal about a mouse tap
  void onMouseTap(Position position);

  /// notify the Terminal about a mouse double tap
  void onMouseDoubleTap(Position position);

  /// notify the Terminal about a pan start
  void onPanStart(Position position);

  /// notify the Terminal about a pan update
  void onPanUpdate(Position position);

  /// sets the scroll offset from bottom (scrolling)
  void setScrollOffsetFromBottom(int offset);

  /// converts the given view line (view port line) index to its position in the
  /// overall buffer
  int convertViewLineToRawLine(int viewLine);

  /// notifies the Terminal about user input
  void raiseOnInput(String input);

  /// writes data to the Terminal
  void write(String text);

  /// paste clipboard content to the Terminal
  void paste(String data);

  /// notifies the Terminal about a resize that happened. The Terminal will
  /// do any resize / reflow logic and notify the backend about the resize
  void resize(
      int newWidth, int newHeight, int newPixelWidth, int newPixelHeight);

  /// notifies the Terminal about key input
  void keyInput(
    TerminalKey key, {
    bool ctrl = false,
    bool alt = false,
    bool shift = false,
    bool mac = false,
    // bool meta,
    String? character,
  });

  /// Future that fires when the backend has exited
  Future<int> get backendExited;

  /// terminates the backend. If already terminated, nothing happens
  void terminateBackend();

  /// flag that indicates if the backend is already terminated
  bool get isTerminated;

  /// returns the current composing string. '' when there is no composing going on
  String get composingString;

  /// update the composing string. This gets called by the input handling
  /// part of the terminal
  void updateComposingString(String value);

  /// returns the list of search hits
  TerminalSearchResult get userSearchResult;

  /// gets the number of search hits
  int get numberOfSearchHits;

  /// gets the current search hit
  int? get currentSearchHit;

  /// sets the current search hit (gets clamped to the valid bounds)
  set currentSearchHit(int? currentSearchHit);

  /// gets the current user search options
  TerminalSearchOptions get userSearchOptions;

  /// sets new user search options. This invalidates the cached search hits and
  /// will re-trigger a new search
  set userSearchOptions(TerminalSearchOptions options);

  /// the search pattern of a currently active search or [null]
  String? get userSearchPattern;

  /// sets the currently active search pattern
  set userSearchPattern(String? pattern);

  /// gets if a user search is active
  bool get isUserSearchActive;

  // sets the user search active state
  set isUserSearchActive(bool isUserSearchActive);
}
