import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xterm/src/ui/render.dart';
import 'package:xterm/xterm.dart';

class _View {
  _View(this.tester, this.terminal, this.controller, this.output);

  final WidgetTester tester;
  final Terminal terminal;
  final TerminalController controller;
  final List<String> output;

  String? get selectedText {
    final selection = controller.selection;
    if (selection == null) return null;
    return terminal.buffer.getText(selection).trim();
  }

  Offset offsetOf(int column, int row) {
    final view = tester.getTopLeft(find.byType(TerminalView));
    final render = tester.renderObject(find.byType(TerminalView));
    final width = render.paintBounds.width / terminal.viewWidth;
    final height = render.paintBounds.height / terminal.viewHeight;
    return view + Offset((column + 0.5) * width, (row + 0.5) * height);
  }

  Future<void> chord(
    List<LogicalKeyboardKey> held,
    LogicalKeyboardKey key,
  ) async {
    for (final k in held) {
      await tester.sendKeyDownEvent(k);
    }
    await tester.sendKeyEvent(key);
    for (final k in held.reversed) {
      await tester.sendKeyUpEvent(k);
    }
    await tester.pump();
  }
}

Future<_View> _pump(
  WidgetTester tester, {
  String content = '',
  TerminalTargetPlatform platform = TerminalTargetPlatform.linux,
}) async {
  final output = <String>[];
  final terminal = Terminal(platform: platform, onOutput: output.add);
  final controller = TerminalController();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TerminalView(terminal, controller: controller, autofocus: true),
      ),
    ),
  );
  terminal.write(content);
  await tester.pump();
  return _View(tester, terminal, controller, output);
}

RenderTerminal _render(WidgetTester tester) =>
    tester.renderObject<RenderTerminal>(
      find.descendant(
        of: find.byType(TerminalView),
        matching: find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_TerminalView',
        ),
      ),
    );

void main() {
  group('TerminalView', () {
    testWidgets('lays out left to right in a right-to-left app', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: TerminalView(Terminal())),
          ),
        ),
      );
      final inside = tester.element(
        find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_TerminalView',
        ),
      );
      expect(Directionality.of(inside), TextDirection.ltr);
    });

    testWidgets('Ctrl+A and Ctrl+X reach the shell', (tester) async {
      final view = await _pump(tester, content: 'some text');
      await view.chord([
        LogicalKeyboardKey.controlLeft,
      ], LogicalKeyboardKey.keyA);
      await view.chord([
        LogicalKeyboardKey.controlLeft,
      ], LogicalKeyboardKey.keyX);
      expect(view.output, ['\x01', '\x18']);
      expect(view.controller.selection, isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('Ctrl+Shift+A selects everything without asserting', (
      tester,
    ) async {
      final view = await _pump(tester, content: 'some text');
      await view.chord([
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.shiftLeft,
      ], LogicalKeyboardKey.keyA);
      expect(view.selectedText, 'some text');
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('a paste with no onPaste goes to the terminal at once', (
      tester,
    ) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => call.method == 'Clipboard.getData'
            ? <String, dynamic>{'text': 'PASTED'}
            : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final view = await _pump(tester);
      await view.chord([
        LogicalKeyboardKey.controlLeft,
      ], LogicalKeyboardKey.keyV);
      await tester.pump();
      expect(view.output, ['PASTED']);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('Alt with a key that types a character sends ESC first', (
      tester,
    ) async {
      final view = await _pump(tester);
      await view.chord([LogicalKeyboardKey.altLeft], LogicalKeyboardKey.period);
      expect(view.output, ['\x1b.']);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('a shift click backwards keeps the end of the selection', (
      tester,
    ) async {
      final view = await _pump(tester, content: 'alpha beta gamma');

      final drag = await tester.startGesture(
        view.offsetOf(6, 0),
        kind: PointerDeviceKind.mouse,
      );
      await drag.moveTo(view.offsetOf(10, 0));
      await tester.pump();
      await drag.up();
      await tester.pump(kDoubleTapTimeout);
      expect(view.selectedText, 'beta');

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      final click = await tester.startGesture(
        view.offsetOf(2, 0),
        kind: PointerDeviceKind.mouse,
      );
      await click.up();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump(kDoubleTapTimeout);

      expect(view.selectedText, 'pha beta');
    });

    testWidgets('a touch long press in a mouse mode is released', (
      tester,
    ) async {
      final view = await _pump(tester, content: '\x1b[?1000h\x1b[?1006hab');

      final press = await tester.startGesture(
        view.offsetOf(2, 0),
        kind: PointerDeviceKind.touch,
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await press.up();
      await tester.pump(kDoubleTapTimeout);

      final presses = view.output.where((o) => o.endsWith('M')).length;
      final releases = view.output.where((o) => o.endsWith('m')).length;
      expect(releases, presses);
    });

    testWidgets('a height that animates resizes once, when it settles', (
      tester,
    ) async {
      final sizes = <(int, int)>[];
      final terminal = Terminal(onResize: (w, h, _, _) => sizes.add((w, h)));
      final height = ValueNotifier(600.0);
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder(
            valueListenable: height,
            builder: (_, value, _) => Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 400,
                height: value,
                child: TerminalView(terminal),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final rows = terminal.viewHeight;
      expect(sizes, [(terminal.viewWidth, rows)]);

      // A soft keyboard's inset, a step every frame.
      for (var i = 0; i < 10; i++) {
        height.value -= 30;
        await tester.pump(const Duration(milliseconds: 16));
        expect(terminal.viewHeight, rows);
      }
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));

      final cell = _render(tester).cellSize;
      expect(sizes, hasLength(2));
      expect(terminal.viewHeight, 300 ~/ cell.height);
      expect(sizes.last, (terminal.viewWidth, terminal.viewHeight));
    });

    testWidgets('an eased height resizes once, its small steps included', (
      tester,
    ) async {
      final sizes = <(int, int)>[];
      final terminal = Terminal(onResize: (w, h, _, _) => sizes.add((w, h)));
      final box = ValueNotifier(const Size(400, 600));
      await tester.pumpWidget(_SizedTerminal(terminal, box));
      await tester.pump();
      expect(sizes, hasLength(1));

      // Fast in the middle, under a row at either end.
      for (final step in [1, 2, 4, 6, 10, 30, 60, 60, 30, 20, 10, 6, 4, 2, 1]) {
        box.value = Size(400, box.value.height - step);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));

      final cell = _render(tester).cellSize;
      expect(sizes, hasLength(2));
      expect(sizes.last, (terminal.viewWidth, 354 ~/ cell.height));
    });

    testWidgets('a width that changes resizes at once', (tester) async {
      final sizes = <(int, int)>[];
      final terminal = Terminal(onResize: (w, h, _, _) => sizes.add((w, h)));
      final box = ValueNotifier(const Size(400, 600));
      await tester.pumpWidget(_SizedTerminal(terminal, box));
      await tester.pump();

      box.value = const Size(300, 500);
      await tester.pump();

      final cell = _render(tester).cellSize;
      expect(sizes, hasLength(2));
      expect(sizes.last, (300 ~/ cell.width, 500 ~/ cell.height));
    });

    testWidgets('turning autoResize on resizes to the view', (tester) async {
      final terminal = Terminal();
      Widget view(bool autoResize) => MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 400,
            height: 600,
            child: TerminalView(terminal, autoResize: autoResize),
          ),
        ),
      );
      await tester.pumpWidget(view(false));
      expect(terminal.viewWidth, 80);

      await tester.pumpWidget(view(true));
      final cell = _render(tester).cellSize;
      expect(terminal.viewWidth, 400 ~/ cell.width);
    });

    testWidgets('a side inset moves the text and the hit test together', (
      tester,
    ) async {
      final terminal = Terminal();
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(padding: EdgeInsets.only(left: 40)),
            child: TerminalView(terminal),
          ),
        ),
      );
      terminal.write('abcdefgh');
      await tester.pump();

      final render = _render(tester);
      final cell = render.cellSize;
      expect(
        render.cursorOffset.dx,
        render.getOffset(const CellOffset(8, 0)).dx,
      );
      expect(
        render.getCellOffset(Offset(40 + cell.width * 5.5, cell.height / 2)),
        const CellOffset(5, 0),
      );
      expect(terminal.viewWidth, (render.size.width - 40) ~/ cell.width);
    });

    testWidgets('rebuilding with the same style keeps the glyph atlas', (
      tester,
    ) async {
      final terminal = Terminal();
      late StateSetter setState;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, set) {
              setState = set;
              return TerminalView(
                terminal,
                textStyle: const TerminalStyle(fontSize: 14),
                theme: TerminalThemes.defaultTheme,
              );
            },
          ),
        ),
      );
      terminal.write('中文 x');
      await tester.pump();

      var images = 0;
      void count(ui.Image _) => images++;
      ui.Image.onCreate = count;
      addTearDown(() => ui.Image.onCreate = null);

      for (var i = 0; i < 3; i++) {
        setState(() {});
        await tester.pump();
      }

      expect(images, 0);
    });

    testWidgets('scrolling to the bottom catches up with output during it', (
      tester,
    ) async {
      final terminal = Terminal();
      final scroll = ScrollController();
      await tester.pumpWidget(
        MaterialApp(
          home: TerminalView(
            terminal,
            scrollController: scroll,
            autofocus: true,
            hardwareKeyboardOnly: true,
          ),
        ),
      );
      terminal.write('line\r\n' * 100);
      await tester.pump();
      scroll.jumpTo(0);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 50));
      terminal.write('more\r\n' * 20);
      await tester.pump(const Duration(milliseconds: 500));

      expect(scroll.position.pixels, scroll.position.maxScrollExtent);

      terminal.write('more\r\n' * 20);
      await tester.pump();
      expect(scroll.position.pixels, scroll.position.maxScrollExtent);
    });

    testWidgets('a view scrolled up stays on its text as scrollback trims', (
      tester,
    ) async {
      final terminal = Terminal(maxLines: 100);
      final scroll = ScrollController();
      await tester.pumpWidget(
        MaterialApp(home: TerminalView(terminal, scrollController: scroll)),
      );
      for (var i = 0; i < 150; i++) {
        terminal.write('line$i\r\n');
      }
      await tester.pump();

      final render = _render(tester);
      final lineHeight = render.lineHeight;
      scroll.jumpTo(lineHeight * 10);
      await tester.pump();
      String topLine() => terminal
          .buffer
          .lines[render.getCellOffset(Offset(1, lineHeight / 2)).y]
          .getText()
          .trim();
      final before = topLine();

      for (var i = 150; i < 160; i++) {
        terminal.write('line$i\r\n');
      }
      await tester.pump();

      expect(topLine(), before);
    });

    testWidgets('a view scrolled up stays on its text through a reset and replay', (
      tester,
    ) async {
      final terminal = Terminal(maxLines: 1000);
      final scroll = ScrollController();
      await tester.pumpWidget(
        MaterialApp(home: TerminalView(terminal, scrollController: scroll)),
      );
      // Output kept more lines than the replay brings back.
      terminal.write([for (var i = 0; i < 300; i++) 'line$i'].join('\r\n'));
      await tester.pump();
      final replay = [for (var i = 150; i < 300; i++) 'line$i'].join('\r\n');

      final render = _render(tester);
      final lineHeight = render.lineHeight;
      scroll.jumpTo(scroll.position.maxScrollExtent - lineHeight * 40);
      await tester.pump();
      String topLine() => terminal
          .buffer
          .lines[render.getCellOffset(Offset(1, lineHeight / 2)).y]
          .getText()
          .trim();
      final before = topLine();

      terminal.write('\x1bc$replay');
      await tester.pump();

      expect(topLine(), before);
    });

    testWidgets('a view scrolled up keeps its place when the replay comes after a layout', (
      tester,
    ) async {
      final terminal = Terminal(maxLines: 1000);
      final scroll = ScrollController();
      await tester.pumpWidget(
        MaterialApp(home: TerminalView(terminal, scrollController: scroll)),
      );
      terminal.write([for (var i = 0; i < 300; i++) 'line$i'].join('\r\n'));
      await tester.pump();

      final render = _render(tester);
      final lineHeight = render.lineHeight;
      scroll.jumpTo(scroll.position.maxScrollExtent - lineHeight * 40);
      await tester.pump();
      String topLine() => terminal
          .buffer
          .lines[render.getCellOffset(Offset(1, lineHeight / 2)).y]
          .getText()
          .trim();
      final before = topLine();

      // The reset is laid out before the replay arrives.
      terminal.write('\x1bc');
      await tester.pump();
      terminal.write([for (var i = 150; i < 300; i++) 'line$i'].join('\r\n'));
      await tester.pump();

      expect(topLine(), before);
    });

    testWidgets('a new terminal does not keep the old one\'s selection', (
      tester,
    ) async {
      final a = Terminal();
      final b = Terminal();
      final controller = TerminalController();
      a.write('alpha');
      await tester.pumpWidget(
        MaterialApp(home: TerminalView(a, controller: controller)),
      );
      controller.setSelection(
        a.buffer.createAnchor(0, 0),
        a.buffer.createAnchor(3, 0),
      );
      await tester.pump();

      await tester.pumpWidget(
        MaterialApp(home: TerminalView(b, controller: controller)),
      );
      await tester.pump();

      expect(controller.selection, isNull);
    });
  });
}

class _SizedTerminal extends StatelessWidget {
  const _SizedTerminal(this.terminal, this.size);

  final Terminal terminal;
  final ValueNotifier<Size> size;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ValueListenableBuilder(
        valueListenable: size,
        builder: (_, value, _) => Align(
          alignment: Alignment.topLeft,
          child: SizedBox.fromSize(size: value, child: TerminalView(terminal)),
        ),
      ),
    );
  }
}
