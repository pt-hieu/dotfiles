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
- `wezterm/wezterm.lua` → `~/.wezterm.lua`
- `zsh/zshrc` → `~/.zshrc`
- `zsh/p10k.zsh` → `~/.p10k.zsh`
- `git/gitconfig` → `~/.gitconfig`
- `scripts/claude-idle-sleep.sh` → `~/.local/bin/claude-idle-sleep`
- `scripts/cpu-hogs.sh` → `~/.local/bin/cpu-hogs`

## Architecture

Each tool gets its own directory with a single config file. The install script symlinks them to where each tool expects its config.

### zsh/zshrc

Shell config with cross-platform support (macOS/Linux branching for paths and plugins). Sections in order:
1. **P10k instant prompt** (must stay at top)
2. **Oh-My-Zsh** setup (plugins: git, vscode, history)
3. **Environment/PATH** — nvm, pnpm, bun, pipx, WezTerm CLI
4. **Plugins** — powerlevel10k, zsh-autosuggestions, zsh-syntax-highlighting (must be last)
5. **Tool init** — zoxide (`cd` override), eza (`ls` override)
6. **Shell hooks** — tab title with git branch
7. **Functions** — git shortcuts, dev tools, worktrees, AI launchers, utilities
8. **P10k config** (must stay at bottom)

Key shell functions: `br` (current branch), `aa` (git add all), `cm` (commit with Jira ticket from branch), `cmm` (amend), `co` (checkout by fuzzy name), `push`/`pull` (to current branch), `t` (nx test), `gqlgen` (GraphQL codegen), `wt`/`wtrm` (worktree management), `c` (Claude Code launcher), `n` (nvim), `zzz` (sleep when Claude Code is idle), `hogs` (find/kill runaway CPU processes).

### ghostty/config

Primary terminal (macOS). Ported from `wezterm.lua`: Aura Dark palette, Cascadia Code NF at 14pt, 0.95 opacity + blur, and the split/scroll/resize keybinds. The window size is ghostty's default, not a fixed cell geometry. Ghostty's own macOS defaults already cover `cmd+d`/`cmd+shift+d` splits, `cmd+[`/`cmd+]` navigation, and the `cmd+arrow`/`cmd+backspace` line editing, so only overrides are declared.

Ghostty has no scripting layer, so the status bar (weather/battery/date) and tab-bar colors have no equivalent. Validate changes with `ghostty +validate-config`.

Requires `brew install --cask font-cascadia-code-nf` (Nerd Font build, needed for powerlevel10k glyphs). Italics live in a separate `Cascadia Code NF Italic` family and must be named explicitly.

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

### scripts/cpu-hogs.sh

Finds and kills runaway CPU processes — the orphans a dead tool session leaves
spinning. Portable across macOS and Linux; every duration format `ps` emits is
parsed. Modes: `check` (report only, the default), `kill [pid...]`. Exit codes:
`0` clean, `1` runaways found.

It samples accumulated CPU time twice `--sample` seconds apart and reports the
difference. `ps %cpu` is a decaying average that stays high for minutes after a
process goes quiet, which would report hogs that had already stopped.

Auto-kill is deliberately narrow. A process is RUNAWAY only when it is yours,
orphaned to init, holds no tty, is a shell or interpreter, and is older than
`--min-age`. The shell-or-interpreter test is the one that is easy to drop and
must not be: launchd parents every GUI app, so orphanhood plus no-tty describes
Chrome exactly as well as it describes a stranded `zsh`. Everything else is
reported as BUSY and needs an explicit pid or `--all`.

Kills with TERM, then KILL for whatever ignores it. The script never touches its
own ancestor chain — killing an ancestor takes down the calling shell and its
terminal.

## Conventions

- All configs use cross-platform branching (`$OSTYPE` or `wezterm.target_triple`) rather than separate files
- Zsh plugins are sourced from OS-specific paths (Homebrew on macOS, system packages on Linux)
- Syntax highlighting plugin must be sourced last in zshrc
