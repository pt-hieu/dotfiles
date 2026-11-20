# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal dotfiles for Brian Pham. Manages shell, terminal, and git configurations across macOS and Linux (CachyOS/Arch).

## Setup

```bash
./install.sh  # Symlinks all configs to home directory
```

Symlink targets:
- `ghostty/config` → `~/.config/ghostty/config`
- `ghostty/themes/aura-dark-wezterm` → `~/.config/ghostty/themes/aura-dark-wezterm`
- `rex/init.lua` → `~/.config/rex/init.lua`
- `wezterm/wezterm.lua` → `~/.wezterm.lua`
- `zsh/zshrc` → `~/.zshrc`
- `zsh/p10k.zsh` → `~/.p10k.zsh`
- `git/gitconfig` → `~/.gitconfig`
- `scripts/claude-idle-sleep.sh` → `~/.local/bin/claude-idle-sleep`
- `scripts/rex-history-pick.sh` → `~/.local/bin/rex-history-pick`

On macOS it also builds `~/Applications/Rex Markdown.app` from `rex/md-opener/`
and makes it the default app for Markdown files.

## Architecture

Each tool gets its own directory with a single config file. The install script symlinks them to where each tool expects its config.

### zsh/zshrc

Shell config with cross-platform support (macOS/Linux branching for paths and plugins). Sections in order:
1. **P10k instant prompt** (must stay at top)
2. **Oh-My-Zsh** setup (plugins: git, vscode, history)
3. **Environment/PATH** — mise, pnpm, bun, pipx, WezTerm CLI
4. **Plugins** — powerlevel10k, zsh-autosuggestions, zsh-syntax-highlighting (must be last)
5. **Key bindings** — vi mode (`bindkey -v`) with `KEYTIMEOUT=1`, set after plugins so their own bindkey calls do not win
6. **Tool init** — zoxide (`cd` override), eza (`ls` override)
7. **Shell hooks** — tab title with git branch
8. **Functions** — git shortcuts, dev tools, worktrees, AI launchers, utilities
9. **P10k config** (must stay at bottom)

Key shell functions: `br` (current branch), `aa` (git add all), `cm` (commit with Jira ticket from branch), `cmm` (amend), `co` (checkout by fuzzy name), `push`/`pull` (to current branch), `wt` (cd to a `.claude/worktrees` entry by fuzzy name, or the repo root with no argument; tab-completes), `n` (nvim), `zzz` (sleep when Claude Code is idle).

### zsh/p10k.zsh

Hand-written Powerlevel10k config: lean single-line style, transparent
background, transient prompt. Left side is `dir`, `vcs`, `prompt_char`; the
right side lists the segments for tools installed here. `my_git_formatter`
builds the `vcs` text. Colours come from the `my_aura` table at the top, the
Aura Dark palette in truecolor hex; set a segment's colour with
`$my_aura[name]`. A segment added to the element lists draws with p10k's
default colours until it gets its own style block. Running `p10k configure`
overwrites this file with the wizard output.

Check a change by loading it in a bare shell, which skips the startup files:
`zsh -f -c 'source zsh/p10k.zsh; typeset -m "POWERLEVEL9K_*"'`.

### ghostty/config

Terminal (macOS). Ported from `wezterm.lua`: Aura Dark palette (in `ghostty/themes/aura-dark-wezterm`, loaded with `theme =` and shared with Rex), Cascadia Code NF at 14pt, 0.23 opacity + blur, and the split/scroll/resize keybinds. The window size is ghostty's default, not a fixed cell geometry. Ghostty's own macOS defaults already cover `cmd+d`/`cmd+shift+d` splits, `cmd+[`/`cmd+]` navigation, and the `cmd+arrow`/`cmd+backspace` line editing, so only overrides are declared.

Ghostty has no scripting layer, so the status bar (weather/battery/date) and tab-bar colors have no equivalent. Validate changes with `ghostty +validate-config`.

New shells start via `login -fp`, so macOS prints a `Last login:` banner; `install.sh` creates `~/.hushlogin` to silence it.

Requires `brew install --cask font-cascadia-code-nf` (Nerd Font build, needed for powerlevel10k glyphs). Italics live in a separate `Cascadia Code NF Italic` family and must be named explicitly.

### rex/init.lua

Rex config (Lua). Rex's default shortcuts cover the splits, pane focus, line
editing and `shift+enter`. The `alt+hjkl` pane resizing from `ghostty/config`
was dropped on purpose. It binds two keys of its own:

- `cmd+r` (`history_search`) opens a floating pane labelled `history` that runs
  `scripts/rex-history-pick.sh` on the pane you came from.
- `cmd+enter` (`history_run_or_split`) sends `ctrl-x` to fzf when that
  `history` pane has focus, so the pick runs. Anywhere else it queues the
  default `pane.split.auto`. The label is how the action tells the picker apart.

Validate with `rex config check` and apply with `rex config reload`;
`rex keymap` shows what the server loaded.

Colors and font are app settings that live in the Rex app. The palette comes
from importing `ghostty/themes/aura-dark-wezterm` (command palette → Import
Theme File). `rex/MANUAL_SETUP.md` lists every setting made by hand in the
GUI, to move into config once Rex supports it.

### rex/md-opener/

`Rex Markdown.app`, the default macOS app for `.md` files, so Cmd-clicking a
Markdown path in Rex opens it in nvim. Rex hands file links to the macOS
default app and has no link-handler hook of its own, which is why this is an
app. Needs `brew install duti`.

- `main.applescript` takes the files macOS opens and passes them to
  `open-in-rex.sh`, copied into the app's Resources.
- `open-in-rex.sh` runs `rex split -- nvim FILE` next to the focused pane of
  the session the Rex app shows. If the app isn't connected, it launches Rex
  and waits up to 10 s, then falls back to TextEdit.
- `build.sh` compiles the app with `osacompile`, sets its bundle ID
  (`dev.brianpham.rex-md-opener`) and document types with PlistBuddy, signs
  it ad hoc, registers it, and sets it as the `.md` default with `duti`.

The server doesn't say which session the app has on screen, so with several
sessions open the file goes to the first one the app is attached to. After
editing the script, re-run `build.sh`; the app holds a copy.

### wezterm/wezterm.lua

Terminal emulator config. Cross-platform (CMD on macOS, ALT on Linux). Features:
- Aura Dark color scheme (custom definition)
- Cascadia Code font at 14pt
- Weather/battery/date status bar (macOS only, via open-meteo API)
- Pane splitting: `mod+d` horizontal, `mod+shift+d` vertical
- Pane navigation: `mod+[`/`mod+]`, resize with `alt+hjkl`
- Linux-specific: tab management (`alt+t`/`alt+w`/`alt+;`/`alt+'`), clipboard image paste via `clip2path`

### git/gitconfig

Minimal — user identity and GitHub credential helper via `gh`.

### scripts/claude-idle-sleep.sh

Sleeps the Mac once every Claude Code CLI session is back at its prompt. macOS
only — it needs `pmset`, `ioreg` and BSD `stat`. Modes: `check` (report only,
the default), `sleep` (sleep once if idle), `watch [minutes]` (poll, default
15). Exit codes: `0` idle, `1` busy, `2` already asleep.

Three guards must all pass before it sleeps:

1. **No working session.** Claude Code holds a `caffeinate` child process for as
   long as it is working and kills it on return to the prompt. A `claude` PID
   with no `caffeinate` child is idle. This is the primary signal.
2. **Transcript quiet.** No write under `~/.claude/projects` for
   `--quiet-minutes` (default 10).
3. **User away.** No keyboard or mouse input for `--user-idle` seconds
   (default 300).

Two details that are easy to get wrong:

- The session running the check excludes its own PID (`CLAUDE_PID`) and its own
  transcript (`CLAUDE_CODE_SESSION_ID`), or it vetoes its own sleep. `lsof`
  cannot find the transcript — Claude Code closes the file between appends.
- The already-asleep check parses `pmset -g log`, which takes ~7s, so it only
  runs after the cheap guards pass. It exists because a scheduled DarkWake
  (maintenance, RTC, push) would otherwise be cut short by another sleep.

### scripts/rex-history-pick.sh

The picker behind `cmd+r` in Rex. Needs `brew install fzf`. It reads
`$HISTFILE` (default `~/.zsh_history`) directly, rebuilding multi-line entries
and stripping `EXTENDED_HISTORY` prefixes. It does not use `fc -R`, which hangs
in a bare zsh. Entries come newest first with duplicates dropped, and are passed
to fzf as NUL-separated records. `Enter` types the pick into the origin pane
with `rex send`. `ctrl-x` (sent by Rex for `cmd+enter`) also adds `\r` to run it.

## Conventions

- All configs use cross-platform branching (`$OSTYPE` or `wezterm.target_triple`) rather than separate files
- Zsh plugins are sourced from OS-specific paths (Homebrew on macOS, system packages on Linux)
- Syntax highlighting plugin must be sourced last in zshrc
