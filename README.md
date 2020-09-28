**[xterm.dart 1.0.0](https://pub.dev/packages/xterm/versions/1.0.0) is available! 🎉**

## xterm.dart

<p>
    <img alt="GitHub repo size" src="https://img.shields.io/github/repo-size/TerminalStudio/xterm.dart">
    <img alt="GitHub issues" src="https://img.shields.io/github/issues-raw/TerminalStudio/xterm.dart">
    <img alt="GitHub pull requests" src="https://img.shields.io/github/issues-pr/TerminalStudio/xterm.dart">
</p>


**xterm.dart** is a fast and fully-featured terminal emulator for Flutter applications, with support for mobile and desktop platforms.

> This package requires Flutter version >=1.22.0

### Screenshots

<table>
  <tr>
    <td>
		<img width="200px" src="https://raw.githubusercontent.com/TerminalStudio/xterm.dart/master/media/demo-shell.png">
    </td>
    <td>
       <img width="200px" src="https://raw.githubusercontent.com/TerminalStudio/xterm.dart/master/media/demo-vim.png">
    </td>
  <tr>
  </tr>
    <td>
       <img width="200px" src="https://raw.githubusercontent.com/TerminalStudio/xterm.dart/master/media/demo-htop.png">
    </td>
    <td>
       <img width="200px" src="https://raw.githubusercontent.com/TerminalStudio/xterm.dart/master/media/demo-dialog.png">
    </td>
  </tr>
</table>

### Features

- 📦 **Works out of the box** No special configuration required.
- 🚀 **Fast** Renders at 60fps.
- 😀 **Wide character support** Supports CJK and emojis.
- ✂️ **Customizable** 
- ✔ **Frontend independent**: The terminal core can work without flutter frontend.

### Getting Started

**1.** Add this to your package's pubspec.yaml file:

```yml
dependencies:
  ...
  xterm: ^0.0.1
```

**2.** Create the terminal:

```dart
import 'package:xterm/xterm.dart';
...
terminal = Terminal();
```

To listen for input, add an onInput handler:

```dart
terminal = Terminal(onInput: onInput);

void onInput(String input) {
 print('input: $input');
}
```

**3.** Create the view, then attach the terminal to the view:

```dart
import 'package:xterm/flutter.dart';
...
child: TerminalView(terminal: terminal),
```

**4.** Write something to the terminal:

```dart
terminal.write('Hello, world!');
```

**Done!**

### License

This project is licensed under an MIT license.