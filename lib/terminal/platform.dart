class PlatformBehavior {
  const PlatformBehavior({
    required this.oscTerminators,
    required this.useMacInputBehavior,
  });

  final Set<int> oscTerminators;
  final bool useMacInputBehavior;
}

class PlatformBehaviors {
  static const mac = PlatformBehavior(
    oscTerminators: {0x07, 0x5c},
    useMacInputBehavior: true,
  );

  static const unix = PlatformBehavior(
    oscTerminators: {0x07, 0x5c},
    useMacInputBehavior: false,
  );

  static const windows = PlatformBehavior(
    oscTerminators: {0x07, 0x00},
    useMacInputBehavior: false,
  );
}
