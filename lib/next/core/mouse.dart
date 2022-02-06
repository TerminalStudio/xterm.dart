/// https://terminalguide.namepad.de/mouse/
enum MouseMode {
  none,

  clickOnly,

  upDownScroll,

  upDownScrollDrag,

  upDownScrollMove,
}

/// https://terminalguide.namepad.de/mouse/
enum MouseReportMode {
  normal,

  utf,

  sgr,

  urxvt,
}
