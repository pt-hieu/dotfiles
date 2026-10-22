# Rex manual setup

These settings live in the Rex app's macOS preferences (`com.superlogical.rex`)
and are set by hand in the GUI, because `init.lua` and the `rex` CLI have no
way to set them yet. Move each one into `init.lua` or `install.sh` once Rex
supports it, and delete its entry here.

Track Rex's progress through the "settings in config files" feature request
(accepted) and the Rex changelog.

## Theme: Aura Dark

1. Command palette (`cmd+shift+p`) → **Import Theme File**.
2. Press `cmd+shift+g` in the file picker and open
   `~/.config/ghostty/themes/aura-dark-wezterm`.
3. Settings → choose the imported theme as the dark theme.

Stored as `Workspace.customThemes` (an encoded blob) and
`Workspace.darkThemeID` (`custom-<uuid>`).

The CLI equivalent needs **Remote Control** on in Settings → Rex Server:

```sh
rex -C <client> do client.theme.import path=$HOME/.config/ghostty/themes/aura-dark-wezterm
```

## Font: Cascadia Code NF, 13.5pt

Settings → Terminal → font **Cascadia Code NF**, size **13.5**. The font comes
from `brew install --cask font-cascadia-code-nf`.

Stored as `Workspace.terminalFontName` = `Cascadia Code NF` and
`Workspace.terminalFontPointSize` = `13.5`. These keys come from the app's
binary and are undocumented; `defaults write` with Rex quit is the unsupported
scripted route.

## Ghostty settings with no Rex equivalent

Port these from `ghostty/config` when Rex adds them:

- `background-opacity = 0.85` and `background-blur = 30` (feature request
  deferred)
- `super+up` / `super+down` scroll to the top and bottom of scrollback
- `alt+hjkl` resize step of 15 (Rex's `pane.resize` `amount` unit is
  undocumented, so the binding uses Rex's default step)
- `split-divider-color = #a277ff`
- `window-padding-x = 12`, `window-padding-y = 8`, `window-padding-balance`
