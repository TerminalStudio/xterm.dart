class TerminalColor {
  const TerminalColor(this.value);

  const TerminalColor.empty() : value = 0xFF000000;

  const TerminalColor.fromARGB(int a, int r, int g, int b)
      : value = (((a & 0xff) << 24) |
                ((r & 0xff) << 16) |
                ((g & 0xff) << 8) |
                ((b & 0xff) << 0)) &
            0xFFFFFFFF;

  final int value;
}
