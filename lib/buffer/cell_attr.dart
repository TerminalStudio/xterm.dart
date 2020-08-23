import 'package:meta/meta.dart';
import 'package:xterm/buffer/cell_color.dart';

class CellAttr {
  CellAttr({
    @required this.fgColor,
    this.bgColor,
    this.bold = false,
    this.faint = false,
    this.italic = false,
    this.underline = false,
    this.blink = false,
    this.inverse = false,
    this.invisible = false,
  });

  CellColor fgColor;
  CellColor bgColor;
  bool bold;
  bool faint;
  bool italic;
  bool underline;
  bool blink;
  bool inverse;
  bool invisible;

  CellAttr copy() {
    return CellAttr(
      fgColor: this.fgColor,
      bgColor: this.bgColor,
      bold: this.bold,
      faint: this.faint,
      italic: this.italic,
      underline: this.underline,
      blink: this.blink,
      inverse: this.inverse,
      invisible: this.invisible,
    );
  }

  void reset({
    @required fgColor,
    bgColor,
    bold = false,
    faint = false,
    italic = false,
    underline = false,
    blink = false,
    inverse = false,
    invisible = false,
  }) {
    this.fgColor = fgColor;
    this.bgColor = bgColor;
    this.bold = bold;
    this.faint = faint;
    this.italic = italic;
    this.underline = underline;
    this.blink = blink;
    this.inverse = inverse;
    this.invisible = invisible;
  }

  CellAttr copyWith({
    CellColor fgColor,
    CellColor bgColor,
    bool bold,
    bool faint,
    bool italic,
    bool underline,
    bool blink,
    bool inverse,
    bool invisible,
  }) {
    return CellAttr(
      fgColor: fgColor ?? this.fgColor,
      bgColor: bgColor ?? this.bgColor,
      bold: bold ?? this.bold,
      faint: faint ?? this.faint,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      blink: blink ?? this.blink,
      inverse: inverse ?? this.inverse,
      invisible: invisible ?? this.invisible,
    );
  }
}

class CellAttrTemplate {
  CellAttrTemplate();
  
  CellAttr _attr;

  set fgColor(CellColor value) {
    _attr = _attr.copyWith(fgColor: value);
  }

  set bgColor(CellColor value) {
    _attr = _attr.copyWith(bgColor: value);
  }

  set bold(bool value) {
    _attr = _attr.copyWith(bold: value);
  }

  set faint(bool value) {
    _attr = _attr.copyWith(faint: value);
  }

  set italic(bool value) {
    _attr = _attr.copyWith(italic: value);
  }

  set underline(bool value) {
    _attr = _attr.copyWith(underline: value);
  }

  set blink(bool value) {
    _attr = _attr.copyWith(blink: value);
  }

  set inverse(bool value) {
    _attr = _attr.copyWith(inverse: value);
  }

  set invisible(bool value) {
    _attr = _attr.copyWith(invisible: value);
  }

  CellAttr get value {}
}
