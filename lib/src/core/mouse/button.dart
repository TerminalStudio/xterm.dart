enum TerminalMouseButton {
  left,

  middle,

  right,

  wheelUp,

  wheelDown,

  wheelLeft,

  wheelRight,
}

extension ButtonIDExtension on TerminalMouseButton {
  /// The id that is used to report a button press or release to the terminal.
  int get id {
    switch (this) {
      case TerminalMouseButton.left:
      case TerminalMouseButton.middle:
      case TerminalMouseButton.right:
        return index;
      // Mouse wheel up / down use button IDs 4 = 0100 (binary) and
      // 5 = 0101 (binary). The bits three and four of the button
      // are transposed by 64 and 128 respectively, when reporting the id of
      // the button and have have to be adjusted correspondingly.
      case TerminalMouseButton.wheelUp:
        return 64 + 4;
      case TerminalMouseButton.wheelDown:
        return 64 + 5;
      case TerminalMouseButton.wheelLeft:
        return 64 + 6;
      case TerminalMouseButton.wheelRight:
        return 64 + 7;
    }
  }

  /// True if the button belongs to a wheel.
  bool get isWheel {
    return TerminalMouseButton.wheelUp.index <= index &&
        index <= TerminalMouseButton.wheelRight.index;
  }
}
