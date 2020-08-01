class CellColor {
  const CellColor(this.value);
  const CellColor.empty() : value = 0xFF000000;
  const CellColor.fromARGB(int a, int r, int g, int b)
      : value = (((a & 0xff) << 24) |
                ((r & 0xff) << 16) |
                ((g & 0xff) << 8) |
                ((b & 0xff) << 0)) &
            0xFFFFFFFF;

  final int value;
}
