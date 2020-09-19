import 'dart:io';

import 'package:xterm/frontend/input_behavior.dart';
import 'package:xterm/frontend/input_behavior_desktop.dart';
import 'package:xterm/frontend/input_behavior_mobile.dart';

class InputBehaviors {
  static const desktop = InputBehaviorDesktop();

  static const mobile = InputBehaviorMobile();

  static InputBehavior get platform {
    if (Platform.isAndroid || Platform.isIOS) {
      return mobile;
    }

    return desktop;
  }
}
