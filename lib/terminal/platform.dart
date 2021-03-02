class PlatformBehavior {
  const PlatformBehavior({required this.oscTerminators});

  final Set<int> oscTerminators;
}

class PlatformBehaviors {
  static const unix = PlatformBehavior(oscTerminators: {0x07, 0x5c});
  static const windows = PlatformBehavior(oscTerminators: {0x07, 0x00});
}
