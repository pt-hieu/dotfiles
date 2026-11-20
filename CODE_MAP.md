# Code map

## Areas

- `zsh/zshrc` is the shell config: PATH, plugins, vi mode, hooks, and the shell functions.
- `zsh/p10k.zsh` is the Powerlevel10k prompt, written by hand.
- `ghostty/config` is the Ghostty terminal config, used on macOS.
- `ghostty/themes/aura-dark-wezterm` is the Aura Dark palette that Ghostty loads and Rex imports.
- `rex/init.lua` is the Rex config. It holds the history picker's two keybinds and leaves everything else to Rex's defaults; the `alt+hjkl` pane resizing that `ghostty/config` has is left out on purpose.
- `rex/MANUAL_SETUP.md` lists the Rex settings made by hand in the app because Rex has no config key for them yet.
- `rex/md-opener/` is the source of `Rex Markdown.app`, the macOS default app for `.md` files, which opens them in nvim in a Rex pane.
- `wezterm/wezterm.lua` is the WezTerm config, for macOS and Linux.
- `git/gitconfig` is the global git config.
- `scripts/claude-idle-sleep.sh` sleeps the Mac once every Claude Code session is idle; the `zzz` function in `zsh/zshrc` wraps it.
- `scripts/rex-history-pick.sh` is the fzf history picker that `rex/init.lua` opens on `cmd+r`. It parses `$HISTFILE` itself because `fc -R` hangs in a bare zsh.

## Entry points

- `install.sh` links every config and script to the path its tool reads, and on macOS runs `rex/md-opener/build.sh`.
- `rex/md-opener/build.sh` compiles `Rex Markdown.app` into `~/Applications` and registers it for `.md` files.

## Where to go for a task

- Add a config file or a script: put it in its tool's directory, add a `link` line to `install.sh`, and run `./install.sh`.
- Add a shell function: it goes in `zsh/zshrc` under the `Functions:` banner for its kind (Git, Dev Tools, AI, Utilities).
- Change the prompt: edit `zsh/p10k.zsh` and check it in a bare shell with `zsh -f -c 'source zsh/p10k.zsh; typeset -m "POWERLEVEL9K_*"'`.
- Add a prompt segment: name it in an element list in `zsh/p10k.zsh` and give it a style block with `$my_aura[name]` colours, because without one it draws in p10k's default colours.
- Leave `p10k configure` alone: it overwrites `zsh/p10k.zsh` with the wizard's output.
- Change `ghostty/config`: validate with `ghostty +validate-config`.
- Change `rex/init.lua`: validate with `rex config check`, apply with `rex config reload`, and read what the server loaded with `rex keymap`.
- Change anything in `rex/md-opener/`: run `rex/md-opener/build.sh` afterwards, because the built app holds a copy of the scripts.
- Change a Rex setting that `rex/init.lua` cannot set: do it in the app and record it in `rex/MANUAL_SETUP.md`.
- Change an Aura Dark colour: it is written out in `ghostty/themes/aura-dark-wezterm`, in the `my_aura` table in `zsh/p10k.zsh`, and in `config.color_schemes` in `wezterm/wezterm.lua`, and Rex needs the theme file imported again as `rex/MANUAL_SETUP.md` describes.

## Paths you can predict

- A tool's config is at `<tool>/<the file name the tool expects>`.
- One file serves both macOS and Linux, with the differences as branches inside it (`$OSTYPE` in zsh, `wezterm.target_triple` in WezTerm), so no per-OS copy of a file exists.
- `scripts/<name>.sh` is installed as `~/.local/bin/<name>`.

## Places to skip

- `ghostty/themes/aura-dark-wezterm` has wezterm in its name, but WezTerm does not read it; WezTerm's colours are in `wezterm/wezterm.lua`.
