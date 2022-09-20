import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:xterm/src/core/buffer/cell_offset.dart';
import 'package:xterm/src/core/buffer/range_line.dart';
import 'package:xterm/src/terminal.dart';
import 'package:xterm/src/ui/controller.dart';

class TerminalShortcut<T extends Intent> {
  /// The activator which triggers the the intent.
  final ShortcutActivator activator;

  /// The intent that is triggered bt the activator.
  final T intent;

  /// The action to run when the shortcut is invoked.
  final Object? Function(T, Terminal, TerminalController) action;

  const TerminalShortcut(this.activator, this.intent, this.action);

  /// Use the default modifier key for the current platform so assemble a
  /// key combination for the shortcut. On iOS the macOS the shortcut will be
  /// triggered my META + [key], otherwise CTRL + [key] triggers the shortcut.
  factory TerminalShortcut.platformDefault(
    LogicalKeyboardKey key,
    T intent,
    Object? Function(T, Terminal, TerminalController) action,
  ) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return TerminalShortcut(
          SingleActivator(key, control: true),
          intent,
          action,
        );
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return TerminalShortcut(
          SingleActivator(key, meta: true),
          intent,
          action,
        );
    }
  }

  /// Convert the shortcut to a [MapEntry] for passing it to an [Action] Widget.
  MapEntry<Type, Action<T>> toActionMapEntry(
    Terminal terminal,
    TerminalController terminalController,
  ) {
    return MapEntry(
      intent.runtimeType,
      CallbackAction<T>(
        onInvoke: (intent) => action(intent, terminal, terminalController),
      ),
    );
  }

  /// Generate a list of default shortcuts for the current platform.
  static List<TerminalShortcut> get defaults {
    return <TerminalShortcut>[
      TerminalShortcut<CopySelectionTextIntent>.platformDefault(
        LogicalKeyboardKey.keyC,
        CopySelectionTextIntent.copy,
        TerminalShortcut.defaultCopy,
      ),
      TerminalShortcut<PasteTextIntent>.platformDefault(
        LogicalKeyboardKey.keyV,
        const PasteTextIntent(SelectionChangedCause.keyboard),
        TerminalShortcut.defaultPaste,
      ),
      TerminalShortcut<SelectAllTextIntent>.platformDefault(
        LogicalKeyboardKey.keyA,
        const SelectAllTextIntent(SelectionChangedCause.keyboard),
        TerminalShortcut.defaultSelectAll,
      ),
    ];
  }

  /// Default handler for [CopySelectionTextIntent].
  static Object? defaultCopy(
    CopySelectionTextIntent intent,
    Terminal terminal,
    TerminalController controller,
  ) async {
    final selection = controller.selection;

    if (selection == null) {
      return null;
    }

    final text = terminal.buffer.getText(selection);

    await Clipboard.setData(ClipboardData(text: text));

    return null;
  }

  /// Default handler for [PasteTextIntent].
  static Object? defaultPaste(
    PasteTextIntent intent,
    Terminal terminal,
    TerminalController controller,
  ) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null) {
      terminal.paste(text);
      controller.clearSelection();
    }

    return null;
  }


  /// Default handler for [SelectAllTextIntent].
  static Object? defaultSelectAll(
    SelectAllTextIntent intent,
    Terminal terminal,
    TerminalController controller,
  ) async {
    controller.setSelection(
      BufferRangeLine(
        CellOffset(0, terminal.buffer.height - terminal.viewHeight),
        CellOffset(terminal.viewWidth, terminal.buffer.height - 1),
      ),
    );
    return null;
  }
}
