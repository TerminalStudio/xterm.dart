class AnsiColor {
  static String red(Object text) {
    return '\x1b[31m$text\x1b[39m';
  }

  static String green(Object text) {
    return '\x1b[32m$text\x1b[39m';
  }

  static String yellow(Object text) {
    return '\x1b[33m$text\x1b[39m';
  }

  static String blue(Object text) {
    return '\x1b[34m$text\x1b[39m';
  }

  static String magenta(Object text) {
    return '\x1b[35m$text\x1b[39m';
  }

  static String cyan(Object text) {
    return '\x1b[36m$text\x1b[39m';
  }
}
