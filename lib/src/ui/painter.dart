import 'dart:ui';
import 'package:flutter/painting.dart';

import 'package:xterm/src/ui/palette_builder.dart';
import 'package:xterm/src/ui/paragraph_cache.dart';
import 'package:xterm/xterm.dart';

/// Encapsulates the logic for painting various terminal elements.
class TerminalPainter {
  TerminalPainter({
    required TerminalTheme theme,
    required TerminalStyle textStyle,
    required TextScaler textScaler,
  })  : _textStyle = textStyle,
        _theme = theme,
        _textScaler = textScaler;

  /// A lookup table from terminal colors to Flutter colors.
  late var _colorPalette = PaletteBuilder(_theme).build();

  /// Size of each character in the terminal.
  late var _cellSize = _measureCharSize();

  /// The cached for cells in the terminal. Should be cleared when the same
  /// cell no longer produces the same visual output. For example, when
  /// [_textStyle] is changed, or when the system font changes.
  final _paragraphCache = ParagraphCache(10240);

  TerminalStyle get textStyle => _textStyle;
  TerminalStyle _textStyle;
  set textStyle(TerminalStyle value) {
    if (value == _textStyle) return;
    _textStyle = value;
    _cellSize = _measureCharSize();
    _paragraphCache.clear();
  }

  TextScaler get textScaler => _textScaler;
  TextScaler _textScaler = TextScaler.linear(1.0);
  set textScaler(TextScaler value) {
    if (value == _textScaler) return;
    _textScaler = value;
    _cellSize = _measureCharSize();
    _paragraphCache.clear();
  }

  TerminalTheme get theme => _theme;
  TerminalTheme _theme;
  set theme(TerminalTheme value) {
    if (value == _theme) return;
    _theme = value;
    _colorPalette = PaletteBuilder(value).build();
    _paragraphCache.clear();
  }

  Size _measureCharSize() {
    const test = 'mmmmmmmmmm';

    final textStyle = _textStyle.toTextStyle();
    final builder = ParagraphBuilder(textStyle.getParagraphStyle());
    builder.pushStyle(
      textStyle.getTextStyle(textScaler: _textScaler),
    );
    builder.addText(test);

    final paragraph = builder.build();
    paragraph.layout(ParagraphConstraints(width: double.infinity));

    final result = Size(
      paragraph.maxIntrinsicWidth / test.length,
      paragraph.height,
    );

    paragraph.dispose();
    return result;
  }

  /// The size of each character in the terminal.
  Size get cellSize => _cellSize;

  /// When the set of font available to the system changes, call this method to
  /// clear cached state related to font rendering.
  void clearFontCache() {
    _cellSize = _measureCharSize();
    _paragraphCache.clear();
  }

  /// Paints the cursor based on the current cursor type.
  void paintCursor(
    Canvas canvas,
    Offset offset, {
    required TerminalCursorType cursorType,
    bool hasFocus = true,
  }) {
    final paint = Paint()
      ..color = _theme.cursor
      ..strokeWidth = 1;

    if (!hasFocus) {
      paint.style = PaintingStyle.stroke;
      canvas.drawRect(offset & _cellSize, paint);
      return;
    }

    switch (cursorType) {
      case TerminalCursorType.block:
        paint.style = PaintingStyle.fill;
        canvas.drawRect(offset & _cellSize, paint);
        return;
      case TerminalCursorType.underline:
        return canvas.drawLine(
          Offset(offset.dx, _cellSize.height - 1),
          Offset(offset.dx + _cellSize.width, _cellSize.height - 1),
          paint,
        );
      case TerminalCursorType.verticalBar:
        return canvas.drawLine(
          Offset(offset.dx, 0),
          Offset(offset.dx, _cellSize.height),
          paint,
        );
    }
  }

  @pragma('vm:prefer-inline')
  void paintHighlight(Canvas canvas, Offset offset, int length, Color color) {
    final endOffset =
        offset.translate(length * _cellSize.width, _cellSize.height);

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    canvas.drawRect(
      Rect.fromPoints(offset, endOffset),
      paint,
    );
  }

  /// Paints [line] to [canvas] at [offset]. The x offset of [offset] is usually
  /// 0, and the y offset is the top of the line.
  void paintLine(
    Canvas canvas,
    Offset offset,
    BufferLine line,
  ) {
    final cellData = CellData.empty();
    final cellWidth = _cellSize.width;

    if (_textStyle.ligatures) {
      // When ligatures are enabled, group cells with the same style to allow ligature formation
      int i = 0;
      while (i < line.length) {
        line.getCellData(i, cellData);
        final start = i;
        final style = _getCellTextStyle(cellData);

        // Find the end of the segment with the same style
        i++;
        while (i < line.length) {
          line.getCellData(i, cellData);
          if (!_textStylesEqual(style, _getCellTextStyle(cellData))) {
            break;
          }
          i++;
        }

        // Paint the segment
        _paintCellSegment(canvas, offset, line, start, i, style);
      }
    } else {
      // Original behavior: paint each cell individually
      for (var i = 0; i < line.length; i++) {
        line.getCellData(i, cellData);

        final charWidth = cellData.content >> CellContent.widthShift;
        final cellOffset = offset.translate(i * cellWidth, 0);

        paintCell(canvas, cellOffset, cellData);

        if (charWidth == 2) {
          i++;
        }
      }
    }
  }

  @pragma('vm:prefer-inline')
  void paintCell(Canvas canvas, Offset offset, CellData cellData) {
    paintCellBackground(canvas, offset, cellData);
    paintCellForeground(canvas, offset, cellData);
  }

  TextStyle _getCellTextStyle(CellData cellData) {
    final cellFlags = cellData.flags;

    var color = cellFlags & CellFlags.inverse == 0
        ? resolveForegroundColor(cellData.foreground)
        : resolveBackgroundColor(cellData.background);

    if (cellData.flags & CellFlags.faint != 0) {
      color = color.withValues(alpha: 0.5);
    }

    return _textStyle.toTextStyle(
      color: color,
      bold: cellFlags & CellFlags.bold != 0,
      italic: cellFlags & CellFlags.italic != 0,
      underline: cellFlags & CellFlags.underline != 0,
    );
  }

  bool _textStylesEqual(TextStyle a, TextStyle b) {
    // Compare font features more carefully since they're lists
    final fontFeaturesEqual =
        (a.fontFeatures == null && b.fontFeatures == null) ||
            (a.fontFeatures != null &&
                b.fontFeatures != null &&
                a.fontFeatures!.length == b.fontFeatures!.length &&
                a.fontFeatures!
                    .every((feature) => b.fontFeatures!.contains(feature)));

    return a.color == b.color &&
        a.fontWeight == b.fontWeight &&
        a.fontStyle == b.fontStyle &&
        a.decoration == b.decoration &&
        a.fontFamily == b.fontFamily &&
        a.fontFamilyFallback == b.fontFamilyFallback &&
        a.fontSize == b.fontSize &&
        a.height == b.height &&
        fontFeaturesEqual;
  }

  void _paintCellSegment(Canvas canvas, Offset lineOffset, BufferLine line,
      int start, int end, TextStyle style) {
    final cellData = CellData.empty();
    final cellWidth = _cellSize.width;
    final buffer = StringBuffer();

    for (int i = start; i < end; i++) {
      line.getCellData(i, cellData);
      final charCode = cellData.content & CellContent.codepointMask;
      final cellFlags = cellData.flags;
      final charWidth = cellData.content >> CellContent.widthShift;

      if (charCode != 0) {
        var char = String.fromCharCode(charCode);
        if (cellFlags & CellFlags.underline != 0 && charCode == 0x20) {
          char = String.fromCharCode(0xA0);
        }
        buffer.write(char);
      } else {
        buffer.write(' '); // For empty cells
      }

      // Paint background for each cell
      final cellOffset = lineOffset.translate(i * cellWidth, 0);
      paintCellBackground(canvas, cellOffset, cellData);

      if (charWidth == 2) {
        i++; // Skip the next cell for wide characters
      }
    }

    final text = buffer.toString();
    if (text.isNotEmpty) {
      final segmentOffset = lineOffset.translate(start * cellWidth, 0);
      final cacheKey = text.hashCode ^ style.hashCode ^ _textScaler.hashCode;
      var paragraph = _paragraphCache.getLayoutFromCache(cacheKey);

      if (paragraph == null) {
        paragraph = _paragraphCache.performAndCacheLayout(
          text,
          style,
          _textScaler,
          double.infinity,
          cacheKey,
        );
      }

      canvas.drawParagraph(paragraph, segmentOffset);
    }
  }

  /// Paints the character in the cell represented by [cellData] to [canvas] at
  /// [offset].
  @pragma('vm:prefer-inline')
  void paintCellForeground(Canvas canvas, Offset offset, CellData cellData) {
    final charCode = cellData.content & CellContent.codepointMask;
    if (charCode == 0) return;

    final cacheKey =
        cellData.getHash() ^ _textScaler.hashCode ^ _cellSize.width.hashCode;
    var paragraph = _paragraphCache.getLayoutFromCache(cacheKey);

    if (paragraph == null) {
      final cellFlags = cellData.flags;
      final style = _getCellTextStyle(cellData);

      // Flutter does not draw an underline below a space which is not between
      // other regular characters. As only single characters are drawn, this
      // will never produce an underline below a space in the terminal. As a
      // workaround the regular space CodePoint 0x20 is replaced with
      // the CodePoint 0xA0. This is a non breaking space and a underline can be
      // drawn below it.
      var char = String.fromCharCode(charCode);
      if (cellFlags & CellFlags.underline != 0 && charCode == 0x20) {
        char = String.fromCharCode(0xA0);
      }

      paragraph = _paragraphCache.performAndCacheLayout(
        char,
        style,
        _textScaler,
        _cellSize.width,
        cacheKey,
      );
    }

    canvas.drawParagraph(paragraph, offset);
  }

  /// Paints the background of a cell represented by [cellData] to [canvas] at
  /// [offset].
  @pragma('vm:prefer-inline')
  void paintCellBackground(Canvas canvas, Offset offset, CellData cellData) {
    late Color color;
    final colorType = cellData.background & CellColor.typeMask;

    if (cellData.flags & CellFlags.inverse != 0) {
      color = resolveForegroundColor(cellData.foreground);
    } else if (colorType == CellColor.normal) {
      return;
    } else {
      color = resolveBackgroundColor(cellData.background);
    }

    final paint = Paint()..color = color;
    final doubleWidth = cellData.content >> CellContent.widthShift == 2;
    final widthScale = doubleWidth ? 2 : 1;
    final size = Size(_cellSize.width * widthScale + 1, _cellSize.height);
    canvas.drawRect(offset & size, paint);
  }

  /// Get the effective foreground color for a cell from information encoded in
  /// [cellColor].
  @pragma('vm:prefer-inline')
  Color resolveForegroundColor(int cellColor) {
    final colorType = cellColor & CellColor.typeMask;
    final colorValue = cellColor & CellColor.valueMask;

    switch (colorType) {
      case CellColor.normal:
        return _theme.foreground;
      case CellColor.named:
      case CellColor.palette:
        return _colorPalette[colorValue];
      case CellColor.rgb:
      default:
        return Color(colorValue | 0xFF000000);
    }
  }

  /// Get the effective background color for a cell from information encoded in
  /// [cellColor].
  @pragma('vm:prefer-inline')
  Color resolveBackgroundColor(int cellColor) {
    final colorType = cellColor & CellColor.typeMask;
    final colorValue = cellColor & CellColor.valueMask;

    switch (colorType) {
      case CellColor.normal:
        return _theme.background;
      case CellColor.named:
      case CellColor.palette:
        return _colorPalette[colorValue];
      case CellColor.rgb:
      default:
        return Color(colorValue | 0xFF000000);
    }
  }
}
