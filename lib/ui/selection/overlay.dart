import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:xterm/ui/controller.dart';
import 'package:xterm/ui/render.dart';
import 'package:xterm/ui/selection/handles.dart';
import 'package:xterm/ui/selection/position.dart';
import 'package:xterm/ui/selection/toolbar.dart';

class TerminalSelectionOverlay {
  TerminalSelectionOverlay({
    required this.context,
    required this.selectionControls,
    required this.selectionDelegate,
    required this.renderTerminal,
    required this.terminalController,
    required this.startHandleLayerLink,
    required this.endHandleLayerLink,
    required this.toolbarLayerLink,
  }) {
    final OverlayState? overlay = Overlay.of(context, rootOverlay: true);
    _toolbarController =
        AnimationController(duration: fadeDuration, vsync: overlay!);
  }

  static const Duration fadeDuration = Duration(milliseconds: 150);

  final BuildContext context;

  final TextSelectionControls selectionControls;

  final TextSelectionDelegate selectionDelegate;

  final RenderTerminal renderTerminal;

  final TerminalController terminalController;

  final LayerLink startHandleLayerLink;

  final LayerLink endHandleLayerLink;

  final LayerLink toolbarLayerLink;

  late final AnimationController _toolbarController;

  OverlayEntry? _toolbar;

  List<OverlayEntry>? _handles;

  Offset? _lastSecondaryTapDownPosition;

  bool get isToolbarShown => _toolbar != null;

  bool get isHandlesShown => _handles != null;

  bool get isShowing => isToolbarShown || isHandlesShown;

  void showToolbar([Offset? lastSecondaryTapDownPosition]) {
    _lastSecondaryTapDownPosition = lastSecondaryTapDownPosition;
    if (_toolbar != null) return;
    _toolbar = OverlayEntry(builder: _buildToolbar);
    Overlay.of(context, rootOverlay: true)!.insert(_toolbar!);
    _toolbarController.forward(from: 0.0);
  }

  void hideToolbar() {
    _toolbarController.stop();
    _toolbar?.remove();
    _toolbar = null;
  }

  void showHandles() {
    if (_handles != null) return;

    _handles = <OverlayEntry>[
      OverlayEntry(
        builder: (context) => _buildHandle(context, HandlePosition.start),
      ),
      OverlayEntry(
        builder: (context) => _buildHandle(context, HandlePosition.end),
      ),
    ];

    Overlay.of(context, rootOverlay: true)!.insertAll(_handles!);
  }

  void hideHandles() {
    if (_handles != null) {
      _handles![0].remove();
      _handles![1].remove();
      _handles = null;
    }
  }

  void show() {
    showToolbar();
    showHandles();
  }

  void hide() {
    hideToolbar();
    hideHandles();
  }

  void update() {
    _markNeedsBuild();
  }

  void _markNeedsBuild() {
    if (_handles != null) {
      _handles![0].markNeedsBuild();
      _handles![1].markNeedsBuild();
    }
    _toolbar?.markNeedsBuild();
  }

  Widget _buildHandle(BuildContext context, HandlePosition position) {
    return SelectionHandleOverlay(
      position: position,
      selectionControls: selectionControls,
      renderTerminal: renderTerminal,
      terminalController: terminalController,
      startHandleLayerLink: startHandleLayerLink,
      endHandleLayerLink: endHandleLayerLink,
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return SelectionToolbarOverlay(
      selectionControls: selectionControls,
      selectionDelegate: selectionDelegate,
      layerLink: toolbarLayerLink,
      renderTerminal: renderTerminal,
      terminalController: terminalController,
      lastSecondaryTapDownPosition: _lastSecondaryTapDownPosition,
    );
  }
}
