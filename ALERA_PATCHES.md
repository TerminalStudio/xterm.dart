# Alera patches

This fork is consumed by Alera as a Git submodule while the terminal fixes are
reviewed upstream.

## Fork metadata

- Fork: <https://github.com/leynier/xterm.dart.git>
- Branch: `fix/scroll-region-buffer-line-move`
- Upstream: <https://github.com/TerminalStudio/xterm.dart>
- Upstream pull request: <https://github.com/TerminalStudio/xterm.dart/pull/227>

## Changes

- Move scroll-region buffer lines safely so scroll-region updates do not detach
  indexed buffer rows.
- Clear stale alternate-buffer and main-buffer cells after resize so
  full-screen terminal apps do not show old rows after the viewport changes.
- Skip app reflow while cursor-hidden apps redraw their own frame, preventing
  stale TUI content from being reintroduced during resize.
- Preserve empty cells between copied text columns when serializing selected
  buffer text. TUI apps can draw columns by moving the cursor instead of writing
  literal space characters; those visual gaps should copy as spaces.

## Why Alera carries this fork

Alera embeds terminal sessions that run interactive TUIs such as Claude Code,
Codex, Gemini, and similar agents. Those apps rely heavily on resize handling,
scroll regions, alternate buffers, cursor positioning, and visual columns. The
fork keeps the minimal fixes available to Alera until upstream can merge and
release them.
