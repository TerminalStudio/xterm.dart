## [3.0.6-alpha] - 2022-4-4
* Export `TerminalViewState`
* Added `onTap` callback to `TerminalView`

## [3.0.5-alpha] - 2022-4-4
* Avoid resize when `RenderBox.size` is zero.
* Added `charInput` and `textInput`method.
* Added `requestKeyboard`, `closeKeyboard` and `hasInputConnection`method.
* Export `KeyboardVisibilty`

## [3.0.4-alpha] - 2022-4-1
* Improved text editing
* Added composing state painting
* Adapt to `MediaQuery.padding`

## [3.0.3-alpha] - 2022-3-28
* Improved scroll handing
* Improved resize handing
* Fix focus repaint
* Fix OSC title update

## [3.0.2-alpha] - 2022-3-28
* Re-design `KeyboardVisibilty`

## [3.0.1-alpha] - 2022-3-27
* Add `KeyboardVisibilty`

## [3.0.0-alpha] - 2022-3-26
* Initial release of v3.

## [2.6.0] - 2021-12-28
* Add scrollBehavior field to the TerminalView class [#55].
* Feature: Search [#60]. Thanks [@devmil].
* Fixes for occasional unintended multi character input [#61]. Thanks [@devmil].
* Fixes ALT + L for a Mac (German Layout) [#62]. Thanks [@devmil].
* Fixes example build problem of flutter-windows for new version of flutter [#63]. Thanks [@linhanyu].
* Fixes inverse color text (when background == 0) [#66]. Thanks [@devmil].
* Fixes assert of scrollController.position [#67]. Thanks [@linhanyu].
* Change interface of ssh.dart example to satisfied new dartssh [#69]. Thanks [@linhanyu].
* add configuration options for keyboard [#74]. Thanks [@jda258].
* Adds check if the TerminalIsolate has already been started  [#77]. Thanks [@devmil].

## [2.5.0-pre] - 2021-8-4
* Support select word / whole row via double tap [#40]. Thanks [@devmil].
* Adds "selectAll" to TerminalUiInteraction [#43]. Thanks [@devmil].
* Fixes sgr processing [#44],[#45]. Thanks [@devmil].
* Adds blinking Cursor support [#46]. Thanks [@devmil].
* Fixes Zoom adaptions on non active buffer [#47]. Thanks [@devmil].
* Adds Padding option to TerminalView  [#48]. Thanks [@devmil].
* Removes no longer supported LogicalKeyboardKey  [#49]. Thanks [@devmil].
* Adds the composing state [#50]. Thanks [@devmil].
* Fix scroll problem in mobile device [#51]. Thanks [@linhanyu].

## [2.4.0-pre] - 2021-6-13
* Update the signature of TerminalBackend.resize() to also receive dimensions in
 pixels[(#39)](https://github.com/TerminalStudio/xterm.dart/pull/39). Thanks [@michaellee8](https://github.com/michaellee8).

## [2.3.1-pre] - 2021-6-1
* Export `theme/terminal_style.dart`

## [2.3.0-pre] - 2021-6-1
* Add `import 'package:xterm/isolate.dart';`

## [2.2.1-pre] - 2021-6-1
* Make BufferLine work on web.

## [2.2.0-pre] - 2021-4-12

## [2.1.0-pre] - 2021-3-20
* Better support for resizing and scrolling.
* Reflow support (in progress [#13](https://github.com/TerminalStudio/xterm.dart/pull/13)), thanks [@devmil](https://github.com/devmil).

## [2.0.0] - 2021-3-7
* Clean up for release

## [2.0.0-pre] - 2021-3-7
* Migrate to nnbd

## [1.3.0] - 2021-2-24
* Performance improvement.

## [1.2.0] - 2021-2-15

* Pass TerminalView's autofocus to the InputListener that it creates. [#10](https://github.com/TerminalStudio/xterm.dart/pull/10), thanks [@timburks](https://github.com/timburks)

## [1.2.0-pre] - 2021-1-20

* add the ability to use fonts from the google_fonts package [#9](https://github.com/TerminalStudio/xterm.dart/pull/9)

## [1.1.1+1] - 2020-10-4

* Update readme


## [1.1.1] - 2020-10-4

* Add brightWhite to TerminalTheme

## [1.1.0] - 2020-9-29

* Fix web support.

## [1.0.2] - 2020-9-29

* Update link.

## [1.0.1] - 2020-9-29

* Disable debug print.

## [1.0.0] - 2020-9-28

* Update readme.

## [1.0.0-dev] - 2020-9-28

* Major issues are fixed.

## [0.1.0] - 2020-8-9

* Bug fixes

## [0.0.4] - 2020-8-1

* Revert version constrain

## [0.0.3] - 2020-8-1

* Update version constrain


## [0.0.2] - 2020-8-1

* Update readme


## [0.0.1] - 2020-8-1

* First version


[@devmil]: https://github.com/devmil
[@michaellee8]: https://github.com/michaellee8
[@linhanyu]: https://github.com/linhanyu
[@jda258]: https://github.com/jda258

[#40]: https://github.com/TerminalStudio/xterm.dart/pull/40
[#43]: https://github.com/TerminalStudio/xterm.dart/pull/43
[#44]: https://github.com/TerminalStudio/xterm.dart/pull/44
[#45]: https://github.com/TerminalStudio/xterm.dart/pull/45
[#46]: https://github.com/TerminalStudio/xterm.dart/pull/46
[#47]: https://github.com/TerminalStudio/xterm.dart/pull/47
[#48]: https://github.com/TerminalStudio/xterm.dart/pull/48
[#49]: https://github.com/TerminalStudio/xterm.dart/pull/49
[#50]: https://github.com/TerminalStudio/xterm.dart/pull/50
[#51]: https://github.com/TerminalStudio/xterm.dart/pull/51


[#55]: https://github.com/TerminalStudio/xterm.dart/pull/55
[#60]: https://github.com/TerminalStudio/xterm.dart/pull/60
[#61]: https://github.com/TerminalStudio/xterm.dart/pull/61
[#62]: https://github.com/TerminalStudio/xterm.dart/pull/62
[#63]: https://github.com/TerminalStudio/xterm.dart/pull/63
[#66]: https://github.com/TerminalStudio/xterm.dart/pull/66
[#67]: https://github.com/TerminalStudio/xterm.dart/pull/67
[#69]: https://github.com/TerminalStudio/xterm.dart/pull/69
[#74]: https://github.com/TerminalStudio/xterm.dart/pull/74
[#77]: https://github.com/TerminalStudio/xterm.dart/pull/77
