import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:xterm/src/core/buffer/cell_offset.dart';
import 'package:xterm/src/core/buffer/range.dart';
import 'package:xterm/src/core/cursor_type.dart';
import 'package:xterm/src/core/input/keys.dart';
import 'package:xterm/src/core/mouse/mode.dart';
import 'package:xterm/src/terminal.dart';
import 'package:xterm/src/ui/controller.dart';
import 'package:xterm/src/ui/custom_text_edit.dart';
import 'package:xterm/src/ui/gesture/gesture_handler.dart';
import 'package:xterm/src/ui/input_map.dart';
import 'package:xterm/src/ui/keyboard_listener.dart';
import 'package:xterm/src/ui/render.dart';
import 'package:xterm/src/ui/scroll_handler.dart';
import 'package:xterm/src/ui/shortcut/actions.dart';
import 'package:xterm/src/ui/shortcut/shortcuts.dart';
import 'package:xterm/src/ui/terminal_text_style.dart';
import 'package:xterm/src/ui/terminal_theme.dart';
import 'package:xterm/src/ui/themes.dart';

class TerminalView extends StatefulWidget {
  const TerminalView(
    this.terminal, {
    super.key,
    this.controller,
    this.theme = TerminalThemes.defaultTheme,
    this.textStyle = const TerminalStyle(),
    this.textScaler,
    this.padding,
    this.scrollController,
    this.autoResize = true,
    this.backgroundOpacity = 1,
    this.focusNode,
    this.autofocus = false,
    this.onTapUp,
    this.onSecondaryTapDown,
    this.onSecondaryTapUp,
    this.mouseCursor = SystemMouseCursors.text,
    this.keyboardType = TextInputType.emailAddress,
    this.keyboardAppearance = Brightness.dark,
    this.cursorType = TerminalCursorType.block,
    this.cursorBlink = false,
    this.cursorBlinkInterval = const Duration(milliseconds: 530),
    this.alwaysShowCursor = false,
    this.deleteDetection = false,
    this.shortcuts,
    this.onKeyEvent,
    this.readOnly = false,
    this.hardwareKeyboardOnly = false,
    this.simulateScroll = true,
    this.hideScrollBar = true,
    this.viewOffset = Offset.zero,
    this.showToolbar = true,
    this.enableSuggestions = true,
    this.scrollBehavior,
    this.toolbarBuilder,
    this.onCopied,
    this.onSelectAll,
    this.onPaste,
    this.onPasteText,
    this.onCopyFailed,
  });

  /// The underlying terminal that this widget renders.
  final Terminal terminal;

  final TerminalController? controller;

  /// The theme to use for this terminal.
  final TerminalTheme theme;

  /// The style to use for painting characters.
  final TerminalStyle textStyle;

  final TextScaler? textScaler;

  /// Padding around the inner [Scrollable] widget.
  final EdgeInsets? padding;

  /// Scroll controller for the inner [Scrollable] widget.
  final ScrollController? scrollController;

  /// Should this widget automatically notify the underlying terminal when its
  /// size changes. [true] by default.
  final bool autoResize;

  /// Opacity of the terminal background. Set to 0 to make the terminal
  /// background transparent.
  final double backgroundOpacity;

  /// An optional focus node to use as the focus node for this widget.
  final FocusNode? focusNode;

  /// True if this widget will be selected as the initial focus when no other
  /// node in its scope is currently focused.
  final bool autofocus;

  /// Callback for when the user taps on the terminal.
  final void Function(TapUpDetails, CellOffset)? onTapUp;

  /// Function called when the user taps on the terminal with a secondary
  /// button.
  final void Function(TapDownDetails, CellOffset)? onSecondaryTapDown;

  /// Function called when the user stops holding down a secondary button.
  final void Function(TapUpDetails, CellOffset)? onSecondaryTapUp;

  /// The mouse cursor for mouse pointers that are hovering over the terminal.
  /// [SystemMouseCursors.text] by default.
  final MouseCursor mouseCursor;

  /// The type of information for which to optimize the text input control.
  /// [TextInputType.emailAddress] by default.
  final TextInputType keyboardType;

  /// The appearance of the keyboard. [Brightness.dark] by default.
  ///
  /// This setting is only honored on iOS devices.
  final Brightness keyboardAppearance;

  /// The type of cursor to use. [TerminalCursorType.block] by default.
  final TerminalCursorType cursorType;

  /// Whether the cursor should blink. [false] by default to match legacy behavior.
  final bool cursorBlink;

  /// Interval used when [cursorBlink] is enabled.
  final Duration cursorBlinkInterval;

  /// Whether to always show the cursor. This is useful for debugging.
  /// [false] by default.
  final bool alwaysShowCursor;

  /// Workaround to detect delete key for platforms and IMEs that does not
  /// emit hardware delete event. Prefered on mobile platforms. [false] by
  /// default.
  final bool deleteDetection;

  /// Shortcuts for this terminal. This has higher priority than input handler
  /// of the terminal If not provided, [defaultTerminalShortcuts] will be used.
  final Map<ShortcutActivator, Intent>? shortcuts;

  /// Keyboard event handler of the terminal. This has higher priority than
  /// [shortcuts] and input handler of the terminal.
  final FocusOnKeyEventCallback? onKeyEvent;

  /// True if no input should send to the terminal.
  final bool readOnly;

  /// True if only hardware keyboard events should be used as input. This will
  /// also prevent any on-screen keyboard to be shown.
  final bool hardwareKeyboardOnly;

  /// If true, when the terminal is in alternate buffer (for example running
  /// vim, man, etc), if the application does not declare that it can handle
  /// scrolling, the terminal will simulate scrolling by sending up/down arrow
  /// keys to the application. This is standard behavior for most terminal
  /// emulators. True by default.
  final bool simulateScroll;

  final bool hideScrollBar;

  final Offset viewOffset;

  final bool showToolbar;

  /// If this is false, some Chinese Android will open safe keyboard.
  final bool enableSuggestions;

  /// Allows customizing the scroll behavior used by the terminal viewport.
  final ScrollBehavior? scrollBehavior;

  /// Optional builder to customize selection toolbar items shown by the input bridge.
  final CustomTextEditToolbarBuilder? toolbarBuilder;

  /// Callback to show toast after copy operation.
  final void Function()? onCopied;

  /// Callback to select all text in the terminal.
  final void Function()? onSelectAll;

  /// Callback to paste text from clipboard to terminal.
  final void Function()? onPaste;

  /// What the iOS system menu's paste brought in, which iOS gives without
  /// asking the user (a read through [onPaste] asks every time). Defaults to
  /// pasting into the terminal, bracketed when the program asked for that.
  final void Function(String text)? onPasteText;

  /// A copy the clipboard refused: the selection stays, and nothing else says
  /// so unless this does.
  final void Function(Object error, StackTrace stack)? onCopyFailed;

  @override
  State<TerminalView> createState() => TerminalViewState();
}

class TerminalViewState extends State<TerminalView>
    with TickerProviderStateMixin {
  var _prevIsAltBuffer = false;
  var _prevMouseMode = MouseMode.none;

  late FocusNode _focusNode;

  late final ShortcutManager _shortcutManager;

  final _customTextEditKey = GlobalKey<CustomTextEditState>();

  final _scrollableKey = GlobalKey<ScrollableState>();

  final _viewportKey = GlobalKey();

  Timer? _cursorBlinkTimer;
  final _cursorBlinkVisible = ValueNotifier<bool>(true);
  bool _previousBlinkEnabled = false;

  final _composingText = ValueNotifier<String?>(null);

  late TerminalController _controller;

  late ScrollController _scrollController;

  RenderTerminal get renderTerminal =>
      _viewportKey.currentContext!.findRenderObject() as RenderTerminal;

  /// [renderTerminal], or null while the viewport is not mounted or not yet
  /// laid out — which a widget built beside it can see: its build can run
  /// before the viewport's element exists, and in the frame it is replaced.
  RenderTerminal? get laidOutRenderTerminal {
    final render = _viewportKey.currentContext?.findRenderObject();
    return render is RenderTerminal && render.hasSize ? render : null;
  }

  late final textSizeNoti = ValueNotifier(widget.textStyle.fontSize);

  /// Slides the selection highlight from where it was to where it now is.
  ///
  /// A selection is whole cells, so dragging one out moved the highlight a
  /// cell at a time and it stepped rather than followed. Short enough that
  /// the highlight is never far behind the pointer — this is catching the eye
  /// up, not an effect, and a selection that lagged the pointer visibly would
  /// be worse than one that stepped.
  late final AnimationController _selectionAnimation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 70),
  );

  /// The selection the highlight is on its way from. Null when there is
  /// nothing to slide from — a selection that was just made, or just dropped.
  BufferRange? _selectionAnimationFrom;

  BufferRange? _lastSelection;

  void _handleSelectionChange() {
    final selection = _controller.selection;
    final previous = _lastSelection;

    // The controller notifies more than once for a single change, and the
    // repeat carries the same selection. Answering it would stop the tween a
    // moment after starting it, which is the whole animation gone.
    if (selection == previous) {
      return;
    }

    _lastSelection = selection;

    if (selection == null || previous == null) {
      // Nothing to slide from: a selection just made, or just dropped. Left
      // at the far end of the tween, which is where it is drawn from.
      _selectionAnimationFrom = null;
      _selectionAnimation.stop();
      _selectionAnimation.value = 1;
      _applySelectionAnimation();
      return;
    }

    _selectionAnimationFrom = previous;
    _selectionAnimation.forward(from: 0);
    _applySelectionAnimation();
  }

  void _applySelectionAnimation() {
    // Before the first layout there is no render object to tell, and the
    // selection it would be told about is already the one it will first draw.
    if (_viewportKey.currentContext?.findRenderObject() == null) {
      return;
    }

    renderTerminal
      ..selectionFrom = _selectionAnimationFrom
      ..selectionT = _selectionAnimation.value;
  }

  @override
  void initState() {
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChange);
    _controller = widget.controller ?? TerminalController();
    _scrollController = widget.scrollController ?? ScrollController();
    _shortcutManager = ShortcutManager(
      shortcuts: widget.shortcuts ?? defaultTerminalShortcuts,
    );
    widget.terminal.addListener(_handleTerminalChange);
    _controller.addListener(_handleSelectionChange);
    _selectionAnimation.addListener(_applySelectionAnimation);
    _prevIsAltBuffer = widget.terminal.isUsingAltBuffer;
    _prevMouseMode = widget.terminal.mouseMode;
    super.initState();
    _updateCursorBlink(scheduleSetState: false);
  }

  @override
  void didUpdateWidget(TerminalView oldWidget) {
    if (oldWidget.focusNode != widget.focusNode) {
      _focusNode.removeListener(_handleFocusChange);
      if (oldWidget.focusNode == null) {
        _focusNode.dispose();
      }
      _focusNode = widget.focusNode ?? FocusNode();
      _focusNode.addListener(_handleFocusChange);
      _updateCursorBlink(resetVisible: true);
    }
    if (oldWidget.terminal != widget.terminal) {
      oldWidget.terminal.removeListener(_handleTerminalChange);
      widget.terminal.addListener(_handleTerminalChange);
      _prevIsAltBuffer = widget.terminal.isUsingAltBuffer;
      _prevMouseMode = widget.terminal.mouseMode;
      _updateCursorBlink(resetVisible: true);
      // Anchored in the old terminal's buffer, so it means nothing here.
      if (oldWidget.controller == widget.controller) {
        _controller.clearSelection();
      }
    }
    if (oldWidget.controller != widget.controller) {
      // The selection listener moves with the controller: left on the old one
      // it went on answering for it and never heard the new one, and dispose
      // removed it only from the new one.
      _controller.removeListener(_handleSelectionChange);
      if (oldWidget.controller == null) {
        _controller.dispose();
      }
      _controller = widget.controller ?? TerminalController();
      _controller.addListener(_handleSelectionChange);
      // Nothing to slide from: the old controller's selection is not where
      // the new one's came from.
      _lastSelection = _controller.selection;
      _selectionAnimationFrom = null;
      _selectionAnimation.stop();
      _selectionAnimation.value = 1;
      _applySelectionAnimation();
    }
    if (oldWidget.scrollController != widget.scrollController) {
      if (oldWidget.scrollController == null) {
        _scrollController.dispose();
      }
      _scrollController = widget.scrollController ?? ScrollController();
    }
    _shortcutManager.shortcuts = widget.shortcuts ?? defaultTerminalShortcuts;
    if (oldWidget.textStyle.fontSize != widget.textStyle.fontSize) {
      textSizeNoti.value = widget.textStyle.fontSize;
    }
    if (oldWidget.cursorBlink != widget.cursorBlink ||
        oldWidget.cursorBlinkInterval != widget.cursorBlinkInterval ||
        oldWidget.alwaysShowCursor != widget.alwaysShowCursor) {
      _updateCursorBlink(resetVisible: true);
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    stopAutoScroll();
    _selectionAnimation.dispose();
    _controller.removeListener(_handleSelectionChange);
    widget.terminal.removeListener(_handleTerminalChange);
    _focusNode.removeListener(_handleFocusChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    if (widget.controller == null) {
      _controller.dispose();
    }
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    _shortcutManager.dispose();
    textSizeNoti.dispose();
    _cursorBlinkTimer?.cancel();
    _cursorBlinkVisible.dispose();
    _composingText.dispose();
    super.dispose();
  }

  bool get _shouldSuppressScroll {
    if (widget.terminal.isUsingAltBuffer) return true;
    final mode = widget.terminal.mouseMode;
    return mode != MouseMode.none && mode.reportScroll;
  }

  @override
  Widget build(BuildContext context) {
    Widget child = ScrollConfiguration(
      behavior: widget.scrollBehavior ?? const _TerminalScrollBehavior(),
      child: Scrollable(
        key: _scrollableKey,
        controller: _scrollController,
        physics: _shouldSuppressScroll
            ? const NeverScrollableScrollPhysics()
            : const ClampingScrollPhysics(),
        viewportBuilder: (context, offset) {
          return ValueListenableBuilder(
            valueListenable: textSizeNoti,
            builder: (_, textSize, _) {
              return ValueListenableBuilder(
                valueListenable: _cursorBlinkVisible,
                builder: (_, cursorBlinkVisible, _) {
                  return ValueListenableBuilder(
                    valueListenable: _composingText,
                    builder: (_, composingText, _) {
                      return _TerminalView(
                        key: _viewportKey,
                        terminal: widget.terminal,
                        controller: _controller,
                        offset: offset,
                        padding: MediaQuery.of(context).padding,
                        autoResize: widget.autoResize,
                        textStyle: widget.textStyle.copyWith(
                          fontSize: textSize,
                        ),
                        textScaler:
                            widget.textScaler ??
                            MediaQuery.textScalerOf(context),
                        devicePixelRatio: MediaQuery.devicePixelRatioOf(
                          context,
                        ),
                        theme: widget.theme,
                        focusNode: _focusNode,
                        cursorType: widget.cursorType,
                        cursorBlinkEnabled: _cursorBlinkEnabled,
                        cursorBlinkVisible: cursorBlinkVisible,
                        alwaysShowCursor: widget.alwaysShowCursor,
                        onEditableRect: _onEditableRect,
                        composingText: composingText,
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );

    if (!widget.hideScrollBar) {
      child = Scrollbar(controller: _scrollController, child: child);
    }

    child = TerminalScrollGestureHandler(
      terminal: widget.terminal,
      simulateScroll: widget.simulateScroll,
      getCellOffset: (offset) => renderTerminal.getScreenCellOffset(offset),
      getLineHeight: () => renderTerminal.lineHeight,
      child: child,
    );

    if (!widget.hardwareKeyboardOnly) {
      child = CustomTextEdit(
        key: _customTextEditKey,
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        inputType: widget.keyboardType,
        keyboardAppearance: widget.keyboardAppearance,
        deleteDetection: widget.deleteDetection,
        enableSuggestions: widget.enableSuggestions,
        onInsert: _onInsert,
        onDelete: () {
          _scrollToBottom();
          widget.terminal.keyInput(TerminalKey.backspace);
          _updateCursorBlink(resetVisible: true);
        },
        onComposing: _onComposing,
        onAction: (action) {
          _scrollToBottom();
          // Android sends TextInputAction.newline when the user presses the virtual keyboard's enter key.
          if (action == TextInputAction.done ||
              action == TextInputAction.newline) {
            widget.terminal.keyInput(TerminalKey.enter);
            _updateCursorBlink(resetVisible: true);
          }
        },
        onKeyEvent: _handleKeyEvent,
        readOnly: widget.readOnly,
        toolbarBuilder: widget.toolbarBuilder,
        hasSelection: () => _controller.selection != null,
        getSelectedText: () => renderTerminal.selectedText ?? '',
        onCopied: widget.onCopied,
        onSelectAll: widget.onSelectAll ?? () => renderTerminal.selectAll(),
        // The clipboard goes to the terminal, as the paste shortcut sends it,
        // and not into the text being composed, which held it until the
        // next key went out with it.
        onPaste:
            widget.onPaste ??
            (widget.readOnly
                ? null
                : () => pasteClipboard(widget.terminal, _controller)),
        onPasteText: widget.readOnly
            ? null
            : widget.onPasteText ??
                  (text) => pasteText(widget.terminal, _controller, text),
        selectionRect: _selectionRect,
        onCopyFailed: widget.onCopyFailed,
        child: child,
      );
    } else if (!widget.readOnly) {
      // Only listen for key input from a hardware keyboard.
      child = CustomKeyboardListener(
        child: child,
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        onInsert: _onInsert,
        onComposing: _onComposing,
        onKeyEvent: _handleKeyEvent,
      );
    }

    child = TerminalActions(
      terminal: widget.terminal,
      controller: _controller,
      child: child,
    );

    child = TerminalGestureHandler(
      viewOffset: widget.viewOffset,
      showToolbar: widget.showToolbar,
      terminalView: this,
      terminalController: _controller,
      onTapUp: _onTapUp,
      onTapDown: _onTapDown,
      onSecondaryTapDown: widget.onSecondaryTapDown != null
          ? _onSecondaryTapDown
          : null,
      onSecondaryTapUp: widget.onSecondaryTapUp != null
          ? _onSecondaryTapUp
          : null,
      readOnly: widget.readOnly,
      scrollController: _scrollController,
      child: child,
    );

    child = MouseRegion(cursor: widget.mouseCursor, child: child);

    child = Container(
      color: widget.theme.background.withValues(
        alpha: widget.backgroundOpacity,
      ),
      padding: widget.padding,
      child: child,
    );

    // A terminal's grid runs left to right whatever the app's language: in a
    // right-to-left locale the selection handles were mirrored against it.
    return Directionality(textDirection: TextDirection.ltr, child: child);
  }

  void requestKeyboard() {
    _customTextEditKey.currentState?.requestKeyboard();
  }

  void closeKeyboard() {
    _customTextEditKey.currentState?.closeKeyboard();
  }

  void unFocus() {
    _focusNode.unfocus();
    _customTextEditKey.currentState?.closeKeyboard();
  }

  /// The selection's bounds on screen, cut to what is visible: a whole
  /// buffer selected is anchored to the rows in view.
  Rect? _selectionRect() {
    final selection = _controller.selection;
    if (selection == null || selection.isCollapsed) return null;
    final render = renderTerminal;
    if (!render.hasSize) return null;
    final range = selection.normalized;
    final cell = render.cellSize;
    final begin = render.getOffset(range.begin);
    final end = render.getOffset(range.end);
    // Over more than one row it spans them: a row is selected to its end.
    final oneRow = range.begin.y == range.end.y;
    final local = Rect.fromLTRB(
      oneRow ? begin.dx : 0,
      begin.dy,
      oneRow ? end.dx : render.size.width,
      end.dy + cell.height,
    ).intersect(Offset.zero & render.size);
    if (local.width <= 0 || local.height <= 0) return null;
    return MatrixUtils.transformRect(render.getTransformTo(null), local);
  }

  /// Copies the selection, as the menu's Copy does: `onCopied` once the
  /// clipboard has it, `onCopyFailed` when it refused.
  void copySelection() => _customTextEditKey.currentState?.copySelection(
    SelectionChangedCause.keyboard,
  );

  void showSelectionToolbar(Rect globalSelectionRect) {
    _customTextEditKey.currentState?.showToolbar(
      globalSelectionRect: globalSelectionRect,
    );
  }

  void hideSelectionToolbar() {
    _customTextEditKey.currentState?.hideToolbar();
  }

  bool get isSelectionToolbarShown =>
      _customTextEditKey.currentState?.isToolbarShown ?? false;

  void toggleFocus() {
    _customTextEditKey.currentState?.toggleKeyboard();
    if (_focusNode.hasFocus) {
      _focusNode.unfocus();
    } else {
      _focusNode.requestFocus();
    }
  }

  Rect get cursorRect {
    return renderTerminal.cursorOffset & renderTerminal.cellSize;
  }

  Rect get globalCursorRect {
    return renderTerminal.localToGlobal(renderTerminal.cursorOffset) &
        renderTerminal.cellSize;
  }

  bool get _cursorBlinkEnabled {
    return (widget.cursorBlink || widget.terminal.cursorBlinkMode) &&
        _focusNode.hasFocus &&
        !widget.alwaysShowCursor;
  }

  void _handleTerminalChange() {
    var shouldUpdate = false;

    if (_cursorBlinkEnabled != _previousBlinkEnabled) {
      _updateCursorBlink(resetVisible: true);
      shouldUpdate = true;
    }

    final isAltBuffer = widget.terminal.isUsingAltBuffer;
    final mouseMode = widget.terminal.mouseMode;
    if (_prevIsAltBuffer != isAltBuffer || _prevMouseMode != mouseMode) {
      _prevIsAltBuffer = isAltBuffer;
      _prevMouseMode = mouseMode;
      shouldUpdate = true;
    }

    if (shouldUpdate && mounted) {
      setState(() {});
    }
  }

  void _handleFocusChange() {
    widget.terminal.focusInput(_focusNode.hasFocus);
    _updateCursorBlink(resetVisible: true);
  }

  void _updateCursorBlink({
    bool resetVisible = false,
    bool scheduleSetState = true,
  }) {
    final shouldBlink = _cursorBlinkEnabled;
    final blinkChanged = shouldBlink != _previousBlinkEnabled;
    _previousBlinkEnabled = shouldBlink;

    _cursorBlinkTimer?.cancel();

    var shouldNotify = blinkChanged;

    if ((resetVisible || !shouldBlink) && !_cursorBlinkVisible.value) {
      _cursorBlinkVisible.value = true;
      shouldNotify = true;
    }

    if (shouldBlink) {
      _cursorBlinkTimer = Timer.periodic(widget.cursorBlinkInterval, (_) {
        if (!mounted) {
          return;
        }
        _cursorBlinkVisible.value = !_cursorBlinkVisible.value;
      });
    }

    if (shouldNotify && scheduleSetState && mounted) {
      setState(() {});
    }
  }

  void _onTapUp(TapUpDetails details) {
    final offset = renderTerminal.getCellOffset(details.localPosition);
    widget.onTapUp?.call(details, offset);
  }

  void _onTapDown(TapDownDetails details) {
    if (_controller.selection == null) {
      if (!widget.hardwareKeyboardOnly) {
        _customTextEditKey.currentState?.requestKeyboard();
      } else {
        _focusNode.requestFocus();
      }
    }

    _updateCursorBlink(resetVisible: true);
  }

  void _onSecondaryTapDown(TapDownDetails details) {
    final offset = renderTerminal.getCellOffset(details.localPosition);
    widget.onSecondaryTapDown?.call(details, offset);
  }

  void _onSecondaryTapUp(TapUpDetails details) {
    final offset = renderTerminal.getCellOffset(details.localPosition);
    widget.onSecondaryTapUp?.call(details, offset);
  }

  bool get hasInputConnection {
    return _customTextEditKey.currentState?.hasInputConnection == true;
  }

  void _onInsert(String text) {
    final key = charToTerminalKey(text.trim());

    // On mobile platforms there is no guarantee that virtual keyboard will
    // generate hardware key events. So we need first try to send the key
    // as a hardware key event. If it fails, then we send it as a text input.
    final consumed = key == null ? false : widget.terminal.keyInput(key);

    if (!consumed) {
      widget.terminal.textInput(text);
    }

    _scrollToBottom();
    _updateCursorBlink(resetVisible: true);
  }

  void _onComposing(String? text) {
    _composingText.value = text;
    _updateCursorBlink(resetVisible: true);
  }

  KeyEventResult _handleKeyEvent(FocusNode focusNode, KeyEvent event) {
    final resultOverride = widget.onKeyEvent?.call(focusNode, event);
    if (resultOverride != null && resultOverride != KeyEventResult.ignored) {
      return resultOverride;
    }

    // ignore: invalid_use_of_protected_member
    final shortcutResult = _shortcutManager.handleKeypress(
      focusNode.context!,
      event,
    );

    if (shortcutResult != KeyEventResult.ignored) {
      return shortcutResult;
    }

    if (event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }

    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final key = keyToTerminalKey(event.logicalKey);
    if (key == null) {
      return KeyEventResult.ignored;
    }

    final handled = _sendTerminalKey(key) || _sendAltCharacter(event);

    if (!handled) {
      return KeyEventResult.ignored;
    }

    return KeyEventResult.handled;
  }

  /// Alt with a key that types a character the keytab has no entry for, a
  /// period for one: ESC and the character. Left alone it was typed without
  /// the Alt. Not with Control, which AltGr on Windows is.
  bool _sendAltCharacter(KeyEvent event) {
    final keyboard = HardwareKeyboard.instance;
    if (!keyboard.isAltPressed ||
        keyboard.isControlPressed ||
        keyboard.isMetaPressed) {
      return false;
    }
    final character = event.character;
    if (character == null || character.runes.length != 1) return false;
    if (!widget.terminal.charInput(character.runes.single, alt: true)) {
      return false;
    }
    _scrollToBottom();
    _updateCursorBlink(resetVisible: true);
    return true;
  }

  bool _sendTerminalKey(TerminalKey key) {
    final handled = widget.terminal.keyInput(
      key,
      ctrl: HardwareKeyboard.instance.isControlPressed,
      alt: HardwareKeyboard.instance.isAltPressed,
      shift: HardwareKeyboard.instance.isShiftPressed,
    );

    if (handled) {
      _scrollToBottom();
      _updateCursorBlink(resetVisible: true);
    }

    return handled;
  }

  void _onEditableRect(Rect rect, Rect caretRect) {
    _customTextEditKey.currentState?.setEditableRect(rect, caretRect);
  }

  void _scrollToBottom() {
    final position = _scrollableKey.currentState?.position;
    // A position not yet laid out has no extent: `maxScrollExtent` asserts one
    // with `!`, and a key typed in that frame threw (SERVERBOX-14B).
    if (position != null && position.hasContentDimensions) {
      final target = position.maxScrollExtent;
      position
          .animateTo(
            target,
            duration: const Duration(milliseconds: 377),
            curve: Curves.fastEaseInToSlowEaseOut,
          )
          .then((_) {
            // Output during the animation moved the bottom past where it was
            // going. Caught up after the next layout, which is what applies
            // that output to the extent; not when something else (a drag)
            // stopped the animation short.
            if (!mounted) return;
            WidgetsBinding.instance
              ..addPostFrameCallback((_) {
                if (!mounted || !position.hasContentDimensions) return;
                if (position.pixels == target &&
                    position.maxScrollExtent > target) {
                  position.jumpTo(position.maxScrollExtent);
                }
              })
              ..scheduleFrame();
          });
    }
  }

  /// How far from an edge a pointer starts dragging the view, and also the
  /// distance past that point at which it reaches [_autoScrollMaxLines].
  double get _autoScrollBand => renderTerminal.lineHeight * 3;

  /// Lines a second at full deflection. Fast enough to cross a screen while
  /// the eye is still on the pointer, slow enough to stop on a line.
  static const _autoScrollMaxLines = 15.0;

  Ticker? _autoScrollTicker;
  Duration _autoScrollLastTick = Duration.zero;

  /// Logical pixels a second, signed. Zero means the pointer is not in either
  /// band and the ticker has nothing to do.
  double _autoScrollVelocity = 0;

  /// Run after each tick has scrolled, so whatever is following the pointer
  /// can follow the content that moved under it. Without it a selection stops
  /// growing the moment the pointer stops moving, which is the whole case this
  /// exists for.
  VoidCallback? _autoScrollOnTick;

  /// Drives the view from a pointer held near or past an edge.
  ///
  /// Called on every pointer move, but the scrolling itself is on a ticker
  /// rather than on those events: a pointer held still outside the edge sends
  /// no more of them, and stopping there is exactly what a drag past the end
  /// of the buffer must not do.
  void updateAutoScroll(Offset localPointerPosition, {VoidCallback? onTick}) {
    final band = _autoScrollBand;
    final dy = localPointerPosition.dy;

    // Deflection past the inner edge of each band, clamped so that a pointer
    // dragged far outside the widget is not faster than one just outside it.
    final past = dy < band
        ? -(band - dy)
        : dy > renderTerminal.size.height - band
        ? dy - (renderTerminal.size.height - band)
        : 0.0;

    _autoScrollVelocity =
        (past / band).clamp(-1.0, 1.0) *
        _autoScrollMaxLines *
        renderTerminal.lineHeight;
    _autoScrollOnTick = onTick;

    if (_autoScrollVelocity == 0) {
      stopAutoScroll();
      return;
    }

    if (_autoScrollTicker == null) {
      _autoScrollLastTick = Duration.zero;
      _autoScrollTicker = createTicker(_onAutoScrollTick)..start();
    }
  }

  void stopAutoScroll() {
    _autoScrollTicker?.dispose();
    _autoScrollTicker = null;
    _autoScrollVelocity = 0;
    _autoScrollOnTick = null;
  }

  void _onAutoScrollTick(Duration elapsed) {
    final position = _scrollableKey.currentState?.position;
    if (position == null) {
      stopAutoScroll();
      return;
    }

    // The first tick has no interval behind it.
    final dt = _autoScrollLastTick == Duration.zero
        ? Duration.zero
        : elapsed - _autoScrollLastTick;
    _autoScrollLastTick = elapsed;

    final target = (position.pixels +
            _autoScrollVelocity * dt.inMicroseconds / 1e6)
        .clamp(position.minScrollExtent, position.maxScrollExtent);

    // `jumpTo` rather than `animateTo`: the ticker is already the animation,
    // and starting another one per frame is what made this stutter.
    if (target != position.pixels) {
      position.jumpTo(target);
    }

    _autoScrollOnTick?.call();
  }
}

class _TerminalView extends LeafRenderObjectWidget {
  const _TerminalView({
    super.key,
    required this.terminal,
    required this.controller,
    required this.offset,
    required this.padding,
    required this.autoResize,
    required this.textStyle,
    required this.textScaler,
    required this.devicePixelRatio,
    required this.theme,
    required this.focusNode,
    required this.cursorType,
    required this.cursorBlinkEnabled,
    required this.cursorBlinkVisible,
    required this.alwaysShowCursor,
    this.onEditableRect,
    this.composingText,
  });

  final Terminal terminal;

  final TerminalController controller;

  final ViewportOffset offset;

  final EdgeInsets padding;

  final bool autoResize;

  final TerminalStyle textStyle;

  final TextScaler textScaler;

  final double devicePixelRatio;

  final TerminalTheme theme;

  final FocusNode focusNode;

  final TerminalCursorType cursorType;

  final bool cursorBlinkEnabled;

  final bool cursorBlinkVisible;

  final bool alwaysShowCursor;


  final EditableRectCallback? onEditableRect;

  final String? composingText;

  @override
  RenderTerminal createRenderObject(BuildContext context) {
    return RenderTerminal(
      terminal: terminal,
      controller: controller,
      offset: offset,
      padding: padding,
      autoResize: autoResize,
      textStyle: textStyle,
      textScaler: textScaler,
      devicePixelRatio: devicePixelRatio,
      theme: theme,
      focusNode: focusNode,
      cursorType: cursorType,
      cursorBlinkEnabled: cursorBlinkEnabled,
      cursorBlinkVisible: cursorBlinkVisible,
      alwaysShowCursor: alwaysShowCursor,
      onEditableRect: onEditableRect,
      composingText: composingText,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderTerminal renderObject) {
    renderObject
      ..terminal = terminal
      ..controller = controller
      ..offset = offset
      ..padding = padding
      ..autoResize = autoResize
      ..textStyle = textStyle
      ..textScaler = textScaler
      ..devicePixelRatio = devicePixelRatio
      ..theme = theme
      ..focusNode = focusNode
      ..cursorType = cursorType
      ..cursorBlinkEnabled = cursorBlinkEnabled
      ..cursorBlinkVisible = cursorBlinkVisible
      ..alwaysShowCursor = alwaysShowCursor
      ..onEditableRect = onEditableRect
      ..composingText = composingText;
  }
}

class _TerminalScrollBehavior extends ScrollBehavior {
  const _TerminalScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
