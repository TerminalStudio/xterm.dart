import 'dart:ui';

import 'package:flutter/widgets.dart';

class KeyboardVisibilty extends StatefulWidget {
  const KeyboardVisibilty({
    Key? key,
    required this.child,
    this.onKeyboardShow,
    this.onKeyboardHide,
  }) : super(key: key);

  final Widget child;

  final VoidCallback? onKeyboardShow;

  final VoidCallback? onKeyboardHide;

  @override
  _KeyboardVisibiltyState createState() => _KeyboardVisibiltyState();
}

class _KeyboardVisibiltyState extends State<KeyboardVisibilty>
    with WidgetsBindingObserver {
  
  T? _nonNullableWrap<T>(T? value) => value;
  
  @override
  void initState() {
    super.initState();
    _nonNullableWrap(WidgetsBinding.instance)!.addObserver(this);
  }

  @override
  void dispose() {
    _nonNullableWrap(WidgetsBinding.instance)!.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final bottomInset = window.viewInsets.bottom;

    if (bottomInset != _lastBottomInset) {
      if (bottomInset > 0) {
        widget.onKeyboardShow?.call();
      } else {
        widget.onKeyboardHide?.call();
      }
    }

    _lastBottomInset = bottomInset;

    super.didChangeMetrics();
  }

  var _lastBottomInset = 0.0;

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
