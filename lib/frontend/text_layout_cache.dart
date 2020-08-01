import 'package:flutter/painting.dart';
import 'package:quiver/collection.dart';

class TextLayoutCache {
  final LruMap<TextSpan, TextPainter> _cache;
  final TextDirection textDirection;

  TextLayoutCache(this.textDirection, int maximumSize) : _cache = LruMap<TextSpan, TextPainter>(maximumSize: maximumSize);

  TextPainter getOrPerformLayout(TextSpan text) {
    final cachedPainter = _cache[text];
    if (cachedPainter != null) {
      return cachedPainter;
    } else {
      return _performAndCacheLayout(text);
    }
  }

  TextPainter _performAndCacheLayout(TextSpan text) {
    final textPainter = TextPainter(text: text, textDirection: textDirection);
    textPainter.layout();

    _cache[text] = textPainter;

    return textPainter;
  }
}