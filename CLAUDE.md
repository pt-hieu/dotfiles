# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal dotfiles for Brian Pham. Manages shell, terminal, and git configurations across macOS and Linux (CachyOS/Arch).

## Setup

```bash
./install.sh  # Symlinks all configs to home directory
```

Symlink targets:
- `wezterm/wezterm.lua` → `~/.wezterm.lua`
- `zsh/zshrc` → `~/.zshrc`
- `zsh/p10k.zsh` → `~/.p10k.zsh`
- `git/gitconfig` → `~/.gitconfig`
- `scripts/claude-idle-sleep.sh` → `~/.local/bin/claude-idle-sleep`

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

Key shell functions: `br` (current branch), `aa` (git add all), `cm` (commit with Jira ticket from branch), `cmm` (amend), `co` (checkout by fuzzy name), `push`/`pull` (to current branch), `t` (nx test), `gqlgen` (GraphQL codegen), `wt`/`wtrm`/`link` (worktree management), `c` (Claude Code launcher), `n` (nvim), `zzz` (sleep when Claude Code is idle).

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

## Conventions

- All configs use cross-platform branching (`$OSTYPE` or `wezterm.target_triple`) rather than separate files
- Zsh plugins are sourced from OS-specific paths (Homebrew on macOS, system packages on Linux)
- Syntax highlighting plugin must be sourced last in zshrc
