import 'dart:math' show min, max;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:xterm/src/core/buffer/cell_flags.dart';
import 'package:xterm/src/core/buffer/position.dart';
import 'package:xterm/src/core/buffer/range.dart';
import 'package:xterm/src/core/cell.dart';
import 'package:xterm/src/core/buffer/line.dart';
import 'package:xterm/src/terminal.dart';
import 'package:xterm/src/ui/controller.dart';
import 'package:xterm/src/ui/cursor_type.dart';
import 'package:xterm/src/ui/palette_builder.dart';
import 'package:xterm/src/ui/paragraph_cache.dart';
import 'package:xterm/src/ui/terminal_size.dart';
import 'package:xterm/src/ui/terminal_text_style.dart';
import 'package:xterm/src/ui/terminal_theme.dart';

typedef EditableRectCallback = void Function(Rect rect, Rect caretRect);

class RenderTerminal extends RenderBox {
  RenderTerminal({
    required Terminal terminal,
    required TerminalController controller,
    required ViewportOffset offset,
    required EdgeInsets padding,
    required bool autoResize,
    required Size charMetrics,
    required TerminalStyle textStyle,
    required TerminalTheme theme,
    required FocusNode focusNode,
    required TerminalCursorType cursorType,
    required bool alwaysShowCursor,
    EditableRectCallback? onEditableRect,
    String? composingText,
  })  : _terminal = terminal,
        _controller = controller,
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

  TerminalController _controller;
  set controller(TerminalController controller) {
    if (_controller == controller) return;
    if (attached) _controller.removeListener(_onControllerUpdate);
    _controller = controller;
    if (attached) _controller.addListener(_onControllerUpdate);
    markNeedsLayout();
  }

  ViewportOffset _offset;
  set offset(ViewportOffset value) {
    if (value == _offset) return;
    if (attached) _offset.removeListener(_onScroll);
    _offset = value;
    if (attached) _offset.addListener(_onScroll);
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

  EditableRectCallback? _onEditableRect;
  set onEditableRect(EditableRectCallback? value) {
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

  var _stickToBottom = true;

  void _onScroll() {
    _stickToBottom = _offset.pixels >= _maxScrollExtent;
    markNeedsLayout();
  }

  void _onFocusChange() {
    markNeedsPaint();
  }

  void _onTerminalChange() {
    markNeedsLayout();
  }

  void _onControllerUpdate() {
    markNeedsLayout();
  }

  @override
  final isRepaintBoundary = true;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _offset.addListener(_onScroll);
    _terminal.addListener(_onTerminalChange);
    _controller.addListener(_onControllerUpdate);
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void detach() {
    super.detach();
    _offset.removeListener(_onScroll);
    _terminal.removeListener(_onTerminalChange);
    _controller.removeListener(_onControllerUpdate);
    _focusNode.removeListener(_onFocusChange);
  }

  @override
  bool hitTestSelf(Offset position) {
    return true;
  }

  @override
  void performLayout() {
    size = constraints.biggest;

    _updateViewportSize();

    _updateScrollOffset();

    if (_stickToBottom) {
      _offset.correctBy(_maxScrollExtent - _offset.pixels);
    }

    SchedulerBinding.instance
        .addPostFrameCallback((_) => _notifyEditableRect());
  }

  double get lineHeight => _charMetrics.height;

  double get terminalHeight =>
      _terminal.buffer.lines.length * _charMetrics.height;

  double get scrollOffset => _offset.pixels;

  BufferPosition positionFromOffset(Offset offset) {
    final x = offset.dx - _padding.left;
    final y = offset.dy - _padding.top + _offset.pixels;
    final row = y ~/ _charMetrics.height;
    final col = x ~/ _charMetrics.width;
    return BufferPosition(col, row);
  }

  Offset offsetFromPosition(BufferPosition position) {
    final row = position.y;
    final col = position.x;
    final x = col * _charMetrics.width;
    final y = row * _charMetrics.height;
    return Offset(x + _padding.left, y + _padding.top - _offset.pixels);
  }

  void selectWord(Offset from, [Offset? to]) {
    final fromOffset = positionFromOffset(globalToLocal(from));
    final fromBoundary = _terminal.buffer.getWordBoundary(fromOffset);
    if (fromBoundary == null) return;
    if (to == null) {
      _controller.setSelection(fromBoundary);
    } else {
      final toOffset = positionFromOffset(globalToLocal(to));
      final toBoundary = _terminal.buffer.getWordBoundary(toOffset);
      if (toBoundary == null) return;
      _controller.setSelection(fromBoundary.merge(toBoundary));
    }
  }

  void selectPosition(Offset from, [Offset? to]) {
    final fromPosition = positionFromOffset(globalToLocal(from));
    if (to == null) {
      _controller.setSelection(BufferRange.collapsed(fromPosition));
    } else {
      final toPosition = positionFromOffset(globalToLocal(to));
      _controller.setSelection(BufferRange(fromPosition, toPosition));
    }
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
    _paint(context, offset);
    context.setWillChangeHint();
  }

  void _paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;

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

    if (_controller.selection != null) {
      _paintSelection(
        canvas,
        _controller.selection!,
        effectFirstLine,
        effectLastLine,
      );
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
      color: _resolveForegroundColor(_terminal.cursor.foreground),
      backgroundColor: _theme.background,
      underline: true,
    );

    final builder = ParagraphBuilder(style.getParagraphStyle());
    builder.addPlaceholder(
      offset.dx,
      _charMetrics.height,
      PlaceholderAlignment.middle,
    );
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

  void _paintSelection(
    Canvas canvas,
    BufferRange selection,
    int firstLine,
    int lastLine,
  ) {
    for (final segment in selection.toSegments()) {
      if (segment.line >= _terminal.buffer.lines.length) {
        break;
      }

      if (segment.line < firstLine) {
        continue;
      }

      if (segment.line > lastLine) {
        break;
      }

      final start = segment.start ?? 0;
      final end = segment.end ?? _terminal.viewWidth;

      final startOffset = Offset(
        start * _charMetrics.width,
        segment.line * _charMetrics.height + _lineOffset,
      );

      final endOffset = Offset(
        end * _charMetrics.width,
        (segment.line + 1) * _charMetrics.height + _lineOffset,
      );

      final paint = Paint()
        ..color = _theme.cursor
        ..strokeWidth = 1;

      canvas.drawRect(
        Rect.fromPoints(startOffset, endOffset),
        paint,
      );
    }
  }

  @pragma('vm:prefer-inline')
  void _paintCellForeground(
    Canvas canvas,
    Offset offset,
    BufferLine line,
    CellData cellData,
  ) {
    final charCode = cellData.content & CellContent.codepointMask;
    if (charCode == 0) return;

    final hash = cellData.getHash();
    // final hash = cellData.getHash() + line.hashCode;
    var paragraph = _paragraphCache.getLayoutFromCache(hash);

    if (paragraph == null) {
      final cellFlags = cellData.flags;

      var color = cellFlags & CellFlags.inverse == 0
          ? _resolveForegroundColor(cellData.foreground)
          : _resolveBackgroundColor(cellData.background);

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
      color = _resolveForegroundColor(cellData.foreground);
    } else if (colorType == CellColor.normal) {
      return;
    } else {
      color = _resolveBackgroundColor(cellData.background);
    }

    final paint = Paint()..color = color;
    final doubleWidth = cellData.content >> CellContent.widthShift == 2;
    final widthScale = doubleWidth ? 2 : 1;
    final size = Size(_charMetrics.width * widthScale + 1, _charMetrics.height);
    canvas.drawRect(offset & size, paint);
  }

  @pragma('vm:prefer-inline')
  Color _resolveForegroundColor(int cellColor) {
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
  Color _resolveBackgroundColor(int cellColor) {
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
