import 'dart:io';

abstract class TestFixtures {
  static String htop_80x25_3s() {
    return File('test/_fixture/htop_80x25_3s.txt').readAsStringSync();
  }
}
