-- Rex config
-- Docs: https://www.superlogical.com/rex/docs/customize/config
-- Apply changes with `rex config reload`; check them with `rex config check`.
--
-- Rex's default shortcuts cover the rest of this setup; the one binding here
-- is the history picker below.
--
-- Colors and font are Rex app settings. Import the shared palette once with
-- Import Theme File in the command palette, picking
-- ~/.config/ghostty/themes/aura-dark-wezterm, then choose it and
-- Cascadia Code NF 14pt in Settings. From the CLI, with Remote Control on:
--   rex -C <client> do client.theme.import path=$HOME/.config/ghostty/themes/aura-dark-wezterm

-- cmd+r: fuzzy-search zsh history in a floating pane. Enter types the pick
-- into the pane you came from; cmd+enter types it and runs it. Needs fzf and
-- ~/.local/bin/rex-history-pick (both set up by install.sh / brew).
rex.action{
  name  = "history_search",
  title = "Search Shell History",
  keywords = "fzf zsh history",
  run   = function(ctx)
    if ctx.block_id == nil then error("no focused pane to send the command to", 0) end
    local _, err = rex.session.new_layer{
      bounds = { 0.25, 0.15, 0.5, 0.6 },
      focus  = true,
      layout = rex.layout.block{
        flavor  = "com.superlogical.terminal.shell",
        label   = "history",
        options = { command = { os.getenv("HOME") .. "/.local/bin/rex-history-pick", ctx.block_id } },
      },
    }
    if err ~= nil then error(err, 0) end
  end,
}

rex.bind("cmd+r", "history_search")

-- cmd+enter runs the pick when the history picker has focus, by sending fzf
-- ctrl-x. Everywhere else it keeps its default, Split Pane Best Fit.
rex.action{
  name  = "history_run_or_split",
  title = "Run History Pick or Split Pane",
  run   = function(ctx)
    if ctx.block_id ~= nil then
      local info = rex.session.describe_block{ block_id = ctx.block_id }
      if info ~= nil and info.block.label == "history" then
        rex.block.call("com.superlogical.terminal", "write", { block_id = ctx.block_id, data = "\24" })
        return
      end
    end
    rex.client.queue("pane.split.auto")
  end,
}

rex.bind("cmd+enter", "history_run_or_split")
