import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xterm/src/ui/custom_text_edit.dart';
import 'package:xterm/xterm.dart';

// The iOS edit menu. A paste from a menu Flutter draws reads the clipboard
// from Dart, which iOS answers with a permission prompt every time; the
// system menu's paste does not ask.

void main() {
  late List<MethodCall> calls;
  late String? copied;
  final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

  setUp(() {
    calls = [];
    copied = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call);
          switch (call.method) {
            case 'Clipboard.hasStrings':
              return <String, bool>{'value': true};
            case 'Clipboard.setData':
              copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  List<Map<Object?, Object?>> shownItems() {
    final call = calls.lastWhere(
      (call) => call.method == 'ContextMenu.showSystemContextMenu',
    );
    return [
      for (final item in (call.arguments as Map)['items'] as List)
        item as Map<Object?, Object?>,
    ];
  }

  testWidgets('the system menu pastes as a paste, without a clipboard read', (
    tester,
  ) async {
    final harness = await _pump(tester);
    harness.terminal.write('\x1b[?2004h');

    await harness.longPressAt(30, 2);

    expect(find.byType(TextSelectionToolbar), findsNothing);
    expect(shownItems().first['type'], 'paste');

    // What the platform view does with the menu's paste: inserts the
    // clipboard as typed text.
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'ls\nrm',
        selection: TextSelection.collapsed(offset: 5),
      ),
    );
    await tester.pump();

    expect(harness.output.join(), '\x1b[200~ls\nrm\x1b[201~');
    expect(
      calls.where((call) => call.method == 'Clipboard.getData'),
      isEmpty,
    );

    // Typing after it is typing again.
    harness.output.clear();
    await _systemHide(tester);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'x',
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    await tester.pump();
    expect(harness.output.join(), 'x');
  }, variant: ios);

  testWidgets('a menu put away without a paste leaves typing alone', (
    tester,
  ) async {
    final harness = await _pump(tester);
    harness.terminal.write('\x1b[?2004h');

    await harness.longPressAt(30, 2);
    await _systemHide(tester);

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'x',
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    await tester.pump();
    expect(harness.output.join(), 'x');
  }, variant: ios);

  testWidgets('copy is the terminal selection, not the input text', (
    tester,
  ) async {
    final harness = await _pump(tester);

    await harness.doubleTapAt(7);

    final items = shownItems();
    final copy = items.firstWhere(
      (item) =>
          item['title'] == const DefaultMaterialLocalizations().copyButtonLabel,
    );
    expect(copy['type'], 'custom');
    expect(items.map((item) => item['type']), contains('paste'));

    await _systemAction(tester, copy['id']! as String);
    await tester.pump();

    expect(copied, 'beta');

    // Typed after an action other than paste: typing.
    harness.terminal.write('\x1b[?2004h');
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'x',
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    await tester.pump();
    expect(harness.output.join(), 'x');
  }, variant: ios);

  testWidgets('select all puts the menu back, to copy from', (tester) async {
    final harness = await _pump(tester);

    await harness.longPressAt(30, 2);
    final selectAll = shownItems().firstWhere(
      (item) =>
          item['title'] ==
          const DefaultMaterialLocalizations().selectAllButtonLabel,
    );
    calls.clear();
    await _systemAction(tester, selectAll['id']! as String);
    await _systemHide(tester);
    await tester.pump();

    expect(harness.controller.selection, isNotNull);
    expect(
      shownItems().map((item) => item['title']),
      contains(const DefaultMaterialLocalizations().copyButtonLabel),
    );
  }, variant: ios);

  testWidgets('putting the keyboard away puts the menu away', (tester) async {
    final harness = await _pump(tester);
    harness.terminal.write('\x1b[?2004h');

    await harness.longPressAt(30, 2);
    calls.clear();
    harness.key.currentState!.closeKeyboard();
    expect(
      calls.map((call) => call.method),
      contains('ContextMenu.hideSystemContextMenu'),
    );

    harness.key.currentState!.requestKeyboard();
    await tester.pump();
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'x',
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    await tester.pump();
    expect(harness.output.join(), 'x');
  }, variant: ios);

  testWidgets('a paste the host put in the menu stays the host\'s', (
    tester,
  ) async {
    var hostPasted = 0;
    final harness = await _pump(
      tester,
      toolbarBuilder: (context, state, items) => [
        for (final item in items)
          item.type == ContextMenuButtonType.paste
              ? item.copyWith(onPressed: () => hostPasted++)
              : item,
      ],
    );

    await harness.longPressAt(30, 2);

    final paste = shownItems().first;
    expect(paste['type'], 'custom');
    await _systemAction(tester, paste['id']! as String);
    expect(hostPasted, 1);
  }, variant: ios);

  testWidgets('a host paste routes the system paste through it', (
    tester,
  ) async {
    final pasted = <String>[];
    final harness = await _pump(tester, onPasteText: pasted.add);

    await harness.longPressAt(30, 2);
    expect(shownItems().first['type'], 'paste');
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'ls',
        selection: TextSelection.collapsed(offset: 2),
      ),
    );
    await tester.pump();

    expect(pasted, ['ls']);
    expect(harness.output, isEmpty);
  }, variant: ios);
  group('a paste the platform signals', () {
    tearDown(() => CustomTextEditState.pasteSignalled = false);

    void insert(WidgetTester tester, String text, {TextRange? composing}) {
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
          composing: composing ?? TextRange.empty,
        ),
      );
    }

    Future<_Harness> bracketed(WidgetTester tester) async {
      final harness = await _pump(tester);
      harness.terminal.write('\x1b[?2004h');
      return harness;
    }

    testWidgets('is the insert that ends with it, bracketed', (tester) async {
      final harness = await bracketed(tester);

      CustomTextEditState.expectPaste('ls\nrm');
      insert(tester, 'ls\nrm');
      await tester.pump();
      expect(harness.output.join(), '\x1b[200~ls\nrm\x1b[201~');

      harness.output.clear();
      insert(tester, 'x');
      await tester.pump();
      expect(harness.output.join(), 'x');
    });

    testWidgets('a composition it commits goes first, as typing', (
      tester,
    ) async {
      final harness = await bracketed(tester);

      insert(tester, 'ni', composing: const TextRange(start: 0, end: 2));
      await tester.pump();
      CustomTextEditState.expectPaste('pasted');
      insert(tester, 'nipasted');
      await tester.pump();

      expect(harness.output.join(), 'ni\x1b[200~pasted\x1b[201~');
    });

    testWidgets('an update before it does not take it', (tester) async {
      // The composition committed on its own, then the insert.
      final harness = await bracketed(tester);

      insert(tester, 'ni', composing: const TextRange(start: 0, end: 2));
      await tester.pump();
      CustomTextEditState.expectPaste('ls\nrm');
      insert(tester, 'ni');
      await tester.pump();
      insert(tester, 'ls\nrm');
      await tester.pump();

      expect(harness.output.join(), 'ni\x1b[200~ls\nrm\x1b[201~');
    });

    testWidgets('lapses when it never arrives', (tester) async {
      final harness = await bracketed(tester);

      CustomTextEditState.expectPaste('x');
      await tester.pump(const Duration(seconds: 2));
      insert(tester, 'x');
      await tester.pump();
      expect(harness.output.join(), 'x');
    });

    testWidgets('once heard, the menu is no longer guessed from', (
      tester,
    ) async {
      final harness = await bracketed(tester);
      CustomTextEditState.expectPaste('unused');
      await tester.pump(const Duration(seconds: 2));

      await harness.longPressAt(30, 2);
      insert(tester, 'x');
      await tester.pump();
      expect(harness.output.join(), 'x');
    }, variant: ios);
  });

  testWidgets('select all puts the menu over the new selection', (
    tester,
  ) async {
    final harness = await _pump(tester);

    await harness.longPressAt(30, 2);
    final first = calls.lastWhere(
      (call) => call.method == 'ContextMenu.showSystemContextMenu',
    );
    final selectAll = shownItems().firstWhere(
      (item) =>
          item['title'] ==
          const DefaultMaterialLocalizations().selectAllButtonLabel,
    );
    calls.clear();
    await _systemAction(tester, selectAll['id']! as String);
    await _systemHide(tester);
    await tester.pump();

    final again = calls.lastWhere(
      (call) => call.method == 'ContextMenu.showSystemContextMenu',
    );
    expect(
      (again.arguments as Map)['targetRect'],
      isNot((first.arguments as Map)['targetRect']),
    );
  }, variant: ios);

  testWidgets('a refused copy is reported', (tester) async {
    Object? failed;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            throw PlatformException(code: 'busy');
          }
          if (call.method == 'Clipboard.hasStrings') {
            return <String, bool>{'value': true};
          }
          return null;
        });
    final harness = await _pump(tester, onCopyFailed: (e, _) => failed = e);

    await harness.doubleTapAt(7);
    harness.key.currentState!.copySelection();
    await tester.pump();

    expect(failed, isA<PlatformException>());
  });
}

Future<void> _platformMessage(WidgetTester tester, MethodCall call) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.platform.name,
    SystemChannels.platform.codec.encodeMethodCall(call),
    (_) {},
  );
}

Future<void> _systemHide(WidgetTester tester) => _platformMessage(
  tester,
  const MethodCall('ContextMenu.onDismissSystemContextMenu', [1]),
);

Future<void> _systemAction(WidgetTester tester, String id) => _platformMessage(
  tester,
  MethodCall('ContextMenu.onPerformCustomAction', [1, id]),
);

Future<_Harness> _pump(
  WidgetTester tester, {
  CustomTextEditToolbarBuilder? toolbarBuilder,
  void Function(String text)? onPasteText,
  void Function(Object error, StackTrace stack)? onCopyFailed,
}) async {
  final terminal = Terminal(maxLines: 32);
  final output = <String>[];
  terminal.onOutput = output.add;
  final controller = TerminalController();
  final key = GlobalKey<TerminalViewState>();

  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(supportsShowingSystemContextMenu: true),
        child: Scaffold(
          body: TerminalView(
            terminal,
            controller: controller,
            key: key,
            autofocus: true,
            toolbarBuilder: toolbarBuilder,
            onPaste: onPasteText == null ? null : () {},
            onPasteText: onPasteText,
            onCopyFailed: onCopyFailed,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();

  terminal.write('alpha beta gamma');
  await tester.pump();

  return _Harness(tester, terminal, controller, output, key);
}

class _Harness {
  _Harness(this.tester, this.terminal, this.controller, this.output, this.key);

  final WidgetTester tester;
  final Terminal terminal;
  final TerminalController controller;
  final List<String> output;
  final GlobalKey<TerminalViewState> key;

  Offset offsetOf(int column, [int row = 0]) {
    final topLeft = tester.getTopLeft(find.byType(TerminalView));
    final render = tester.renderObject(find.byType(TerminalView));
    final cellWidth = render.paintBounds.width / terminal.viewWidth;
    final cellHeight = render.paintBounds.height / terminal.viewHeight;
    return topLeft +
        Offset((column + 0.5) * cellWidth, (row + 0.5) * cellHeight);
  }

  Future<void> longPressAt(int column, int row) async {
    final gesture = await tester.startGesture(offsetOf(column, row));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 1));
    await gesture.up();
    await tester.pump();
    await tester.pump(kDoubleTapTimeout);
  }

  Future<void> doubleTapAt(int column) async {
    for (var i = 0; i < 2; i++) {
      final gesture = await tester.startGesture(
        offsetOf(column),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.up();
      await tester.pump(
        i == 1
            ? kDoubleTapTimeout + const Duration(milliseconds: 1)
            : kDoubleTapMinTime,
      );
    }
  }
}
