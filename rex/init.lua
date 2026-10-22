-- Rex config — ported from ghostty/config
-- Docs: https://www.superlogical.com/rex/docs/customize/config
-- Apply changes with `rex config reload`; check them with `rex config check`.
--
-- Colors and font are Rex app settings. Import the shared palette once with
-- Import Theme File in the command palette, picking
-- ~/.config/ghostty/themes/aura-dark-wezterm, then choose it and
-- Cascadia Code NF 14pt in Settings. From the CLI, with Remote Control on:
--   rex -C <client> do client.theme.import path=$HOME/.config/ghostty/themes/aura-dark-wezterm

local terminal = "com.superlogical.terminal"

-- Types raw bytes into the focused terminal.
rex.action{
  name  = "type_text",
  title = "Type Text",
  args  = { text = "string" },
  run   = function(ctx, args)
    local result, err = rex.block.call(terminal, "write", { data = args.text })
    if not result then
      error(err)
    end
  end,
}

-- Splits
rex.bind("cmd+d", "pane.split", { direction = "right" })
rex.bind("cmd+shift+d", "pane.split", { direction = "down" })
rex.bind("cmd+[", "pane.focus_previous")
rex.bind("cmd+]", "pane.focus_next")

-- Pane resizing with alt+hjkl
rex.bind("alt+h", "pane.resize", { direction = "left" })
rex.bind("alt+j", "pane.resize", { direction = "down" })
rex.bind("alt+k", "pane.resize", { direction = "up" })
rex.bind("alt+l", "pane.resize", { direction = "right" })

-- Line editing: start of line, end of line, delete to start of line
rex.bind("cmd+left", "pane.send_key", { key = "ctrl+a" })
rex.bind("cmd+right", "pane.send_key", { key = "ctrl+e" })
rex.bind("cmd+backspace", "pane.send_key", { key = "ctrl+u" })

-- Newline without submitting (Claude Code, REPLs)
rex.bind("shift+enter", "type_text", { text = "\27\r" })
