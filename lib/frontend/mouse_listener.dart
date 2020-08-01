import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

typedef ScrollHandler = void Function(Offset);

class MouseListener extends StatelessWidget {
  MouseListener({this.child, this.onScroll});

  final Widget child;
  final ScrollHandler onScroll;

  @override
  Widget build(BuildContext context) {
    return Listener(
      child: child,
      onPointerSignal: onPointerSignal,
    );
  }

  void onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent && onScroll != null) {
      onScroll(event.scrollDelta);
    }
  }
}
