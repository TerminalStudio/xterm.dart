import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:quiver/collection.dart';

class ParagraphCache {
  ParagraphCache(int maximumSize)
      : _cache = LruMap<int, Paragraph>(maximumSize: maximumSize);

  final LruMap<int, Paragraph> _cache;

  Paragraph? getLayoutFromCache(int key) {
    return _cache[key];
  }

  Paragraph performAndCacheLayout(String text, TextStyle style, int key) {
    final builder = ParagraphBuilder(style.getParagraphStyle());
    builder.pushStyle(style.getTextStyle());
    builder.addText(text);

    final paragraph = builder.build();
    paragraph.layout(ParagraphConstraints(width: double.infinity));

    _cache[key] = paragraph;
    return paragraph;
  }

  void clear() {
    _cache.clear();
  }

  int get length {
    return _cache.length;
  }
}
