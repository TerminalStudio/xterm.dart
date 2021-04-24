import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:xterm/frontend/cell_size.dart';
import 'package:xterm/xterm.dart';

class TerminalScrollable extends StatefulWidget {
  TerminalScrollable({
    required this.terminal,
    required this.cellSize,
    required this.scrollController,
    required this.child,
  });

  final Terminal terminal;
  final CellSize cellSize;
  final ScrollController scrollController;
  final Widget child;

  @override
  _TerminalScrollableState createState() => _TerminalScrollableState();
}

class _TerminalScrollableState extends State<TerminalScrollable> {
  /// Scroll position from the terminal. Not null if terminal scroll extent has
  /// been updated and needs to be syncronized to flutter side.
  double? _pendingTerminalScrollExtent;

  void onTerminalChange() {
    _pendingTerminalScrollExtent =
        widget.cellSize.cellHeight * widget.terminal.buffer.scrollOffsetFromTop;

    if (widget.scrollController.position.pixels !=
        _pendingTerminalScrollExtent) {
      setState(() {});
    }
  }

  @override
  void initState() {
    widget.terminal.addListener(onTerminalChange);
    super.initState();
  }

  @override
  void didUpdateWidget(TerminalScrollable oldWidget) {
    oldWidget.terminal.removeListener(onTerminalChange);
    widget.terminal.addListener(onTerminalChange);
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    widget.terminal.removeListener(onTerminalChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        _onScrollNotification(notification.metrics.pixels);
        return false;
      },
      child: Scrollable(
        controller: widget.scrollController,
        viewportBuilder: _buildViewport,
      ),
    );
  }

  // synchronize flutter scroll offset to terminal
  void _onScrollNotification(double offset) {
    final topOffset = (offset / widget.cellSize.cellHeight).ceil();
    final bottomOffset = widget.terminal.invisibleHeight - topOffset;

    widget.terminal.buffer.setScrollOffsetFromBottom(bottomOffset);
    widget.terminal.refresh();

    /// Clear [_pendingTerminalScrollExtent] because currently [Scrollable] is
    /// the source of scrolling.
    _pendingTerminalScrollExtent = null;
  }

  Widget _buildViewport(
    BuildContext context,
    ViewportOffset offset,
  ) {
    final position = widget.scrollController.position;

    /// Use [_EmptyScrollActivity] to suppress unexpected behaviors
    /// that come from [applyViewportDimension].
    if (position is ScrollActivityDelegate) {
      position.beginActivity(
        _EmptyScrollActivity(position as ScrollActivityDelegate),
      );
    }

    // Set viewport height.
    final cellSize = widget.cellSize;
    final viewportExtent = cellSize.cellHeight * widget.terminal.viewHeight;
    offset.applyViewportDimension(viewportExtent);

    final totalExtent = cellSize.cellHeight * widget.terminal.buffer.height;
    final minScrollExtent = 0.0;
    final maxScrollExtent = totalExtent - viewportExtent;

    // Set how much the terminal can scroll
    offset.applyContentDimensions(
      minScrollExtent,
      math.max(0.0, maxScrollExtent),
    );

    // Syncronize pending terminal scroll extent to ScrollController
    if (_pendingTerminalScrollExtent != null) {
      position.correctPixels(_pendingTerminalScrollExtent!);
      _pendingTerminalScrollExtent = null;
    }

    return widget.child;
  }
}

/// A scroll activity that does nothing. Used to suppress unexpected behaviors
/// from [Scrollable] during viewport building process.
class _EmptyScrollActivity extends IdleScrollActivity {
  _EmptyScrollActivity(ScrollActivityDelegate delegate) : super(delegate);

  @override
  void applyNewDimensions() {}

  /// set [isScrolling] to ture to prevent flutter from calling the old scroll
  /// activity.
  @override
  final isScrolling = true;

  @override
  void dispatchScrollStartNotification(
    ScrollMetrics metrics,
    BuildContext? context,
  ) {}
}
