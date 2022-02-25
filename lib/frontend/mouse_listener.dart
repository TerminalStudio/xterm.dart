import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

typedef ScrollHandler = void Function(Offset);

class MouseListener extends StatelessWidget {
  const MouseListener({
    required this.child,
    required this.onScroll,
    Key? key,
  }) : super(key: key);

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
    if (event is PointerScrollEvent) {
      onScroll(event.scrollDelta);
    }
  }
}
