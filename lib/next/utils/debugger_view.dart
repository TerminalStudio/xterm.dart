import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:xterm/next/utils/debugger.dart';

class TerminalDebuggerView extends StatefulWidget {
  const TerminalDebuggerView(
    this.debugger, {
    Key? key,
    this.scrollController,
    this.onSeek,
  }) : super(key: key);

  final TerminalDebugger debugger;

  final ScrollController? scrollController;

  final void Function(int)? onSeek;

  @override
  State<TerminalDebuggerView> createState() => _TerminalDebuggerViewState();
}

class _TerminalDebuggerViewState extends State<TerminalDebuggerView> {
  int? selectedCommand;

  @override
  void initState() {
    widget.debugger.addListener(_onDebuggerChanged);
    super.initState();
  }

  @override
  void didUpdateWidget(covariant TerminalDebuggerView oldWidget) {
    if (oldWidget.debugger != widget.debugger) {
      oldWidget.debugger.removeListener(_onDebuggerChanged);
      widget.debugger.addListener(_onDebuggerChanged);
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    widget.debugger.removeListener(_onDebuggerChanged);
    super.dispose();
  }

  void _onDebuggerChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final commands = widget.debugger.commands;
    return ListView.builder(
      itemExtent: 20,
      controller: widget.scrollController,
      itemCount: commands.length,
      itemBuilder: (context, index) {
        final command = commands[index];
        return _CommandItem(
          index,
          command,
          selected: selectedCommand == index,
          select: () {
            setState(() => selectedCommand = index);
            widget.onSeek?.call(index);
          },
        );
      },
    );
  }
}

class _CommandItem extends StatelessWidget {
  const _CommandItem(
    this.index,
    this.command, {
    Key? key,
    this.select,
    this.selected = false,
  }) : super(key: key);

  final int index;

  final TerminalCommand command;

  final bool selected;

  final void Function()? select;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: select,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (event) {
          if (event.down) {
            select?.call();
          }
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? Colors.blue : Colors.transparent,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: selected ? Colors.blue : Colors.black,
                    fontFamily: 'monospace',
                    fontFamilyFallback: [
                      'Menlo',
                      'Monaco',
                      'Consolas',
                      'Liberation Mono',
                      'Courier New',
                      'Noto Sans Mono CJK SC',
                      'Noto Sans Mono CJK TC',
                      'Noto Sans Mono CJK KR',
                      'Noto Sans Mono CJK JP',
                      'Noto Sans Mono CJK HK',
                      'Noto Color Emoji',
                      'Noto Sans Symbols',
                      'monospace',
                      'sans-serif',
                    ],
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              SizedBox(width: 20),
              Container(
                width: 100,
                child: Text(command.escapedChars),
              ),
              Expanded(
                child: Container(
                  child: Text(command.explanation.join(',')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
