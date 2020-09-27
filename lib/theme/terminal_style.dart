class TerminalStyle {
  static const defaultFontFamily = [
    'Droid Sans Mono',
    'Noto Sans Mono',
    'Roboto Mono',
    'Consolas',
    'Noto Sans Mono CJK SC',
    'Noto Sans Mono CJK TC',
    'Noto Sans Mono CJK KR',
    'Noto Sans Mono CJK JP',
    'Noto Sans Mono CJK HK',
    'monospace',
    'Noto Color Emoji',
    'Noto Sans Symbols',
    'Roboto',
    'Ubuntu',
    'Cantarell',
    'DejaVu Sans',
    'Liberation Sans',
    'Arial',
    'Droid Sans Fallback',
    'sans-serif',
  ];

  const TerminalStyle({
    this.fontFamily = defaultFontFamily,
    this.fontSize = 14,
    this.fontWidthScaleFactor = 1.0,
    this.fontHeightScaleFactor = 1.1,
  });

  final List<String> fontFamily;
  final double fontSize;
  final double fontWidthScaleFactor;
  final double fontHeightScaleFactor;
}
