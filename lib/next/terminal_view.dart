import 'dart:math' show min, max;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:xterm/buffer/cell_flags.dart';
import 'package:xterm/frontend/input_map.dart';
import 'package:xterm/input/keys.dart';
import 'package:xterm/next.dart';
import 'package:xterm/next/core/cell.dart';
import 'package:xterm/next/core/line.dart';
import 'package:xterm/next/ui/char_metrics.dart';
import 'package:xterm/next/ui/custom_text_edit.dart';
import 'package:xterm/next/ui/palette_builder.dart';
import 'package:xterm/next/ui/paragraph_cache.dart';
import 'package:xterm/next/ui/terminal_size.dart';
import 'package:xterm/next/ui/terminal_theme.dart';
import 'package:xterm/next/ui/themes.dart';

typedef _EditableRectCallback = void Function(Rect rect, Rect caretRect);

class TerminalView extends StatefulWidget {
  const TerminalView(
    this.terminal, {
    Key? key,
    this.theme = TerminalThemes.defaultTheme,
    this.textStyle = const TerminalStyle(),
    this.padding,
    this.scrollController,
    this.autoResize = true,
    this.backgroundOpacity = 1,
    this.focusNode,
    this.autofocus = false,
    this.onTap,
    this.keyboardType = TextInputType.emailAddress,
    this.keyboardAppearance = Brightness.dark,
    this.cursorType = TerminalCursorType.block,
    this.alwaysShowCursor = false,
    this.deleteDetection = false,
  }) : super(key: key);

  final Terminal terminal;

  final TerminalTheme theme;

  final TerminalStyle textStyle;

  final EdgeInsets? padding;

  final ScrollController? scrollController;

  final bool autoResize;

  final double backgroundOpacity;

  final FocusNode? focusNode;

  final bool autofocus;

  final VoidCallback? onTap;

  final TextInputType keyboardType;

  final Brightness keyboardAppearance;

  final TerminalCursorType cursorType;

  final bool alwaysShowCursor;

  /// Workaround to detect delete key for platforms and IMEs that does not
  /// emit hardware delete event.
  final bool deleteDetection;

  @override
  State<TerminalView> createState() => TerminalViewState();
}

class TerminalViewState extends State<TerminalView> {
  late final FocusNode focusNode;

  final customTextEditKey = GlobalKey<CustomTextEditState>();

  final scrollableKey = GlobalKey<ScrollableState>();

  String? composingText;
  
  T? _nonNullableWrap<T>(T? value) => value;

  @override
  void initState() {
    focusNode = widget.focusNode ?? FocusNode();
    super.initState();
  }

  @override
  void didUpdateWidget(TerminalView oldWidget) {
    if (oldWidget.focusNode != widget.focusNode) {
      focusNode = widget.focusNode ?? FocusNode();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  void requestKeyboard() {
    customTextEditKey.currentState?.requestKeyboard();
  }

  void closeKeyboard() {
    customTextEditKey.currentState?.closeKeyboard();
  }

  bool get hasInputConnection {
    return customTextEditKey.currentState?.hasInputConnection == true;
  }

  KeyEventResult _onKeyEvent(RawKeyEvent event) {
    if (event is! RawKeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final key = inputMap(event.logicalKey);

    if (key == null) {
      return KeyEventResult.ignored;
    }

    final handled = widget.terminal.keyInput(
      key,
      ctrl: event.isControlPressed,
      alt: event.isAltPressed,
      shift: event.isShiftPressed,
    );

    return handled ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  void _onKeyboardShow() {
    if (focusNode.hasFocus) {
       _nonNullableWrap(WidgetsBinding.instance)!.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  void _onEditableRect(Rect rect, Rect caretRect) {
    customTextEditKey.currentState?.setEditableRect(rect, caretRect);
  }

  void _scrollToBottom() {
    final position = scrollableKey.currentState?.position;
    if (position != null) {
      position.moveTo(position.maxScrollExtent);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate everytime build happens, because some fonts library
    // lazily load fonts (such as google_fonts) and this can change the
    // font metrics while textStyle is still the same.
    final charMetrics = calcCharMetrics(widget.textStyle);
    Widget child = Scrollable(
      key: scrollableKey,
      controller: widget.scrollController,
      viewportBuilder: (context, offset) {
        return _TerminalViewport(
          terminal: widget.terminal,
          offset: offset,
          padding: MediaQuery.of(context).padding,
          autoResize: widget.autoResize,
          charMetrics: charMetrics,
          textStyle: widget.textStyle,
          theme: widget.theme,
          focusNode: focusNode,
          cursorType: widget.cursorType,
          alwaysShowCursor: widget.alwaysShowCursor,
          onEditableRect: _onEditableRect,
          composingText: composingText,
        );
      },
    );

    child = Container(
      color: widget.theme.background.withOpacity(widget.backgroundOpacity),
      padding: widget.padding,
      child: child,
    );

    child = CustomTextEdit(
      key: customTextEditKey,
      focusNode: focusNode,
      inputType: widget.keyboardType,
      keyboardAppearance: widget.keyboardAppearance,
      deleteDetection: widget.deleteDetection,
      onInsert: (text) {
        _scrollToBottom();
        widget.terminal.textInput(text);
      },
      onDelete: () {
        _scrollToBottom();
        widget.terminal.keyInput(TerminalKey.backspace);
      },
      onComposing: (text) {
        setState(() => composingText = text);
      },
      onAction: (action) {
        _scrollToBottom();
        if (action == TextInputAction.done) {
          widget.terminal.keyInput(TerminalKey.enter);
        }
      },
      onKey: _onKeyEvent,
      child: child,
    );

    child = KeyboardVisibilty(
      onKeyboardShow: _onKeyboardShow,
      child: child,
    );

    return GestureDetector(
      onTap: () {
        customTextEditKey.currentState?.requestKeyboard();
        widget.onTap?.call();
      },
      child: child,
    );
  }
}

class _TerminalViewport extends LeafRenderObjectWidget {
  const _TerminalViewport({
    Key? key,
    required this.terminal,
    required this.offset,
    required this.padding,
    required this.autoResize,
    required this.charMetrics,
    required this.textStyle,
    required this.theme,
    required this.focusNode,
    required this.cursorType,
    required this.alwaysShowCursor,
    this.onEditableRect,
    this.composingText,
  }) : super(key: key);

  final Terminal terminal;

  final ViewportOffset offset;

  final EdgeInsets padding;

  final bool autoResize;

  final Size charMetrics;

  final TerminalStyle textStyle;

  final TerminalTheme theme;

  final FocusNode focusNode;

  final TerminalCursorType cursorType;

  final bool alwaysShowCursor;

  final _EditableRectCallback? onEditableRect;

  final String? composingText;

  @override
  _RenderTerminalViewport createRenderObject(BuildContext context) {
    return _RenderTerminalViewport(
      terminal: terminal,
      offset: offset,
      padding: padding,
      autoResize: autoResize,
      charMetrics: charMetrics,
      textStyle: textStyle,
      theme: theme,
      focusNode: focusNode,
      cursorType: cursorType,
      alwaysShowCursor: alwaysShowCursor,
      onEditableRect: onEditableRect,
      composingText: composingText,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, _RenderTerminalViewport renderObject) {
    renderObject
      ..terminal = terminal
      ..offset = offset
      ..padding = padding
      ..autoResize = autoResize
      ..charMetrics = charMetrics
      ..textStyle = textStyle
      ..theme = theme
      ..focusNode = focusNode
      ..cursorType = cursorType
      ..alwaysShowCursor = alwaysShowCursor
      .._onEditableRect = onEditableRect
      ..composingText = composingText;
  }
}

class _RenderTerminalViewport extends RenderBox {
  _RenderTerminalViewport({
    required Terminal terminal,
    required ViewportOffset offset,
    required EdgeInsets padding,
    required bool autoResize,
    required Size charMetrics,
    required TerminalStyle textStyle,
    required TerminalTheme theme,
    required FocusNode focusNode,
    required TerminalCursorType cursorType,
    required bool alwaysShowCursor,
    _EditableRectCallback? onEditableRect,
    String? composingText,
  })  : _terminal = terminal,
        _offset = offset,
        _padding = padding,
        _autoResize = autoResize,
        _charMetrics = charMetrics,
        _textStyle = textStyle,
        _theme = theme,
        _focusNode = focusNode,
        _cursorType = cursorType,
        _alwaysShowCursor = alwaysShowCursor,
        _onEditableRect = onEditableRect,
        _composingText = composingText {
    _updateColorPalette();
  }

  Terminal _terminal;
  set terminal(Terminal terminal) {
    if (_terminal == terminal) return;
    if (attached) _terminal.removeListener(_onTerminalChange);
    _terminal = terminal;
    if (attached) _terminal.addListener(_onTerminalChange);
    _resizeTerminalIfNeeded();
    markNeedsLayout();
  }

  ViewportOffset _offset;
  set offset(ViewportOffset value) {
    if (value == _offset) return;
    if (attached) _offset.removeListener(_hasScrolled);
    _offset = value;
    if (attached) _offset.addListener(_hasScrolled);
    markNeedsLayout();
  }

  EdgeInsets _padding;
  set padding(EdgeInsets value) {
    if (value == _padding) return;
    _padding = value;
    markNeedsLayout();
  }

  bool _autoResize;
  set autoResize(bool value) {
    if (value == _autoResize) return;
    _autoResize = value;
    markNeedsLayout();
  }

  Size _charMetrics;
  set charMetrics(Size value) {
    if (value == _charMetrics) return;
    _charMetrics = value;
    markNeedsLayout();
  }

  TerminalStyle _textStyle;
  set textStyle(TerminalStyle value) {
    if (value == _textStyle) return;
    _textStyle = value;
    markNeedsLayout();
  }

  TerminalTheme _theme;
  set theme(TerminalTheme value) {
    if (value == _theme) return;
    _theme = value;
    _updateColorPalette();
    markNeedsPaint();
  }

  FocusNode _focusNode;
  set focusNode(FocusNode value) {
    if (value == _focusNode) return;
    if (attached) _focusNode.removeListener(_onFocusChange);
    _focusNode = value;
    if (attached) _focusNode.addListener(_onFocusChange);
    markNeedsPaint();
  }

  TerminalCursorType _cursorType;
  set cursorType(TerminalCursorType value) {
    if (value == _cursorType) return;
    _cursorType = value;
    markNeedsPaint();
  }

  bool _alwaysShowCursor;
  set alwaysShowCursor(bool value) {
    if (value == _alwaysShowCursor) return;
    _alwaysShowCursor = value;
    markNeedsPaint();
  }

  _EditableRectCallback? _onEditableRect;
  set setOnEditableRect(_EditableRectCallback? value) {
    if (value == _onEditableRect) return;
    _onEditableRect = value;
    markNeedsLayout();
  }

  String? _composingText;
  set composingText(String? value) {
    if (value == _composingText) return;
    _composingText = value;
    markNeedsPaint();
  }

  final _paragraphCache = ParagraphCache(10240);

  late List<Color> _colorPalette;

  TerminalSize? _viewportSize;

  void _updateColorPalette() {
    _colorPalette = PaletteBuilder(_theme).build();
  }

  // var lineOffset = 0;

  var _stickToBottom = true;

  void _hasScrolled() {
    // For static scroll:
    //
    // final lineOffset = _offset.pixels ~/ _charMetrics.height;
    // if (this.lineOffset != lineOffset) {
    //   markNeedsLayout();
    //   this.lineOffset = lineOffset;
    // }

    _stickToBottom = _offset.pixels >= _maxScrollExtent;

    markNeedsLayout();
  }

  void _onFocusChange() {
    markNeedsPaint();
  }

  void _onTerminalChange() {
    markNeedsLayout();
  }

  @override
  final isRepaintBoundary = true;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _offset.addListener(_hasScrolled);
    _terminal.addListener(_onTerminalChange);
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void detach() {
    _offset.removeListener(_hasScrolled);
    _terminal.removeListener(_onTerminalChange);
    _focusNode.removeListener(_onFocusChange);
    super.detach();
  }

  @override
  void performLayout() {
    size = constraints.biggest;

    _updateViewportSize();

    _updateScrollOffset();

    if (_stickToBottom) {
      if (_offset.pixels <= _maxScrollExtent) {
        _offset.correctBy(
          _maxScrollExtent - _offset.pixels,
        );
      }
    }
    
    T? _nonNullableWrap<T>(T? value) => value;

   _nonNullableWrap(WidgetsBinding.instance)!
        .addPostFrameCallback((_) => _notifyEditableRect());
  }

  void _notifyEditableRect() {
    final cursor = localToGlobal(_cursorOffset);

    final rect = Rect.fromLTRB(
      cursor.dx,
      cursor.dy,
      size.width,
      cursor.dy + _charMetrics.height,
    );

    final caretRect = cursor & _charMetrics;

    _onEditableRect?.call(rect, caretRect);
  }

  void _updateViewportSize() {
    if (size <= _charMetrics) {
      return;
    }

    final viewportSize = TerminalSize(
      size.width ~/ _charMetrics.width,
      _viewportHeight ~/ _charMetrics.height,
    );

    if (_viewportSize != viewportSize) {
      _viewportSize = viewportSize;
      _resizeTerminalIfNeeded();
    }
  }

  void _resizeTerminalIfNeeded() {
    if (_autoResize && _viewportSize != null) {
      _terminal.resize(
        _viewportSize!.width,
        _viewportSize!.height,
        _charMetrics.width.round(),
        _charMetrics.height.round(),
      );
    }
  }

  bool get _isComposingText {
    return _composingText != null && _composingText!.isNotEmpty;
  }

  bool get _shouldShowCursor {
    return _terminal.cursorVisibleMode || _alwaysShowCursor || _isComposingText;
  }

  double get _viewportHeight {
    return size.height - _padding.vertical;
  }

  double get _maxScrollExtent {
    final terminalHeight = _terminal.buffer.lines.length * _charMetrics.height;
    return max(terminalHeight - _viewportHeight, 0.0);
  }

  double get _lineOffset {
    return -_offset.pixels + _padding.top;
  }

  Offset get _cursorOffset {
    return Offset(
      _terminal.buffer.cursorX * _charMetrics.width,
      _terminal.buffer.absoluteCursorY * _charMetrics.height + _lineOffset,
    );
  }

  void _updateScrollOffset() {
    _offset.applyViewportDimension(_viewportHeight);
    _offset.applyContentDimensions(0, _maxScrollExtent);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _paint(context.canvas, offset);
    context.setWillChangeHint();
  }

  void _paint(Canvas canvas, Offset offset) {
    final lines = _terminal.buffer.lines;
    final charHeight = _charMetrics.height;

    final firstLineOffset = _offset.pixels - _padding.top;
    final lastLineOffset = _offset.pixels + size.height + _padding.bottom;

    final firstLine = firstLineOffset ~/ charHeight;
    final lastLine = lastLineOffset ~/ charHeight;

    final effectFirstLine = firstLine.clamp(0, lines.length - 1);
    final effectLastLine = lastLine.clamp(0, lines.length - 1);

    for (var i = effectFirstLine; i <= effectLastLine; i++) {
      _paintLine(
        canvas,
        lines[i],
        offset.translate(0, (i * charHeight + _lineOffset).truncateToDouble()),
      );
    }

    if (_terminal.buffer.absoluteCursorY >= effectFirstLine &&
        _terminal.buffer.absoluteCursorY <= effectLastLine) {
      final cursorOffset = offset + _cursorOffset;

      if (_isComposingText) {
        _paintComposingText(canvas, cursorOffset);
      }

      if (_shouldShowCursor) {
        _paintCursor(canvas, cursorOffset);
      }
    }
  }

  void _paintCursor(Canvas canvas, Offset offset) {
    final paint = Paint()
      ..color = _theme.cursor
      ..strokeWidth = 1;

    if (!_focusNode.hasFocus) {
      paint.style = PaintingStyle.stroke;
      canvas.drawRect(offset & _charMetrics, paint);
      return;
    }

    switch (_cursorType) {
      case TerminalCursorType.block:
        paint.style = PaintingStyle.fill;
        canvas.drawRect(offset & _charMetrics, paint);
        return;
      case TerminalCursorType.underline:
        return canvas.drawLine(
          Offset(offset.dx, _charMetrics.height - 1),
          Offset(offset.dx + _charMetrics.width, _charMetrics.height - 1),
          paint,
        );
      case TerminalCursorType.verticalBar:
        return canvas.drawLine(
          Offset(offset.dx, 0),
          Offset(offset.dx, _charMetrics.height),
          paint,
        );
    }
  }
  
  

  void _paintComposingText(Canvas canvas, Offset offset) {
    final composingText = _composingText;

    if (composingText == null) {
      return;
    }

    final style = _textStyle.toTextStyle(
      color: resolveForegroundColor(_terminal.cursor.foreground),
      backgroundColor: _theme.background,
      underline: true,
    );

    final builder = ParagraphBuilder(style.getParagraphStyle());
    builder.addPlaceholder(
        offset.dx, _charMetrics.height, PlaceholderAlignment.middle);
    builder.pushStyle(style.getTextStyle());
    builder.addText(composingText);

    final paragraph = builder.build();
    paragraph.layout(ParagraphConstraints(width: size.width));

    canvas.drawParagraph(paragraph, Offset(0, offset.dy));
  }

  void _paintLine(Canvas canvas, BufferLine line, Offset offset) {
    final cellData = CellData.empty();
    final cellWidth = _charMetrics.width;

    final visibleCells = size.width ~/ cellWidth + 1;
    final effectCells = min(visibleCells, line.length);

    for (var i = 0; i < effectCells; i++) {
      line.getCellData(i, cellData);
      final charWidth = cellData.content >> CellContent.widthShift;
      final cellOffset = offset.translate(i * cellWidth, 0);
      _paintCellBackground(canvas, cellOffset, cellData);
      _paintCellForeground(canvas, cellOffset, line, cellData);

      if (charWidth == 2) {
        i++;
      }
    }
  }

  @pragma('vm:prefer-inline')
  void _paintCellForeground(
      Canvas canvas, Offset offset, BufferLine line, CellData cellData) {
    final charCode = cellData.content & CellContent.codepointMask;
    if (charCode == 0) return;

    final hash = cellData.getHash();
    // final hash = cellData.getHash() + line.hashCode;
    var paragraph = _paragraphCache.getLayoutFromCache(hash);

    if (paragraph == null) {
      final cellFlags = cellData.flags;

      var color = cellFlags & CellFlags.inverse == 0
          ? resolveForegroundColor(cellData.foreground)
          : resolveBackgroundColor(cellData.background);

      if (cellData.flags & CellFlags.faint != 0) {
        color = color.withOpacity(0.5);
      }

      final style = _textStyle.toTextStyle(
        color: color,
        bold: cellFlags & CellFlags.bold != 0,
        italic: cellFlags & CellFlags.italic != 0,
        underline: cellFlags & CellFlags.underline != 0,
      );

      paragraph = _paragraphCache.performAndCacheLayout(
        String.fromCharCode(charCode),
        style,
        hash,
      );
    }

    canvas.drawParagraph(paragraph, offset);
  }

  @pragma('vm:prefer-inline')
  void _paintCellBackground(Canvas canvas, Offset offset, CellData cellData) {
    late Color color;
    final colorType = cellData.background & CellColor.typeMask;

    if (cellData.flags & CellFlags.inverse != 0) {
      color = resolveForegroundColor(cellData.foreground);
    } else if (colorType == CellColor.normal) {
      return;
    } else {
      color = resolveBackgroundColor(cellData.background);
    }

    final paint = Paint()..color = color;
    final doubleWidth = cellData.content >> CellContent.widthShift == 2;
    final widthScale = doubleWidth ? 2 : 1;
    final size = Size(_charMetrics.width * widthScale + 1, _charMetrics.height);
    canvas.drawRect(offset & size, paint);
  }

  @pragma('vm:prefer-inline')
  Color resolveForegroundColor(int cellColor) {
    final colorType = cellColor & CellColor.typeMask;
    final colorValue = cellColor & CellColor.valueMask;

    switch (colorType) {
      case CellColor.normal:
        return _theme.foreground;
      case CellColor.named:
      case CellColor.palette:
        return _colorPalette[colorValue];
      case CellColor.rgb:
      default:
        return Color(colorValue | 0xFF000000);
    }
  }

  @pragma('vm:prefer-inline')
  Color resolveBackgroundColor(int cellColor) {
    final colorType = cellColor & CellColor.typeMask;
    final colorValue = cellColor & CellColor.valueMask;

    switch (colorType) {
      case CellColor.normal:
        return _theme.background;
      case CellColor.named:
      case CellColor.palette:
        return _colorPalette[colorValue];
      case CellColor.rgb:
      default:
        return Color(colorValue | 0xFF000000);
    }
  }
}
