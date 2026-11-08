import 'dart:math' show max;
import 'dart:ui';

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:xterm/src/core/buffer/cell_offset.dart';
import 'package:xterm/src/core/buffer/line.dart';
import 'package:xterm/src/core/buffer/range.dart';
import 'package:xterm/src/core/buffer/range_line.dart';
import 'package:xterm/src/core/buffer/segment.dart';
import 'package:xterm/src/core/cursor_type.dart';
import 'package:xterm/src/core/mouse/button.dart';
import 'package:xterm/src/core/mouse/button_state.dart';
import 'package:xterm/src/terminal.dart';
import 'package:xterm/src/ui/controller.dart';
import 'package:xterm/src/ui/painter.dart';
import 'package:xterm/src/ui/selection_mode.dart';
import 'package:xterm/src/ui/terminal_size.dart';
import 'package:xterm/src/ui/terminal_text_style.dart';
import 'package:xterm/src/ui/terminal_theme.dart';

typedef EditableRectCallback = void Function(Rect rect, Rect caretRect);

class RenderTerminal extends RenderBox with RelayoutWhenSystemFontsChangeMixin {
  RenderTerminal({
    required this._terminal,
    required this._controller,
    required this._offset,
    required this._padding,
    required this._autoResize,
    required TerminalStyle textStyle,
    required TextScaler textScaler,
    double devicePixelRatio = 1.0,
    required TerminalTheme theme,
    required this._focusNode,
    required this._cursorType,
    required this._cursorBlinkEnabled,
    required this._cursorBlinkVisible,
    required this._alwaysShowCursor,
    this._onEditableRect,
    this._composingText,
  }) : _painter = TerminalPainter(
         theme: theme,
         textStyle: textStyle,
         textScaler: textScaler,
         devicePixelRatio: devicePixelRatio,
       );

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
    // The viewport may be the size it was, which a layout does not act on.
    _resizeTerminalIfNeeded();
    markNeedsLayout();
  }

  set textStyle(TerminalStyle value) {
    if (value == _painter.textStyle) return;
    _painter.textStyle = value;
    markNeedsLayout();
  }

  set textScaler(TextScaler value) {
    if (value == _painter.textScaler) return;
    _painter.textScaler = value;
    markNeedsLayout();
  }

  /// Only the glyph atlas reads this, so a change repaints without relaying
  /// out: the grid is measured in logical pixels and does not move.
  set devicePixelRatio(double value) {
    if (value == _painter.devicePixelRatio) return;
    _painter.devicePixelRatio = value;
    markNeedsPaint();
  }

  set theme(TerminalTheme value) {
    if (value == _painter.theme) return;
    _painter.theme = value;
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

  bool _cursorBlinkEnabled;
  bool get cursorBlinkEnabled => _cursorBlinkEnabled;

  set cursorBlinkEnabled(bool value) {
    if (value == _cursorBlinkEnabled) return;
    _cursorBlinkEnabled = value;
    markNeedsPaint();
  }

  bool _cursorBlinkVisible;
  set cursorBlinkVisible(bool value) {
    if (value == _cursorBlinkVisible) return;
    _cursorBlinkVisible = value;
    markNeedsPaint();
  }

  bool _alwaysShowCursor;
  set alwaysShowCursor(bool value) {
    if (value == _alwaysShowCursor) return;
    _alwaysShowCursor = value;
    markNeedsPaint();
  }

  /// Where the selection was before the one being drawn, and how far the
  /// highlight has travelled from there — 1 meaning it has arrived.
  ///
  /// A selection is whole cells, so it moves in whole cells, and dragging one
  /// out stepped the highlight a cell at a time. These let it be drawn part
  /// of the way, so it slides. Nothing else about the selection is affected:
  /// what is copied, and what the handles are placed against, is the range
  /// itself, which never has a fraction in it.
  BufferRange? _selectionFrom;
  BufferRange? get selectionFrom => _selectionFrom;
  set selectionFrom(BufferRange? value) {
    if (value == _selectionFrom) return;
    _selectionFrom = value;
    markNeedsPaint();
  }

  double _selectionT = 1;
  double get selectionT => _selectionT;
  set selectionT(double value) {
    if (value == _selectionT) return;
    _selectionT = value;
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

  TerminalSize? _viewportSize;

  final TerminalPainter _painter;

  var _stickToBottom = true;

  void _onScroll() {
    _restoring = false;
    _stickToBottom = _scrollOffset >= _maxScrollExtent;
    markNeedsLayout();
    _notifyEditableRect();
  }

  void _onFocusChange() {
    markNeedsPaint();
  }

  void _onTerminalChange() {
    markNeedsLayout();
    _notifyEditableRect();
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
    // A settle dropped while detached; the viewport kept its new size.
    final cells = _viewportSize;
    if (cells != null &&
        (cells.width != _terminal.viewWidth ||
            cells.height != _terminal.viewHeight)) {
      _settleHeightLater();
    }
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
  void dispose() {
    _painter.dispose();
    super.dispose();
  }

  @override
  bool hitTestSelf(Offset position) {
    return true;
  }

  @override
  void systemFontsDidChange() {
    _painter.clearFontCache();
    super.systemFontsDidChange();
  }

  @override
  void performLayout() {
    size = constraints.biggest;

    _updateViewportSize();

    _updateScrollOffset();

    if (_stickToBottom) {
      _offset.correctBy(_maxScrollExtent - _scrollOffset);
    } else {
      _keepTopLine();
    }
    _rememberTopLine();
  }

  /// The line at the top of the view and the index it had then. A full
  /// scrollback drops lines off its front as output arrives, which moves every
  /// line up while the scroll offset stays put; following this line keeps a
  /// view scrolled up on the text being read.
  BufferLine? _topLine;
  int _topLineIndex = 0;

  /// How far the view was above the bottom, for when its top line is gone.
  double _bottomDistance = 0;

  /// The view waits for the text replacing a cleared buffer to reach back to
  /// [_bottomDistance]: a layout before the replay has arrived must not take
  /// the empty screen for where the view is.
  bool _restoring = false;

  void _keepTopLine() {
    final line = _topLine;
    if (line == null) return;
    if (!line.attached || _restoring) {
      // The buffer was cleared under it, as a reset before a replay of the
      // same text does. What replaces it ends where it ended, while it may
      // start elsewhere: the view keeps its distance from the bottom.
      final target = _maxScrollExtent - _bottomDistance;
      _offset.correctBy(max(0.0, target) - _scrollOffset);
      _restoring = target < 0;
      return;
    }
    final lines = _terminal.buffer.lines;
    final index = line.index;
    // Another buffer's line, after a switch to or from the alternate screen.
    if (index >= lines.length || !identical(lines[index], line)) return;
    final moved = index - _topLineIndex;
    if (moved != 0) {
      _offset.correctBy(moved * _painter.cellSize.height);
    }
  }

  void _rememberTopLine() {
    final lines = _terminal.buffer.lines;
    if (lines.length == 0) {
      _topLine = null;
      return;
    }
    final row = (_scrollOffset ~/ _painter.cellSize.height).clamp(
      0,
      lines.length - 1,
    );
    _topLine = lines[row];
    _topLineIndex = row;
    if (!_restoring) _bottomDistance = _maxScrollExtent - _scrollOffset;
  }

  /// Total height of the terminal in pixels. Includes scrollback buffer.
  double get _terminalHeight =>
      _terminal.buffer.lines.length * _painter.cellSize.height;

  /// The distance from the top of the terminal to the top of the viewport.
  // double get _scrollOffset => _offset.pixels;
  double get _scrollOffset {
    // return _offset.pixels ~/ _painter.cellSize.height * _painter.cellSize.height;
    return _offset.pixels;
  }

  /// The height of a terminal line in pixels. This includes the line spacing.
  /// Height of the entire terminal is expected to be a multiple of this value.
  double get lineHeight => _painter.cellSize.height;

  /// Get the top-left corner of the cell at [cellOffset] in pixels.
  Offset getOffset(CellOffset cellOffset) {
    final row = cellOffset.y;
    final col = cellOffset.x;
    final x = col * _painter.cellSize.width;
    final y = row * _painter.cellSize.height;
    return Offset(x + _padding.left, y + _padding.top - _scrollOffset);
  }

  /// Get the [CellOffset] of the cell that [offset] is in.
  CellOffset getCellOffset(Offset offset) {
    final x = offset.dx - _padding.left;
    final y = offset.dy - _padding.top + _scrollOffset;
    final row = y ~/ _painter.cellSize.height;
    final col = x ~/ _painter.cellSize.width;
    return CellOffset(
      col.clamp(0, _terminal.viewWidth - 1),
      row.clamp(0, _terminal.buffer.lines.length - 1),
    );
  }

  Iterable<int> _getYOffsetForFindingWord(int y) sync* {
    yield 0;
    if (y > 0) yield -1;
    if (y < _terminal.buffer.lines.length - 1) yield 1;
  }

  /// Selects entire words in the terminal that contains [from] and [to].
  /// In order to better mobile experience, we need to find the word boundary
  /// in the range of [y, y+1, y-1] lines sequentially.
  /// But we should check y>0 before y-1 and y<terminalHeight before y+1.
  BufferRangeLine? selectWord(CellOffset from, [CellOffset? to]) {
    final fromBoundary = wordBoundaryAt(from);
    if (fromBoundary == null) return null;

    if (to == null) {
      selectBufferRange(fromBoundary, mode: SelectionMode.line);
      return fromBoundary;
    } else {
      final toBoundary = wordBoundaryAt(to);
      if (toBoundary == null) return null;

      final range = fromBoundary.merge(toBoundary);
      selectBufferRange(range, mode: SelectionMode.line);
      return range;
    }
  }

  /// The word [offset] is in, or null where there is none. Changes nothing:
  /// [selectWord] is this and then a selection, and a drag that grows by the
  /// word needs the boundary on its own, several times per second.
  BufferRangeLine? wordBoundaryAt(CellOffset offset) {
    /// Toleration for the point position is not accurate.
    for (final yOffset in _getYOffsetForFindingWord(offset.y)) {
      final candidate = CellOffset(offset.x, offset.y + yOffset);
      final boundary = _terminal.buffer.getWordBoundary(candidate);
      if (boundary != null) return boundary;
    }
    return null;
  }

  /// The whole line [offset] is on.
  ///
  /// A line that wrapped is one line: the rows it runs over are one line of
  /// text, and taking all of them is what a third click does in a text field
  /// and in every terminal that has the gesture.
  BufferRangeLine lineBoundaryAt(CellOffset offset) {
    final buffer = _terminal.buffer;
    final lines = buffer.lines;

    var start = offset.y.clamp(0, lines.length - 1);
    while (start > 0 && lines[start].isWrapped) {
      start--;
    }

    var end = start;
    while (end + 1 < lines.length && lines[end + 1].isWrapped) {
      end++;
    }

    return BufferRangeLine(
      CellOffset(0, start),
      CellOffset(buffer.viewWidth, end),
    );
  }

  /// Selects the whole line [from] is on. See [lineBoundaryAt].
  BufferRangeLine selectLine(CellOffset from) {
    final range = lineBoundaryAt(from);
    selectBufferRange(range, mode: SelectionMode.line);
    return range;
  }

  String? get selectedText {
    final selection = _controller.selection;
    if (selection == null) {
      return null;
    }
    return _terminal.buffer.getText(selection);
  }

  /// Selects characters in the terminal that starts from [from] to [to]. At
  /// least one cell is selected even if [from] and [to] are same.
  void selectCharacters(CellOffset from, [CellOffset? to]) {
    if (to == null) {
      _controller.setSelection(
        _terminal.buffer.createAnchorFromOffset(from),
        _terminal.buffer.createAnchorFromOffset(from),
        mode: SelectionMode.line,
      );
    } else {
      if (to.x >= from.x) {
        to = CellOffset(to.x + 1, to.y);
      }
      _controller.setSelection(
        _terminal.buffer.createAnchorFromOffset(from),
        _terminal.buffer.createAnchorFromOffset(to),
        mode: SelectionMode.line,
      );
    }
  }

  void selectBufferRange(BufferRange range, {SelectionMode? mode}) {
    final normalized = range.normalized;
    _controller.setSelection(
      _terminal.buffer.createAnchorFromOffset(normalized.begin),
      _terminal.buffer.createAnchorFromOffset(normalized.end),
      mode: mode ?? _controller.selectionMode,
    );
  }

  /// Selects all content in the terminal buffer.
  void selectAll() {
    final buffer = _terminal.buffer;
    if (buffer.height == 0) {
      return;
    }
    final start = buffer.createAnchor(0, 0);
    final end = buffer.createAnchor(buffer.viewWidth, buffer.height - 1);
    _controller.setSelection(start, end, mode: SelectionMode.line);
  }

  void clearSelection() {
    _controller.clearSelection();
  }

  /// The cell at [offset] counted from the top of the screen rather than of
  /// the buffer, which is what a mouse report carries. A line in the
  /// scrollback is above the screen, so its row is negative.
  CellOffset getScreenCellOffset(Offset offset) {
    final cell = getCellOffset(offset);
    return CellOffset(cell.x, cell.y - _terminal.buffer.scrollBack);
  }

  /// Send a mouse event at [offset] with [button] being currently in [buttonState].
  bool mouseEvent(
    TerminalMouseButton button,
    TerminalMouseButtonState buttonState,
    Offset offset,
  ) {
    return _terminal.mouseInput(
      button,
      buttonState,
      getScreenCellOffset(offset),
    );
  }

  void _notifyEditableRect() {
    final onEditableRect = _onEditableRect;
    if (onEditableRect == null) return;

    // Called from [_onTerminalChange] and [_onScroll], neither of which is a
    // layout pass — the terminal is written to from a socket. So there may not
    // be a size to read yet, and [localToGlobal] has nothing to answer with
    // until there is.
    if (!hasSize) return;

    final cursor = localToGlobal(cursorOffset);

    // Skipped rather than sent when it is not a real rectangle.
    //
    // The editable rect goes to the engine as JSON, and JSON has no NaN: a
    // non-finite one throws `JsonUnsupportedObjectError` inside the platform
    // channel, from a timer callback with nothing above it to catch it. It has
    // been seen on a device, through `Terminal.write` on a session flush.
    //
    // **Why the geometry goes non-finite is not known.** Offstage, a zero-size
    // box and an ancestor at scale zero were all tried and all stay finite —
    // see `test/src/ui/editable_rect_test.dart`, which records that rather
    // than pretending to reproduce it. So this is a guard and not a fix: it
    // costs one skipped update, and the next write, frame or caret move sends
    // another.
    //
    // A candidate worth keeping in mind if it is chased again: this runs from
    // `_onTerminalChange`, immediately after `markNeedsLayout` and therefore
    // before the layout it just invalidated — so both `size` and the paint
    // transform are read a frame stale by construction.
    if (!cursor.isFinite || !_painter.cellSize.isFinite || !size.isFinite) {
      return;
    }

    final rect = Rect.fromLTRB(
      cursor.dx,
      cursor.dy,
      size.width,
      cursor.dy + _painter.cellSize.height,
    );

    final caretRect = cursor & _painter.cellSize;

    onEditableRect(rect, caretRect);
  }

  /// Update the viewport size in cells based on the current widget size in
  /// pixels.
  void _updateViewportSize() {
    final width = size.width - _padding.horizontal;
    if (width < _painter.cellSize.width ||
        _viewportHeight < _painter.cellSize.height) {
      return;
    }

    final viewportSize = TerminalSize(
      width ~/ _painter.cellSize.width,
      _viewportHeight ~/ _painter.cellSize.height,
    );

    final previous = _viewportSize;
    final heightMoved =
        _laidOutHeight != null && _laidOutHeight != _viewportHeight;
    _laidOutHeight = _viewportHeight;
    _viewportSize = viewportSize;

    if (previous == null || previous.width != viewportSize.width) {
      _resizeTerminalIfNeeded();
      return;
    }
    // A height that changes frame after frame is an animation, as a soft
    // keyboard's: each size would reach the program as a SIGWINCH and its
    // redraw arrive for a size already gone. The view clips to the bottom
    // meanwhile, and the terminal takes the size the animation ends at.
    // Pixels, not rows, tell whether it still moves: an eased animation's
    // first and last frames move less than a row.
    if (heightMoved) _settleHeightLater();
  }

  double? _laidOutHeight;
  bool _heightChanged = false;
  bool _heightSettling = false;

  void _settleHeightLater() {
    if (!_autoResize) return;
    _heightChanged = true;
    if (_heightSettling) return;
    _heightSettling = true;
    SchedulerBinding.instance.addPostFrameCallback(_settleHeight);
  }

  void _settleHeight(Duration _) {
    if (!attached) {
      _heightSettling = false;
      return;
    }
    if (_heightChanged) {
      // Changed in this frame; one frame more decides whether it goes on.
      _heightChanged = false;
      SchedulerBinding.instance
        ..addPostFrameCallback(_settleHeight)
        ..scheduleFrame();
      return;
    }
    _heightSettling = false;
    final cells = _viewportSize;
    if (cells == null ||
        (cells.width == _terminal.viewWidth &&
            cells.height == _terminal.viewHeight)) {
      return;
    }
    // Ahead of the resize, whose callback can throw.
    markNeedsLayout();
    _resizeTerminalIfNeeded();
  }

  /// Notify the underlying terminal that the viewport size has changed.
  void _resizeTerminalIfNeeded() {
    if (_autoResize && _viewportSize != null) {
      _terminal.resize(
        _viewportSize!.width,
        _viewportSize!.height,
        _painter.cellSize.width.round(),
        _painter.cellSize.height.round(),
      );
    }
  }

  /// Update the scroll offset based on the current terminal state. This should
  /// be called in [performLayout] after the viewport size has been updated.
  void _updateScrollOffset() {
    _offset.applyViewportDimension(_viewportHeight);
    _offset.applyContentDimensions(0, _maxScrollExtent);
  }

  bool get _isComposingText {
    return _composingText != null && _composingText!.isNotEmpty;
  }

  bool get _shouldShowCursor {
    return _terminal.cursorVisibleMode || _alwaysShowCursor || _isComposingText;
  }

  TerminalCursorType get _effectiveCursorType {
    return _terminal.cursorTypeOverride ?? _cursorType;
  }

  double get _viewportHeight {
    return size.height - _padding.vertical;
  }

  double get _maxScrollExtent {
    return max(_terminalHeight - _viewportHeight, 0.0);
  }

  double get _lineOffset {
    return -_scrollOffset + _padding.top;
  }

  /// The offset of the cursor from the top left corner of this render object.
  Offset get cursorOffset {
    return Offset(
      _terminal.buffer.cursorX * _painter.cellSize.width + _padding.left,
      _terminal.buffer.absoluteCursorY * _painter.cellSize.height + _lineOffset,
    );
  }

  Size get cellSize {
    return _painter.cellSize;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _paint(context, offset);
    context.setWillChangeHint();
  }

  void _paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;

    final lines = _terminal.buffer.lines;
    final charHeight = _painter.cellSize.height;

    final firstLineOffset = _scrollOffset - _padding.top;
    final lastLineOffset = _scrollOffset + size.height + _padding.bottom;

    final firstLine = firstLineOffset ~/ charHeight;
    final lastLine = lastLineOffset ~/ charHeight;

    final effectFirstLine = firstLine.clamp(0, lines.length - 1);
    final effectLastLine = lastLine.clamp(0, lines.length - 1);

    for (var i = effectFirstLine; i <= effectLastLine; i++) {
      _painter.paintLine(
        canvas,
        offset.translate(
          _padding.left,
          (i * charHeight + _lineOffset).truncateToDouble(),
        ),
        lines[i],
        reverseDisplay: _terminal.reverseDisplayMode,
      );
    }

    if (_terminal.buffer.absoluteCursorY >= effectFirstLine &&
        _terminal.buffer.absoluteCursorY <= effectLastLine) {
      if (_isComposingText) {
        _paintComposingText(canvas, offset + cursorOffset);
      }

      final shouldPaintCursor =
          _shouldShowCursor &&
          (!_cursorBlinkEnabled ||
              !_focusNode.hasFocus ||
              _cursorBlinkVisible ||
              _isComposingText);

      if (shouldPaintCursor) {
        _painter.paintCursor(
          canvas,
          offset + cursorOffset,
          cursorType: _effectiveCursorType,
          hasFocus: _focusNode.hasFocus,
        );
      }
    }

    _paintHighlights(
      canvas,
      _controller.highlights,
      effectFirstLine,
      effectLastLine,
    );

    if (_controller.selection != null) {
      _paintSelection(
        canvas,
        _controller.selection!,
        effectFirstLine,
        effectLastLine,
      );
    }
  }

  /// Paints the text that is currently being composed in IME to [canvas] at
  /// [offset]. [offset] is usually the cursor position.
  void _paintComposingText(Canvas canvas, Offset offset) {
    final composingText = _composingText;
    if (composingText == null) {
      return;
    }

    final style = _painter.textStyle.toTextStyle(
      color: _painter.resolveForegroundColor(_terminal.cursor.foreground),
      backgroundColor: _painter.theme.background,
      underline: true,
    );

    final builder = ParagraphBuilder(style.getParagraphStyle());
    builder.addPlaceholder(
      offset.dx,
      _painter.cellSize.height,
      PlaceholderAlignment.middle,
    );
    builder.pushStyle(style.getTextStyle(textScaler: _painter.textScaler));
    builder.addText(composingText);

    final paragraph = builder.build();
    paragraph.layout(ParagraphConstraints(width: size.width));

    canvas.drawParagraph(paragraph, Offset(0, offset.dy));
  }

  void _paintSelection(
    Canvas canvas,
    BufferRange selection,
    int firstLine,
    int lastLine,
  ) {
    final to = selection.normalized;

    // Where each end is drawn while the tween runs, in cells and fractional.
    // Only the horizontal is interpolated, and only for an end that stayed on
    // its row: a highlight sliding diagonally across a grid of cells to catch
    // up with a row it is already on reads as a mistake rather than as motion.
    double? beginX;
    double? endX;

    final from = _selectionFrom?.normalized;
    if (from != null && _selectionT < 1) {
      if (from.begin.y == to.begin.y) {
        beginX = lerpDouble(from.begin.x, to.begin.x, _selectionT);
      }
      if (from.end.y == to.end.y) {
        endX = lerpDouble(from.end.x, to.end.x, _selectionT);
      }
    }

    for (final segment in to.toSegments()) {
      if (segment.line >= _terminal.buffer.lines.length) {
        break;
      }

      if (segment.line < firstLine) {
        continue;
      }

      if (segment.line > lastLine) {
        break;
      }

      _paintSegment(
        canvas,
        segment,
        _painter.theme.selection,
        start: segment.line == to.begin.y ? beginX : null,
        end: segment.line == to.end.y ? endX : null,
      );
    }
  }

  void _paintHighlights(
    Canvas canvas,
    List<TerminalHighlight> highlights,
    int firstLine,
    int lastLine,
  ) {
    for (var highlight in _controller.highlights) {
      final range = highlight.range?.normalized;

      if (range == null ||
          range.begin.y > lastLine ||
          range.end.y < firstLine) {
        continue;
      }

      for (var segment in range.toSegments()) {
        if (segment.line < firstLine) {
          continue;
        }

        if (segment.line > lastLine) {
          break;
        }

        _paintSegment(canvas, segment, highlight.color);
      }
    }
  }

  @pragma('vm:prefer-inline')
  void _paintSegment(
    Canvas canvas,
    BufferSegment segment,
    Color color, {
    double? start,
    double? end,
  }) {
    final startX = start ?? (segment.start ?? 0).toDouble();
    final endX = end ?? (segment.end ?? _terminal.viewWidth).toDouble();

    final startOffset = Offset(
      startX * _painter.cellSize.width + _padding.left,
      segment.line * _painter.cellSize.height + _lineOffset,
    );

    _painter.paintHighlight(canvas, startOffset, endX - startX, color);
  }
}
