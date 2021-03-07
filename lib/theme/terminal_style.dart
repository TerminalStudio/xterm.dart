import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class TerminalStyle {
  static const defaultFontFamily = [
    'Monaco',
    'Droid Sans Mono',
    'Noto Sans Mono',
    'Roboto Mono',
    'Consolas',
    'Noto Sans Mono CJK SC',
    'Noto Sans Mono CJK TC',
    'Noto Sans Mono CJK KR',
    'Noto Sans Mono CJK JP',
    'Noto Sans Mono CJK HK',
    'Noto Color Emoji',
    'Noto Sans Symbols',
    'Roboto',
    'Ubuntu',
    'Cantarell',
    'DejaVu Sans',
    'Liberation Sans',
    'Arial',
    'Droid Sans Fallback',
    'Cascadia Mono',
    'Arial Unicode MS',
    'sans-serif',
    'monospace',
  ];

  const TerminalStyle({
    this.fontFamily = defaultFontFamily,
    this.fontSize = 14,
    this.fontWidthScaleFactor = 1.0,
    this.fontHeightScaleFactor = 1.1,
    this.textStyleProvider,
  });

  final List<String> fontFamily;
  final double fontSize;
  final double fontWidthScaleFactor;
  final double fontHeightScaleFactor;
  final TextStyleProvider? textStyleProvider;
}

typedef TextStyleProvider = Function({
  TextStyle textStyle,
  Color color,
  Color backgroundColor,
  double fontSize,
  FontWeight fontWeight,
  FontStyle fontStyle,
  double letterSpacing,
  double wordSpacing,
  TextBaseline textBaseline,
  double height,
  Locale locale,
  Paint foreground,
  Paint background,
  List<ui.Shadow> shadows,
  List<ui.FontFeature> fontFeatures,
  TextDecoration decoration,
  Color decorationColor,
  TextDecorationStyle decorationStyle,
  double decorationThickness,
});
