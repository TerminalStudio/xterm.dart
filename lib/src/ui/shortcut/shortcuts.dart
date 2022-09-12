import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:xterm/src/ui/shortcut/intents.dart';

Map<ShortcutActivator, Intent> get defaultTerminalShortcuts {
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.windows:
      return _defaultShortcuts;
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return _defaultAppleShortcuts;
  }
}

final _defaultShortcuts = {
  SingleActivator(LogicalKeyboardKey.keyC, control: true):
      const TerminalCopyIntent(),
  SingleActivator(LogicalKeyboardKey.keyV, control: true):
      const TerminalPasteIntent(),
  SingleActivator(LogicalKeyboardKey.keyA, control: true):
      const TerminalSelectAllIntent(),
};

final _defaultAppleShortcuts = {
  SingleActivator(LogicalKeyboardKey.keyC, meta: true):
      const TerminalCopyIntent(),
  SingleActivator(LogicalKeyboardKey.keyV, meta: true):
      const TerminalPasteIntent(),
  SingleActivator(LogicalKeyboardKey.keyA, meta: true):
      const TerminalSelectAllIntent(),
};
