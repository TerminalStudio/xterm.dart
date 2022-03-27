import 'package:flutter/widgets.dart';

class KeyboardVisibilty extends StatefulWidget {
  const KeyboardVisibilty(
      {Key? key, required this.child, this.onKeyboardShow, this.onKeyboardHide})
      : super(key: key);

  final Widget child;

  final VoidCallback? onKeyboardShow;

  final VoidCallback? onKeyboardHide;

  static _KeyboardVisibiltyState? of(BuildContext context) {
    return context.findAncestorStateOfType<_KeyboardVisibiltyState>();
  }

  @override
  _KeyboardVisibiltyState createState() => _KeyboardVisibiltyState();
}

class _KeyboardVisibiltyState extends State<KeyboardVisibilty> {
  var _lastBottomInset = 0.0;

  final isVisible = ValueNotifier(false);

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;

    if (bottomInset != _lastBottomInset) {
      if (bottomInset > 0) {
        isVisible.value = true;
        widget.onKeyboardShow?.call();
      } else {
        isVisible.value = false;
        widget.onKeyboardHide?.call();
      }
    }

    _lastBottomInset = bottomInset;

    return widget.child;
  }
}
