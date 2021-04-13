
## xterm.dart

<p>
    <a href="https://github.com/TerminalStudio/xterm.dart/actions/workflows/ci.yml">
      <img alt="Actions" src="https://github.com/TerminalStudio/xterm.dart/actions/workflows/ci.yml/badge.svg">
    </a>
    <a href="https://pub.dev/packages/xterm">
      <img alt="Package version" src="https://img.shields.io/pub/v/xterm?color=blue&include_prereleases">
    </a>
    <img alt="GitHub repo size" src="https://img.shields.io/github/repo-size/TerminalStudio/xterm.dart">
    <img alt="GitHub issues" src="https://img.shields.io/github/issues-raw/TerminalStudio/xterm.dart">
    <img alt="GitHub pull requests" src="https://img.shields.io/github/issues-pr/TerminalStudio/xterm.dart">
</p>


**xterm.dart** is a fast and fully-featured terminal emulator for Flutter applications, with support for mobile and desktop platforms.

> This package requires Flutter version >=2.0.0

## Screenshots

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

## Features

- 📦 **Works out of the box** No special configuration required.
- 🚀 **Fast** Renders at 60fps.
- 😀 **Wide character support** Supports CJK and emojis.
- ✂️ **Customizable** 
- ✔ **Frontend independent**: The terminal core can work without flutter frontend.

## Getting Started

**1.** Add this to your package's pubspec.yaml file:

```yml
dependencies:
  ...
  xterm: ^2.2.0-pre
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

## Example

- **local pty example**: [Terminal Lite](https://github.com/TerminalStudio/xterm.dart)

- **ssh example**: https://github.com/TerminalStudio/xterm.dart/blob/master/example/lib/ssh.dart
<img width="400px" src="https://raw.githubusercontent.com/TerminalStudio/xterm.dart/master/media/example-ssh.png">

## Features and bugs

Please file feature requests and bugs at the [issue tracker](https://github.com/TerminalStudio/xterm.dart/issues).

Contributions are always welcome!

## License

This project is licensed under an MIT license.