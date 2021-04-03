extension BitFlags on int {
  bool hasFlag(int flag) {
    return this & flag != 0;
  }
}
