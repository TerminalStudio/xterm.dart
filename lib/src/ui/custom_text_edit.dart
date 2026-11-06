import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Builds customized context menu entries for the text selection toolbar.
///
/// The [defaultItems] argument reflects the actions that would normally be
/// shown (copy, paste, select all, etc.). Implementations can reuse or replace
/// them when building the final list of entries to display. The result is
/// shown as it is: an empty list means no toolbar.
typedef CustomTextEditToolbarBuilder =
    List<ContextMenuButtonItem> Function(
      BuildContext context,
      CustomTextEditState state,
      List<ContextMenuButtonItem> defaultItems,
    );

class CustomTextEdit extends StatefulWidget {
  final Widget child;
  final void Function(String) onInsert;
  final void Function() onDelete;
  final void Function(String?) onComposing;
  final void Function(TextInputAction) onAction;
  final KeyEventResult Function(FocusNode, KeyEvent) onKeyEvent;
  final FocusNode focusNode;
  final TextEditingController? controller;
  final void Function(TextSelection selection, SelectionChangedCause? cause)?
  onSelectionChanged;
  final void Function(TextRange composing)? onComposingChanged;
  final bool autofocus;
  final bool readOnly;
  final TextInputType inputType;
  final TextInputAction inputAction;
  final Brightness keyboardAppearance;
  final bool deleteDetection;
  final bool enableSuggestions;

  /// Optional hook for IME-specific private commands.
  ///
  /// When the platform sends a private command via
  /// [TextInputClient.performPrivateCommand], this callback is invoked with the
  /// raw [action] string and decoded [data] map after the built-in handlers
  /// have run.
  final void Function(String action, Map<String, dynamic> data)?
  onPrivateCommand;

  /// Optional builder to customize the full set of selection toolbar items.
  ///
  /// The builder receives the current [CustomTextEditState] alongside
  /// the default toolbar entries and should return the complete list
  /// to be shown to the user.
  final CustomTextEditToolbarBuilder? toolbarBuilder;

  /// Callback to check if there is a selection in the terminal.
  final bool Function()? hasSelection;

  /// Callback to get the selected text from the terminal.
  final String Function()? getSelectedText;

  /// Callback invoked after a copy operation completes.
  final void Function()? onCopied;

  /// Callback to select all text in the terminal.
  final void Function()? onSelectAll;

  /// Callback to paste text from clipboard to terminal.
  final void Function()? onPaste;

  /// Receives what the system menu's paste (iOS) put in, which reaches this
  /// widget as typed input. Without it, that menu reads the clipboard through
  /// [onPaste], and iOS asks the user before every read.
  final void Function(String text)? onPasteText;

  /// Where the selection is now, in global coordinates, for a menu put back
  /// after select all: over what is selected, not where it was asked for.
  final Rect? Function()? selectionRect;

  /// A copy the clipboard refused. Nothing changes on screen otherwise.
  final void Function(Object error, StackTrace stack)? onCopyFailed;

  CustomTextEdit({
    super.key,
    required this.child,
    required this.onInsert,
    required this.onDelete,
    required this.onComposing,
    required this.onAction,
    required this.onKeyEvent,
    required this.focusNode,
    this.controller,
    this.onSelectionChanged,
    this.onComposingChanged,
    this.autofocus = false,
    this.readOnly = false,
    this.inputType = TextInputType.text,
    this.inputAction = TextInputAction.done,
    this.keyboardAppearance = Brightness.light,
    this.deleteDetection = false,
    this.enableSuggestions = true,
    this.onPrivateCommand,
    this.toolbarBuilder,
    this.hasSelection,
    this.getSelectedText,
    this.onCopied,
    this.onSelectAll,
    this.onPaste,
    this.onPasteText,
    this.selectionRect,
    this.onCopyFailed,
  });

  @override
  CustomTextEditState createState() => CustomTextEditState();
}

class CustomTextEditState extends State<CustomTextEdit>
    with TextInputClient, TextSelectionDelegate {
  /// The terminal holding the input connection, the one a platform paste
  /// lands in.
  static CustomTextEditState? _attached;

  /// Whether the platform has told [expectPaste] of a paste. From then on it
  /// is trusted to tell of every one, and an insert while the system menu
  /// offers paste is no longer guessed to be its paste.
  static bool pasteSignalled = false;

  /// The platform is about to insert [text], the clipboard, as typed text into
  /// the attached terminal (iOS: the app's `sendAction` hook).
  static void expectPaste(String text) {
    pasteSignalled = true;
    _attached?._expectPaste(text);
  }

  String? _expectedPaste;
  Timer? _pasteExpiry;

  void _expectPaste(String text) {
    _expectedPaste = text;
    _pasteExpiry?.cancel();
    // The insert follows on the same turn of the platform; one that never
    // comes must not leave the text waiting to be matched.
    _pasteExpiry = Timer(const Duration(seconds: 1), _clearPaste);
  }

  void _clearPaste() {
    _pasteExpiry?.cancel();
    _pasteExpiry = null;
    _expectedPaste = null;
  }

  /// Sends what [typed] holds of an expected paste as that paste, and what
  /// came before it (a composition the paste committed) as typing. False when
  /// it does not end with the paste: some other update, which leaves the paste
  /// still expected.
  bool _takePaste(String typed) {
    final paste = _expectedPaste;
    if (paste == null || paste.isEmpty || !typed.endsWith(paste)) return false;
    _clearPaste();
    final before = typed.substring(0, typed.length - paste.length);
    if (before.isNotEmpty) widget.onInsert(before);
    (widget.onPasteText ?? widget.onInsert)(paste);
    return true;
  }

  TextInputConnection? _connection;
  final ContextMenuController _menuController = ContextMenuController();

  /// The iOS edit menu, used instead of [_menuController] where it is
  /// supported. Created when first shown: creating one takes the platform's
  /// menu events away from any other.
  SystemContextMenuController? _systemMenu;
  bool _systemMenuShown = false;

  /// Whether the system menu on screen offers paste. Its paste goes to the
  /// platform view, which inserts the clipboard as typed text before the menu
  /// is reported gone; an insert while this holds is that text.
  bool _systemMenuOffersPaste = false;

  /// Where to put the system menu back once the platform has put it away:
  /// after select all, which leaves a selection to copy.
  Rect? _systemMenuReshowRect;
  final ClipboardStatusNotifier _clipboardStatus = ClipboardStatusNotifier();
  TextSelectionToolbarAnchors? _toolbarAnchors;

  /// Where a menu was asked for while the clipboard state was still unknown,
  /// so that it can be put up once that is answered. See [showToolbar].
  Rect? _pendingToolbarRect;
  Rect _caretRect = Rect.zero;
  TextEditingController? _controller;
  VoidCallback? _controllerListener;
  DateTime? _skipImeDeleteUntil;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
    _initController();
    _currentEditingState = _getInitialEditingValue();
    _clipboardStatus.addListener(_handleClipboardStatusChanged);
    if (widget.focusNode.hasFocus) {
      // Deferred a frame. Opening the connection reads `View.of(context)`, and
      // an inherited widget must not be looked up during `initState` — the
      // element is not yet attached to one.
      //
      // Reachable whenever this widget is first built already focused: a tab
      // focused before its page was laid out, a session restored on launch, or
      // any rebuild that keeps the focus node. Callers used to avoid it by
      // waiting before moving focus, which hid the fault rather than fixing it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openOrCloseInputConnectionIfNeeded();
      });
    }
  }

  void _initController() {
    _controller = widget.controller;
    if (_controller != null) {
      _controllerListener = () {
        if (_currentEditingState != _controller!.value) {
          final oldValue = _currentEditingState;
          setState(() {
            _currentEditingState = _controller!.value;
          });
          if (widget.onSelectionChanged != null &&
              oldValue.selection != _currentEditingState.selection) {
            widget.onSelectionChanged!(_currentEditingState.selection, null);
          }
          if (widget.onComposingChanged != null &&
              oldValue.composing != _currentEditingState.composing) {
            widget.onComposingChanged!(_currentEditingState.composing);
          }
        }
      };
      _controller!.addListener(_controllerListener!);
    }
  }

  void _disposeController() {
    if (_controller != null && _controllerListener != null) {
      _controller!.removeListener(_controllerListener!);
    }
    _controller = null;
    _controllerListener = null;
  }

  @override
  void didUpdateWidget(CustomTextEdit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _disposeController();
      _initController();
      if (_controller != null) {
        setState(() {
          _currentEditingState = _controller!.value;
        });
      }
    }

    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
      // If focus changed and the new node has focus, ensure connection is open.
      if (widget.focusNode.hasFocus) {
        _openOrCloseInputConnectionIfNeeded();
      } else {
        // If new node does not have focus, ensure connection is closed.
        _closeInputConnectionIfNeeded();
      }
    }

    // If relevant properties change, and we have an active connection,
    // we might need to re-create the connection with the new configuration.
    if (widget.readOnly != oldWidget.readOnly ||
        widget.inputType != oldWidget.inputType ||
        widget.inputAction != oldWidget.inputAction ||
        widget.keyboardAppearance != oldWidget.keyboardAppearance ||
        widget.enableSuggestions != oldWidget.enableSuggestions) {
      if (hasInputConnection) {
        _closeInputConnectionIfNeeded();
        _openInputConnection(); // This will use the new widget properties
      }
    } else if (!_shouldCreateInputConnection) {
      // If we shouldn't have a connection (e.g., became readOnly), close it.
      _closeInputConnectionIfNeeded();
    } else {
      // If we should have a connection, and previously were readOnly but now not,
      // and have focus, open it.
      if (oldWidget.readOnly && !widget.readOnly && widget.focusNode.hasFocus) {
        _openInputConnection();
      }
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    _disposeController();
    _closeInputConnectionIfNeeded();
    _menuController.remove();
    _systemMenu?.dispose();
    _clipboardStatus.removeListener(_handleClipboardStatusChanged);
    _clipboardStatus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // No shortcuts of its own: the view's, which the host can replace, reach
    // these actions through [onKeyEvent], and a second set here took keys
    // the host had left out of its map.
    return Actions(
        actions: <Type, Action<Intent>>{
          CopySelectionTextIntent: CallbackAction<CopySelectionTextIntent>(
            onInvoke: (intent) {
              copySelection(SelectionChangedCause.keyboard);
              return null;
            },
          ),
          PasteTextIntent: CallbackAction<PasteTextIntent>(
            onInvoke: (intent) => pasteText(intent.cause),
          ),
          SelectAllTextIntent: CallbackAction<SelectAllTextIntent>(
            onInvoke: (intent) => selectAll(intent.cause),
          ),
        },
      child: Focus(
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        onKeyEvent: _onKeyEvent,
        child: widget.child,
      ),
    );
  }

  bool get hasInputConnection => _connection != null && _connection!.attached;

  void requestKeyboard() {
    if (widget.focusNode.hasFocus) {
      _openInputConnection();
    } else {
      widget.focusNode.requestFocus();
    }
  }

  void closeKeyboard() {
    _closeInputConnectionIfNeeded();
  }

  void toggleKeyboard() {
    if (hasInputConnection) {
      closeKeyboard();
    } else {
      requestKeyboard();
    }
  }

  void _showCaretOnScreen() {
    if (_caretRect == Rect.zero) return;
    // After the frame, not now: the input method can call in mid-layout, and
    // `ensureVisible` walks up through ancestors that may not be laid out yet
    // — a list item the host is still building threw (SERVERBOX-11T).
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox == null || !renderBox.attached || !renderBox.hasSize) {
        return;
      }
      final scrollableState = Scrollable.maybeOf(context);
      if (scrollableState == null) return;
      scrollableState.position.ensureVisible(
        renderBox,
        alignment: 0.5,
        duration: const Duration(milliseconds: 150),
        curve: Curves.ease,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
    });
  }

  @override
  void bringIntoView(TextPosition position) {
    _showCaretOnScreen();
  }

  void setEditingState(TextEditingValue value) {
    if (_currentEditingState == value) {
      return;
    }
    final oldValue = _currentEditingState;
    _currentEditingState = value;
    if (widget.controller != null && widget.controller!.value != value) {
      widget.controller!.value = value;
    }
    if (widget.onSelectionChanged != null &&
        oldValue.selection != value.selection) {
      widget.onSelectionChanged!(value.selection, null);
    }
    if (widget.onComposingChanged != null &&
        oldValue.composing != value.composing) {
      widget.onComposingChanged!(value.composing);
    }
    _connection?.setEditingState(value);
    _showCaretOnScreen();
    setState(() {});
  }

  void setEditableRect(Rect rect, Rect caretRect) {
    _caretRect = caretRect;

    if (!hasInputConnection) {
      return;
    }

    // The transform should be based on the editable area's position relative to the screen.
    // If 'rect' is already in global coordinates, translation might be (0,0,0).
    // If 'rect' is local to some parent, its top-left needs to be translated.
    // For simplicity, assuming 'rect' is the global bounds for now.
    // EditableText uses renderEditable.getTransformTo(null)
    _connection?.setEditableSizeAndTransform(
      rect.size,
      Matrix4.translationValues(rect.left, rect.top, 0),
    );
    _connection?.setCaretRect(caretRect);
  }

  void _onFocusChange() {
    _openOrCloseInputConnectionIfNeeded();
    if (!widget.focusNode.hasFocus) hideToolbar();
  }

  KeyEventResult _onKeyEvent(FocusNode focusNode, KeyEvent event) {
    // Handle both KeyDownEvent and KeyRepeatEvent for key repeat functionality
    // Only process when not composing text
    if ((event is KeyDownEvent || event is KeyRepeatEvent) &&
        _currentEditingState.composing.isCollapsed) {
      return widget.onKeyEvent(focusNode, event);
    }
    // Let other handlers process the event if composing or not a key down/repeat event.
    return KeyEventResult.skipRemainingHandlers;
  }

  void _openOrCloseInputConnectionIfNeeded() {
    if (!mounted) return;
    if (widget.focusNode.hasFocus && _shouldCreateInputConnection) {
      _openInputConnection();
    } else {
      _closeInputConnectionIfNeeded();
    }
  }

  bool get _shouldCreateInputConnection =>
      !widget.readOnly && (kIsWeb || widget.focusNode.hasFocus);

  void _openInputConnection() {
    if (!_shouldCreateInputConnection || !mounted) {
      return;
    }

    if (!widget.focusNode.hasFocus) {
      return;
    }
    if (hasInputConnection) {
      _connection!.show();
      _connection!.setEditingState(_currentEditingState);
      return;
    }
    final config = TextInputConfiguration(
      viewId: View.of(context).viewId,
      inputType: widget.inputType,
      inputAction: widget.inputAction,
      keyboardAppearance: widget.keyboardAppearance,
      autocorrect: false,
      enableSuggestions: widget.enableSuggestions,
      enableIMEPersonalizedLearning: false,
      textCapitalization: TextCapitalization.none,
      readOnly: widget.readOnly,
    );
    _connection = TextInput.attach(this, config);
    if (!mounted) {
      _connection?.close();
      _connection = null;
      return;
    }
    _attached = this;
    _connection!.show();
    _connection!.setEditingState(_currentEditingState);
  }

  void _closeInputConnectionIfNeeded() {
    // The system menu belongs to the connection's platform view.
    if (_systemMenuShown) hideToolbar();
    if (hasInputConnection) {
      _connection!.close();
      _connection = null;
    }
    _detach();
  }

  void _detach() {
    if (_attached == this) _attached = null;
    _clearPaste();
  }

  TextEditingValue _getInitialEditingValue() {
    if (widget.controller != null) {
      return widget.controller!.value;
    }
    return _initEditingState;
  }

  TextEditingValue get _initEditingState => widget.deleteDetection
      ? const TextEditingValue(
          text: '  ', // Two spaces for backspace detection
          selection: TextSelection.collapsed(offset: 2),
        )
      : TextEditingValue.empty;

  // Ensure _currentEditingState is initialized before _openInputConnection might use it.
  late var _currentEditingState = TextEditingValue.empty;

  @override
  TextEditingValue? get currentTextEditingValue {
    return _currentEditingState;
  }

  @override
  AutofillScope? get currentAutofillScope {
    return null; // Autofill not typically used in terminals
  }

  @override
  void updateEditingValue(TextEditingValue value) {
    if (_currentEditingState == value) {
      return;
    }
    final TextEditingValue oldValue = _currentEditingState;
    _currentEditingState = value;
    if (widget.controller != null && widget.controller!.value != value) {
      widget.controller!.value = value;
    }
    // selection/composing
    if (widget.onSelectionChanged != null &&
        oldValue.selection != value.selection) {
      widget.onSelectionChanged!(value.selection, null);
    }
    if (widget.onComposingChanged != null &&
        oldValue.composing != value.composing) {
      widget.onComposingChanged!(value.composing);
    }

    // Before the composing branch: a paste over marked text ends it.
    if (_expectedPaste != null &&
        _currentEditingState.composing.isCollapsed &&
        _takePaste(_typed(_currentEditingState.text))) {
      if (!oldValue.composing.isCollapsed) widget.onComposing(null);
      _currentEditingState = _initEditingState.copyWith();
      _connection?.setEditingState(_currentEditingState);
      _showCaretOnScreen();
      return;
    }

    if (!_currentEditingState.composing.isCollapsed) {
      final String composingText = _currentEditingState.composing.textInside(
        _currentEditingState.text,
      );
      widget.onComposing(composingText);
      return;
    }

    final bool wasComposing = !oldValue.composing.isCollapsed;
    // If we were composing and now we are not, notify with null.
    if (wasComposing) {
      widget.onComposing(null);
    }

    final String previousText = oldValue.text;
    final String currentText = _currentEditingState.text;
    final int initTextLength = _initEditingState.text.length;

    final bool textChanged = widget.deleteDetection
        ? _processDeleteDetectionInput(
            previousText,
            currentText,
            initTextLength,
          )
        : _processStandardInput(
            previousText,
            currentText,
            initTextLength,
            wasComposing,
          );

    // Reset editing state to the initial state if composing is done
    // and text was actually processed (either by insert/delete or composing finished).
    // This is crucial for the IME to correctly handle subsequent input.
    if (_currentEditingState.composing.isCollapsed &&
        (_currentEditingState.text != _initEditingState.text || textChanged)) {
      _currentEditingState = _initEditingState.copyWith();
      _connection?.setEditingState(_currentEditingState);
    }
    _showCaretOnScreen();
  }

  /// What a finished (not composing) update typed.
  ///
  /// Nothing in the buffer past the placeholder has reached the terminal: a
  /// composition is only previewed, and the buffer is reset to the placeholder
  /// after every commit. So whatever the IME left of the placeholder is all
  /// that is not input, wherever it wrote — after it, over it, in place of a
  /// composition, longer or shorter than what it replaced. Not an offset into
  /// the previous text, which assumed the IME only ever appends.
  String _typed(String currentText) {
    final initialText = _initEditingState.text;
    var kept = 0;
    while (kept < initialText.length &&
        kept < currentText.length &&
        currentText.codeUnitAt(kept) == initialText.codeUnitAt(kept)) {
      kept++;
    }
    return currentText.substring(kept);
  }

  bool _processDeleteDetectionInput(
    String previousText,
    String currentText,
    int initTextLength,
  ) {
    final typed = _typed(currentText);
    if (typed.isNotEmpty) {
      return _insertTextDelta(typed);
    }
    // Only placeholder left, and less of it: a backspace.
    if (currentText.length < initTextLength &&
        previousText == _initEditingState.text &&
        !_consumeImeDeleteSuppression()) {
      widget.onDelete();
      return true;
    }
    return false;
  }

  bool _processStandardInput(
    String previousText,
    String currentText,
    int initTextLength,
    bool wasComposing,
  ) {
    final typed = _typed(currentText);
    if (typed.isNotEmpty) {
      return _insertTextDelta(typed);
    }
    // A composition given up leaves less text than it had, which is not a
    // delete: none of it was sent.
    if (!wasComposing &&
        currentText.length < previousText.length &&
        !_consumeImeDeleteSuppression()) {
      widget.onDelete();
      return true;
    }
    return false;
  }

  bool _insertTextDelta(String textDelta) {
    if (textDelta.isEmpty) {
      return false;
    }
    final onPasteText = widget.onPasteText;
    if (!pasteSignalled &&
        _systemMenuShown &&
        _systemMenuOffersPaste &&
        onPasteText != null) {
      _systemMenuOffersPaste = false;
      onPasteText(textDelta);
      return true;
    }
    widget.onInsert(textDelta);
    return true;
  }

  @override
  void performAction(TextInputAction action) {
    widget.onAction(action);
  }

  @override
  void insertContent(KeyboardInsertedContent content) {
    // Text only. A keyboard inserts stickers and GIFs this way too, whose
    // bytes are an image a terminal cannot show and not UTF-8 at all: decoding
    // them threw (SERVERBOX-146).
    final data = content.data;
    if (data == null || !content.mimeType.startsWith('text/')) return;
    widget.onInsert(utf8.decode(data, allowMalformed: true));
  }

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {
    // Handle floating cursor updates if supported
  }

  @override
  void showAutocorrectionPromptRect(int start, int end) {
    // Handle autocorrection prompt if supported
  }

  @override
  void connectionClosed() {
    // Called by the system when the connection is closed.
    // We should not call _connection.close() here as it's already closed.
    // Setting _connection to null indicates that we no longer have a connection.
    if (_connection != null) {
      _connection = null;
    }
    _detach();
    _resetSystemMenu();
  }

  @override
  void didChangeInputControl(
    TextInputControl? oldControl,
    TextInputControl? newControl,
  ) {
    // Handle input control changes if necessary
  }

  @override
  void insertTextPlaceholder(Size size) {
    // Handle text placeholder insertion if necessary
  }

  @override
  void removeTextPlaceholder() {
    // Handle text placeholder removal if necessary
  }

  @override
  void performSelector(String selectorName) {
    // Handle platform-specific selectors if necessary
  }

  @override
  TextEditingValue get textEditingValue => _currentEditingState;

  set textEditingValue(TextEditingValue value) {
    if (_currentEditingState == value) {
      return;
    }
    final oldValue = _currentEditingState;
    _currentEditingState = value;
    if (widget.controller != null && widget.controller!.value != value) {
      widget.controller!.value = value;
    }
    // selection/composing
    if (widget.onSelectionChanged != null &&
        oldValue.selection != value.selection) {
      widget.onSelectionChanged!(value.selection, null);
    }
    if (widget.onComposingChanged != null &&
        oldValue.composing != value.composing) {
      widget.onComposingChanged!(value.composing);
    }
    _connection?.setEditingState(_currentEditingState);
    setState(() {});
  }

  @override
  void hideToolbar([bool hideHandles = true]) {
    if (_menuController.isShown) {
      _menuController.remove();
    }
    if (_systemMenuShown) {
      _resetSystemMenu();
      unawaited(_systemMenu?.hide());
    }
    _toolbarAnchors = null;
    // Or a menu dismissed while the clipboard was still being asked about
    // would come back on its own when the answer landed.
    _pendingToolbarRect = null;
    // If text handles are being managed by this widget, hide them too.
    // EditableText manages its own handles.
  }

  bool get isToolbarShown => _menuController.isShown || _systemMenuShown;

  @override
  void showToolbar({Rect? globalSelectionRect}) {
    if (!mounted) {
      return;
    }

    final Rect? anchorRect =
        globalSelectionRect ?? (_caretRect == Rect.zero ? null : _caretRect);

    if (anchorRect == null) {
      return;
    }

    // The platform's own menu where there is one: its paste is the user's, so
    // iOS lets it read the clipboard without asking. It is shown by the
    // platform view of the input connection, so not while there is none
    // (the keyboard put away).
    if (hasInputConnection && SystemContextMenu.isSupported(context)) {
      _showSystemMenu(anchorRect);
      return;
    }

    _clipboardStatus.update();

    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;

    final spaceAbove = anchorRect.top;
    final spaceBelow = screenSize.height - anchorRect.bottom - mediaQuery.viewInsets.bottom;

    final Offset primaryAnchor;
    final Offset secondaryAnchor;

    const minSpace = 48.0;
    if (spaceAbove >= minSpace) {
      primaryAnchor = anchorRect.topCenter;
      secondaryAnchor = anchorRect.bottomCenter;
    } else if (spaceBelow >= minSpace) {
      primaryAnchor = anchorRect.bottomCenter;
      secondaryAnchor = anchorRect.topCenter;
    } else {
      if (spaceAbove >= spaceBelow) {
        primaryAnchor = anchorRect.topCenter;
        secondaryAnchor = anchorRect.bottomCenter;
      } else {
        primaryAnchor = anchorRect.bottomCenter;
        secondaryAnchor = anchorRect.topCenter;
      }
    }

    _toolbarAnchors = TextSelectionToolbarAnchors(
      primaryAnchor: primaryAnchor,
      secondaryAnchor: secondaryAnchor,
    );

    if (_menuController.isShown) {
      _menuController.markNeedsBuild();
      return;
    }

    final List<ContextMenuButtonItem> initialItems =
        _buildContextMenuButtonItems();
    if (initialItems.isEmpty) {
      _toolbarAnchors = null;

      // Flutter builds no items at all — not even copy — while the clipboard
      // state is unknown, since whether paste belongs in the menu depends on
      // it. `_clipboardStatus.update()` above answers on a later frame, and
      // nothing asked for this menu a second time, so a request that arrived
      // before the first answer was dropped and no menu appeared.
      //
      // How wide that window is depends on how fast the platform answers, and
      // it starts closing as soon as the widget is built, so this is a race
      // rather than a certainty. It is also reachable a second way, and that
      // one is not a race: an answer that fails leaves the status unknown,
      // and every menu until one succeeds was dropped for good.
      //
      // Remembered here and put up in [_handleClipboardStatusChanged] when
      // an answer arrives.
      _pendingToolbarRect =
          _clipboardStatus.value == ClipboardStatus.unknown ? anchorRect : null;
      return;
    }

    _pendingToolbarRect = null;

    _menuController.show(
      context: context,
      contextMenuBuilder: (BuildContext context) {
        final anchors = _toolbarAnchors;
        final items = _buildContextMenuButtonItems();
        if (anchors == null || items.isEmpty) {
          return const SizedBox.shrink();
        }
        return _buildMaterialToolbar(context, anchors, items);
      },
      debugRequiredFor: widget,
    );
  }

  void _showSystemMenu(Rect anchorRect) {
    // Paste is offered whatever the clipboard holds: the platform leaves it
    // out when there is no text, and asking first is a read iOS reports.
    final items = _buildContextMenuButtonItems(
      clipboardStatus: ClipboardStatus.pasteable,
    );
    if (items.isEmpty) {
      hideToolbar();
      return;
    }
    final l10n = MaterialLocalizations.of(context);
    var offersPaste = false;
    final data = <IOSSystemContextMenuItemData>[];
    for (final item in items) {
      final onPressed = item.onPressed;
      if (onPressed == null) continue;
      // Copy and select all stay this widget's: the platform's would act on
      // the input connection's placeholder text, not the terminal.
      // Only this widget's own paste: one a toolbar builder put in its place
      // is the host's to run.
      if (onPressed == _pasteFromToolbar && widget.onPasteText != null) {
        offersPaste = true;
        data.add(const IOSSystemContextMenuItemDataPaste());
      } else {
        data.add(
          IOSSystemContextMenuItemDataCustom(
            title: _buttonLabel(l10n, item),
            onPressed: () {
              // The platform is putting the menu away already; hiding it
              // again from the action would leave its dismissal no one to
              // reach.
              _resetSystemMenu();
              if (item.type == ContextMenuButtonType.selectAll) {
                _systemMenuReshowRect = anchorRect;
              }
              onPressed();
            },
          ),
        );
      }
    }
    if (data.isEmpty) {
      hideToolbar();
      return;
    }
    _pendingToolbarRect = null;
    if (_menuController.isShown) _menuController.remove();
    final menu = _systemMenu ??= SystemContextMenuController(
      onSystemHide: _onSystemMenuHidden,
    );
    _systemMenuShown = true;
    _systemMenuOffersPaste = offersPaste;
    unawaited(menu.showWithItems(anchorRect, data));
  }

  void _onSystemMenuHidden() {
    _systemMenuShown = false;
    _systemMenuOffersPaste = false;
    final reshow = _systemMenuReshowRect;
    _systemMenuReshowRect = null;
    if (reshow == null) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.focusNode.hasFocus) {
        showToolbar(
          globalSelectionRect: widget.selectionRect?.call() ?? reshow,
        );
      }
    });
  }

  void _resetSystemMenu() {
    _systemMenuShown = false;
    _systemMenuOffersPaste = false;
    _systemMenuReshowRect = null;
  }

  /// The selection toolbar, in Material on every platform.
  ///
  /// [AdaptiveTextSelectionToolbar] would give a Cupertino one on iOS and
  /// macOS and a desktop one on Linux and Windows, so the same terminal came
  /// up looking like three different things. Building it here fixes the
  /// chrome, the buttons and the labels together — going through the adaptive
  /// widget for any of the three would put the platform back into that part.
  Widget _buildMaterialToolbar(
    BuildContext context,
    TextSelectionToolbarAnchors anchors,
    List<ContextMenuButtonItem> items,
  ) {
    return TextSelectionToolbar(
      anchorAbove: anchors.primaryAnchor,
      anchorBelow: anchors.secondaryAnchor ?? anchors.primaryAnchor,
      children: <Widget>[
        for (var i = 0; i < items.length; i++)
          TextSelectionToolbarTextButton(
            padding: TextSelectionToolbarTextButton.getPadding(i, items.length),
            onPressed: items[i].onPressed,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              _buttonLabel(MaterialLocalizations.of(context), items[i]),
            ),
          ),
      ],
    );
  }

  /// The Material label for [item].
  ///
  /// Switched over exhaustively rather than defaulted, so that a button type
  /// added to Flutter is a compile error here instead of an empty button.
  String _buttonLabel(MaterialLocalizations l10n, ContextMenuButtonItem item) {
    final label = item.label;
    if (label != null) {
      return label;
    }

    return switch (item.type) {
      ContextMenuButtonType.cut => l10n.cutButtonLabel,
      ContextMenuButtonType.copy => l10n.copyButtonLabel,
      ContextMenuButtonType.paste => l10n.pasteButtonLabel,
      ContextMenuButtonType.selectAll => l10n.selectAllButtonLabel,
      ContextMenuButtonType.delete => l10n.deleteButtonTooltip.toUpperCase(),
      ContextMenuButtonType.lookUp => l10n.lookUpButtonLabel,
      ContextMenuButtonType.searchWeb => l10n.searchWebButtonLabel,
      ContextMenuButtonType.share => l10n.shareButtonLabel,
      ContextMenuButtonType.liveTextInput => l10n.scanTextButtonLabel,
      ContextMenuButtonType.custom => '',
    };
  }

  void _handleClipboardStatusChanged() {
    if (!mounted) {
      return;
    }
    if (_menuController.isShown) {
      _menuController.markNeedsBuild();
    }

    // A menu that was asked for before the clipboard answered. Now it has,
    // there are items to put in one.
    final pending = _pendingToolbarRect;
    if (pending != null &&
        !_menuController.isShown &&
        _clipboardStatus.value != ClipboardStatus.unknown) {
      _pendingToolbarRect = null;
      showToolbar(globalSelectionRect: pending);
    }

    setState(() {});
  }

  List<ContextMenuButtonItem> _buildContextMenuButtonItems({
    ClipboardStatus? clipboardStatus,
  }) {
    final defaultItems = EditableText.getEditableButtonItems(
      clipboardStatus: clipboardStatus ?? _clipboardStatus.value,
      onCopy: copyEnabled
          ? () => copySelection(SelectionChangedCause.toolbar)
          : null,
      onCut: null,
      onPaste: pasteEnabled ? _pasteFromToolbar : null,
      onSelectAll: selectAllEnabled
          ? () => selectAll(SelectionChangedCause.toolbar)
          : null,
      onLookUp: null,
      onSearchWeb: null,
      onShare: null,
      onLiveTextInput: null,
    );
    if (widget.toolbarBuilder == null) {
      return defaultItems;
    }
    // The complete list, as documented: empty is a builder asking for no
    // menu, not for the defaults back.
    return widget.toolbarBuilder!(
      context,
      this,
      List<ContextMenuButtonItem>.unmodifiable(defaultItems),
    );
  }

  @override
  bool get copyEnabled {
    if (widget.hasSelection != null) {
      return widget.hasSelection!();
    }
    return !_currentEditingState.selection.isCollapsed;
  }

  @override
  bool get pasteEnabled => widget.onPaste != null;

  @override
  bool get cutEnabled => false;

  @override
  bool get selectAllEnabled =>
      widget.onSelectAll != null ||
      (_currentEditingState.text.isNotEmpty &&
          (_currentEditingState.selection.baseOffset != 0 ||
              _currentEditingState.selection.extentOffset !=
                  _currentEditingState.text.length));

  @override
  void copySelection(SelectionChangedCause cause) {
    if (!copyEnabled) {
      return;
    }

    String selectedText;
    if (widget.getSelectedText != null) {
      selectedText = widget.getSelectedText!();
    } else {
      selectedText = _currentEditingState.selection.textInside(
        _currentEditingState.text,
      );
    }

    if (selectedText.isEmpty) {
      return;
    }

    // The clipboard can refuse — on Windows another program may hold it open —
    // and nothing awaits this to hear about it (SERVERBOX-1N7). Not copied is
    // the outcome either way, so it is not reported as copied.
    // Nor is a copy that lands after this edit is gone anyone's to report.
    Clipboard.setData(ClipboardData(text: selectedText)).then(
      (_) {
        if (mounted) widget.onCopied?.call();
      },
      onError: (Object e, StackTrace s) {
        if (mounted) widget.onCopyFailed?.call(e, s);
      },
    );

    if (cause == SelectionChangedCause.toolbar) {
      hideToolbar();
    }
  }

  void _pasteFromToolbar() =>
      unawaited(pasteText(SelectionChangedCause.toolbar));

  @override
  Future<void> pasteText(SelectionChangedCause cause) async {
    if (!pasteEnabled) {
      return;
    }

    // Whatever the clipboard turns out to hold. It was put away only after a
    // paste that worked, so an empty or refused one left the menu up.
    if (cause == SelectionChangedCause.toolbar) {
      hideToolbar();
    }

    widget.onPaste?.call();
  }

  @override
  void selectAll(SelectionChangedCause cause) {
    if (widget.onSelectAll != null) {
      widget.onSelectAll!();
      // A keyboard select-all has no menu up to move, and asking one that is
      // not shown asserts. Moved rather than rebuilt: it was over the old
      // selection.
      if (_menuController.isShown) {
        final rect = widget.selectionRect?.call();
        if (rect != null) {
          showToolbar(globalSelectionRect: rect);
        } else {
          _menuController.markNeedsBuild();
        }
      }
      setState(() {});
    } else if (!widget.readOnly && _currentEditingState.text.isNotEmpty) {
      textEditingValue = _currentEditingState.copyWith(
        selection: TextSelection(
          baseOffset: 0,
          extentOffset: _currentEditingState.text.length,
        ),
      );
      _showCaretOnScreen();
    }
  }

  @override
  void cutSelection(SelectionChangedCause cause) {
  }

  @override
  void userUpdateTextEditingValue(
    TextEditingValue value,
    SelectionChangedCause cause,
  ) {
    if (_currentEditingState == value) return;
    final oldValue = _currentEditingState;
    _currentEditingState = value;
    if (widget.controller != null && widget.controller!.value != value) {
      widget.controller!.value = value;
    }
    if (widget.onSelectionChanged != null &&
        oldValue.selection != value.selection) {
      widget.onSelectionChanged!(value.selection, cause);
    }
    if (widget.onComposingChanged != null &&
        oldValue.composing != value.composing) {
      widget.onComposingChanged!(value.composing);
    }
    _connection?.setEditingState(_currentEditingState);
    _showCaretOnScreen();
    setState(() {});
  }

  // Helper to get RenderEditable, similar to EditableTextState.renderEditable
  // This is a common pattern but might not fit all CustomTextEdit use cases
  // if the text rendering is handled differently.
  RenderEditable? get renderEditable {
    // Attempt to find a RenderEditable in the widget tree.
    // This is a common pattern but might not fit all CustomTextEdit use cases
    // if the text rendering is handled differently.
    RenderObject? object = context.findRenderObject();
    while (object != null) {
      if (object is RenderEditable) {
        return object;
      }
      // Iterate up or down depending on structure. For now, just checking current.
      // A more robust way might be to have the child widget provide this.
      break; // Simplified: only checks the direct RenderObject.
    }
    return null;
  }

  // Helper for toolbar anchor calculation, similar to EditableTextState
  Offset globalToLocal(Offset global) {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    return box?.globalToLocal(global) ?? global;
  }

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {
    final handled = _handlePrivateCommand(action, data);
    if (!handled) {
      final selectionHandled = _applySelectionFromPrivateCommand(data);
      if (!selectionHandled) {
        final text = _extractTextFromPrivateCommand(data);
        if (text != null && text.isNotEmpty && !widget.readOnly) {
          widget.onInsert(text);
        }
      }
    }
    widget.onPrivateCommand?.call(action, data);
  }

  bool _handlePrivateCommand(String action, Map<String, dynamic> data) {
    final normalized = action.toLowerCase();

    if (normalized.contains('select') && normalized.contains('all')) {
      if (selectAllEnabled) {
        selectAll(SelectionChangedCause.toolbar);
      }
      return true;
    }

    if (normalized.contains('cut')) {
      if (cutEnabled) {
        cutSelection(SelectionChangedCause.toolbar);
      }
      return true;
    }

    if (normalized.contains('copy')) {
      if (copyEnabled) {
        copySelection(SelectionChangedCause.toolbar);
      }
      return true;
    }

    if (normalized.contains('paste')) {
      if (pasteEnabled) {
        unawaited(pasteText(SelectionChangedCause.toolbar));
      }
      return true;
    }

    if (normalized.contains('delete')) {
      if (_handleImeDeleteCommand(normalized, data)) {
        return true;
      }
    }

    return false;
  }

  bool _handleImeDeleteCommand(
    String normalizedAction,
    Map<String, dynamic> data,
  ) {
    if (widget.readOnly) {
      // Consume the command so the IME does not try to delete cached text.
      return true;
    }

    final beforeLength = _extractImeDeleteLength(
      data,
      _kImeDeleteBeforeLengthKeys,
    );
    final afterLength = _extractImeDeleteLength(
      data,
      _kImeDeleteAfterLengthKeys,
    );

    // Record a suppression window so that a follow-up update from the IME does
    // not trigger an additional delete.
    _skipImeDeleteUntil = DateTime.now().add(_kImeDeleteSuppressionWindow);

    final bool handleAsBackspace = beforeLength > 0 || afterLength == 0;

    if (handleAsBackspace) {
      _emitImeBackspace();
      return true;
    }

    if (afterLength > 0) {
      // Forward delete is not supported by the embedded terminal. Fallback to
      // a backspace to avoid dropping the entire line.
      _emitImeBackspace();
      return true;
    }

    return false;
  }

  void _emitImeBackspace() {
    widget.onDelete();

    final resetState = _initEditingState.copyWith();
    _currentEditingState = resetState;
    _connection?.setEditingState(resetState);
    _showCaretOnScreen();
  }

  bool _consumeImeDeleteSuppression() {
    final deadline = _skipImeDeleteUntil;
    if (deadline == null) {
      return false;
    }

    _skipImeDeleteUntil = null;
    return DateTime.now().isBefore(deadline);
  }

  int _extractImeDeleteLength(
    Map<String, dynamic> data,
    List<String> candidateKeys,
  ) {
    for (final key in candidateKeys) {
      final length = _coerceToInt(data[key]);
      if (length != null && length > 0) {
        return length;
      }
    }
    return 0;
  }

  static const _kImeDeleteBeforeLengthKeys = <String>[
    'beforeLength',
    'before',
    'lengthBeforeCursor',
    'length_before_cursor',
    'deleteBeforeLength',
    'delete_before_length',
  ];

  static const _kImeDeleteAfterLengthKeys = <String>[
    'afterLength',
    'after',
    'lengthAfterCursor',
    'length_after_cursor',
    'deleteAfterLength',
    'delete_after_length',
  ];

  static const _kImeDeleteSuppressionWindow = Duration(milliseconds: 120);

  static const _kPrivateCommandTextKeys = <String>[
    'text',
    'TEXT',
    'android.intent.extra.PROCESS_TEXT',
    'androidx.core.view.inputmethod.InputConnectionCompat.CONTENT_DESCRIPTION',
    'androidx.core.view.inputmethod.InputConnectionCompat.CONTENT_CLIP',
  ];

  String? _extractTextFromPrivateCommand(Map<String, dynamic> data) {
    for (final key in _kPrivateCommandTextKeys) {
      final value = data[key];
      final text = _coerceToString(value);
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  bool _applySelectionFromPrivateCommand(Map<String, dynamic> data) {
    final base = data['selectionBase'];
    final extent = data['selectionExtent'];
    if (base is int && extent is int) {
      // Platform data, checked before it becomes the editing value: a range
      // outside the text would break the next edit that reads it.
      final length = _currentEditingState.text.length;
      if (base < 0 || extent < 0 || base > length || extent > length) {
        return true;
      }
      final affinityIndex = data['selectionAffinity'];
      TextAffinity? affinity;
      if (affinityIndex is int &&
          affinityIndex >= 0 &&
          affinityIndex < TextAffinity.values.length) {
        affinity = TextAffinity.values[affinityIndex];
      }
      final selection = TextSelection(
        baseOffset: base,
        extentOffset: extent,
        affinity: affinity ?? TextAffinity.downstream,
      );
      textEditingValue = _currentEditingState.copyWith(selection: selection);
      return true;
    }
    return false;
  }

  int? _coerceToInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  String? _coerceToString(dynamic value) {
    if (value is String) {
      return value;
    }
    if (value is List<int>) {
      return String.fromCharCodes(value);
    }
    if (value is List && value.isNotEmpty) {
      if (value.first is int) {
        try {
          return String.fromCharCodes(value.cast<int>());
        } catch (_) {
          return null;
        }
      }
      if (value.first is String) {
        return value.join();
      }
    }
    if (value is int) {
      return String.fromCharCode(value);
    }
    if (value is Iterable<int>) {
      return String.fromCharCodes(value);
    }
    return null;
  }
}
