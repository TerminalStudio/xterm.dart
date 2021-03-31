class TerminalColor {
  static int empty() {
    return 0xFF000000;
  }

  static int transparent = 0x00000000;

  static int fromARGB(int a, int r, int g, int b) {
    return (((a & 0xff) << 24) |
            ((r & 0xff) << 16) |
            ((g & 0xff) << 8) |
            ((b & 0xff) << 0)) &
        0xFFFFFFFF;
  }
}
