import 'package:platform_info/platform_info.dart';
import 'package:xterm/frontend/input_behavior.dart';
import 'package:xterm/frontend/input_behavior_desktop.dart';
import 'package:xterm/frontend/input_behavior_mobile.dart';

class InputBehaviors {
  static final desktop = InputBehaviorDesktop();

  static final mobile = InputBehaviorMobile();

  static InputBehavior get platform {
    if (Platform.I.isMobile) {
      return mobile;
    }

    return desktop;
  }
}
