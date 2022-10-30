import 'package:xterm/src/core/input/keys.dart';
import 'package:xterm/src/core/input/keytab/keytab.dart';
import 'package:xterm/src/utils/platform.dart';
import 'package:xterm/src/core/state.dart';

/// The key event received from the keyboard, along with the state of the
/// modifier keys and state of the terminal. Typically consumed by the
/// [TerminalInputHandler] to produce a escape sequence that can be recognized
/// by the terminal.
///
/// See also:
/// - [TerminalInputHandler]
class TerminalKeyboardEvent {
  final TerminalKey key;

  final bool shift;

  final bool ctrl;

  final bool alt;

  final TerminalState state;

  final bool altBuffer;

  final TerminalTargetPlatform platform;

  TerminalKeyboardEvent({
    required this.key,
    required this.shift,
    required this.ctrl,
    required this.alt,
    required this.state,
    required this.altBuffer,
    required this.platform,
  });

  TerminalKeyboardEvent copyWith({
    TerminalKey? key,
    bool? shift,
    bool? ctrl,
    bool? alt,
    TerminalState? state,
    bool? altBuffer,
    TerminalTargetPlatform? platform,
  }) {
    return TerminalKeyboardEvent(
      key: key ?? this.key,
      shift: shift ?? this.shift,
      ctrl: ctrl ?? this.ctrl,
      alt: alt ?? this.alt,
      state: state ?? this.state,
      altBuffer: altBuffer ?? this.altBuffer,
      platform: platform ?? this.platform,
    );
  }
}

/// TerminalInputHandler contains the logic for translating a [TerminalKeyboardEvent]
/// into escape sequences that can be recognized by the terminal.
abstract class TerminalInputHandler {
  /// Translates a [TerminalKeyboardEvent] into an escape sequence. If the event
  /// cannot be translated, null is returned.
  String? call(TerminalKeyboardEvent event);
}

/// A [TerminalInputHandler] that chains multiple handlers together. If any
/// handler returns a non-null value, it is returned. Otherwise, null is
/// returned.
class CascadeInputHandler implements TerminalInputHandler {
  final List<TerminalInputHandler> _handlers;

  const CascadeInputHandler(this._handlers);

  @override
  String? call(TerminalKeyboardEvent event) {
    for (var handler in _handlers) {
      final result = handler(event);
      if (result != null) {
        return result;
      }
    }
    return null;
  }
}

/// The default input handler for the terminal. That is composed of a
/// [KeytabInputHandler], a [CtrlInputHandler], and a [AltInputHandler].
///
/// It's possible to override the default input handler behavior by chaining
/// another input handler before or after the default input handler using
/// [CascadeInputHandler].
///
/// See also:
///  * [CascadeInputHandler]
const defaultInputHandler = CascadeInputHandler([
  KeytabInputHandler(),
  CtrlInputHandler(),
  AltInputHandler(),
]);

final _keytab = Keytab.defaultKeytab();

/// A [TerminalInputHandler] that translates key events according to a keytab
/// file.
class KeytabInputHandler implements TerminalInputHandler {
  const KeytabInputHandler();

  @override
  String? call(TerminalKeyboardEvent event) {
    final action = _keytab.find(
      event.key,
      ctrl: event.ctrl,
      alt: event.alt,
      shift: event.shift,
      newLineMode: event.state.lineFeedMode,
      appCursorKeys: event.state.appKeypadMode,
      appKeyPad: event.state.appKeypadMode,
      appScreen: event.altBuffer,
      macos: event.platform == TerminalTargetPlatform.macos,
    );

    if (action == null) {
      return null;
    }

    return action.action.unescapedValue();
  }
}

/// A [TerminalInputHandler] that translates ctrl + key events into escape
/// sequences. For example, ctrl + a becomes ^A.
class CtrlInputHandler implements TerminalInputHandler {
  const CtrlInputHandler();

  @override
  String? call(TerminalKeyboardEvent event) {
    if (!event.ctrl || event.shift || event.alt) {
      return null;
    }

    final key = event.key;

    if (key.index >= TerminalKey.keyA.index &&
        key.index <= TerminalKey.keyZ.index) {
      final input = key.index - TerminalKey.keyA.index + 1;
      return String.fromCharCode(input);
    }

    return null;
  }
}

/// A [TerminalInputHandler] that translates alt + key events into escape
/// sequences. For example, alt + a becomes ^[a.
class AltInputHandler implements TerminalInputHandler {
  const AltInputHandler();

  @override
  String? call(TerminalKeyboardEvent event) {
    if (!event.alt || event.ctrl || event.shift) {
      return null;
    }

    if (event.platform == TerminalTargetPlatform.macos) {
      return null;
    }

    final key = event.key;

    if (key.index >= TerminalKey.keyA.index &&
        key.index <= TerminalKey.keyZ.index) {
      final charCode = key.index - TerminalKey.keyA.index + 65;
      final input = [0x1b, charCode];
      return String.fromCharCodes(input);
    }

    return null;
  }
}
