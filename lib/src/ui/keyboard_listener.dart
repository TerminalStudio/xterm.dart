import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class CustomKeyboardListener extends StatelessWidget {
  final Widget child;

  final FocusNode focusNode;

  final bool autofocus;

  final void Function(String) onInsert;

  final void Function(String?) onComposing;

  final KeyEventResult Function(FocusNode, RawKeyEvent) onKey;

  const CustomKeyboardListener({
    Key? key,
    required this.child,
    required this.focusNode,
    this.autofocus = false,
    required this.onInsert,
    required this.onComposing,
    required this.onKey,
  }) : super(key: key);

  KeyEventResult _onKey(FocusNode focusNode, RawKeyEvent keyEvent) {
    // First try to handle the key event directly.
    final handled = onKey(focusNode, keyEvent);
    if (handled == KeyEventResult.ignored) {
      // If it was not handled, but the key corresponds to a character,
      // insert the character.
      if (keyEvent.character != null && keyEvent.character != "") {
        onInsert(keyEvent.character!);
        return KeyEventResult.handled;
      } else if (keyEvent.data is RawKeyEventDataIos &&
          keyEvent is RawKeyDownEvent) {
        // On iOS keyEvent.character is always null. But data.characters
        // contains the the character(s) corresponding to the input.
        final data = keyEvent.data as RawKeyEventDataIos;
        if (data.characters != "") {
          onComposing(null);
          onInsert(data.characters);
        } else if (data.charactersIgnoringModifiers != "") {
          // If characters is an empty string but charactersIgnoringModifiers is
          // not an empty string, this indicates that the current characters is
          // being composed. The current composing state is
          // charactersIgnoringModifiers.
          onComposing(data.charactersIgnoringModifiers);
        }
      }
    }
    return handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      autofocus: autofocus,
      onKey: _onKey,
      child: child,
    );
  }
}
