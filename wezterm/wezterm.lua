-- Pull in the wezterm API
local wezterm = require("wezterm")

-- This will hold the configuration.
local config = wezterm.config_builder()

-- OS detection
local is_macos = wezterm.target_triple:find("darwin") ~= nil

-- OS-aware modifier key (CMD on macOS, ALT on Linux/Windows)
local mod = is_macos and "CMD" or "ALT"

-- Wayland support (disabled: nightly bug with window_decorations)
-- See: https://github.com/wezterm/wezterm/issues/6673
config.enable_wayland = false

-- This is where you actually apply your config choices.

-- For example, changing the initial geometry for new windows:
config.initial_cols = 120
config.initial_rows = 28

-- Set default working directory (macOS-specific path)
if is_macos then
	config.default_cwd = "/Users/brian.pham/Classified/interface.git"
end

-- or, changing the font size and color scheme.
config.font_size = 14

config.font = wezterm.font("Cascadia Code")

config.color_schemes = {
	["Aura Dark"] = {
		ansi = {
			"#15141b",
			"#ff6767",
			"#61ffca",
			"#ffca85",
			"#a277ff",
			"#a277ff",
			"#61ffca",
			"#edecee",
		},
		brights = {
			"#6d6d6d",
			"#ff6767",
			"#61ffca",
			"#ffca85",
			"#a277ff",
			"#a277ff",
			"#61ffca",
			"#edecee",
		},
		background = "#15141b",
		foreground = "#edecee",
		cursor_bg = "#a277ff",
		cursor_border = "#a277ff",
		cursor_fg = "#a277ff",
		selection_bg = "#29263c",
		selection_fg = "#edecee",
		scrollbar_thumb = "#6d6d6d",
		split = "#a277ff",
	},
}

config.color_scheme = "Aura Dark"

-- Highlight active pane border
config.inactive_pane_hsb = {
	saturation = 0.2,
	brightness = 1,
}

-- Window opacity
config.window_background_opacity = 1
if is_macos then
	config.macos_window_background_blur = 10
end

-- Window decorations
config.window_decorations = "RESIZE"

-- Fancy tab bar
config.use_fancy_tab_bar = true
config.hide_tab_bar_if_only_one_tab = false
config.tab_bar_at_bottom = false

config.window_frame = {
	font = wezterm.font("Cascadia Code"),
	font_size = 14.0,
	active_titlebar_bg = "#15141b",
	inactive_titlebar_bg = "#15141b",
}

config.colors = config.colors or {}
config.colors.tab_bar = {
	inactive_tab_edge = "#29263c",
	active_tab = {
		bg_color = "#a277ff",
		fg_color = "#15141b",
	},
	inactive_tab = {
		bg_color = "#1f1d29",
		fg_color = "#6d6d6d",
	},
	new_tab = {
		bg_color = "#15141b",
		fg_color = "#6d6d6d",
	},
}

-- Async API fetch
local function fetch_api_async()
	wezterm.background_child_process({
		"sh",
		"-c",
		[[
      hour=$(date +%H)
      curl -s 'https://api.open-meteo.com/v1/forecast?latitude=10.823&longitude=106.6296&daily=uv_index_max&hourly=temperature_2m,rain,weather_code&timezone=Asia%2FBangkok&forecast_days=1' | \
      jq -r --argjson hour "$hour" '
      .hourly.temperature_2m[$hour] as $temp |
      .hourly.weather_code[$hour] as $code |
      .hourly.rain[$hour] as $rain |
      .daily.uv_index_max[0] as $uv |
      (if $code == 0 then "☀️"
       elif $code <= 3 then "⛅"
       elif $code == 45 or $code == 48 then "🌫️"
       elif $code >= 51 and $code <= 67 then "🌧️"
       elif $code >= 71 and $code <= 77 then "❄️"
       elif $code >= 80 and $code <= 82 then "🌦️"
       elif $code >= 95 then "⛈️"
       else "🌤️" end) as $weather_icon |
      (if $uv <= 2 then "🟢"
       elif $uv <= 5 then "🟡"
       elif $uv <= 7 then "🟠"
       elif $uv <= 10 then "🔴"
       else "🟣" end) as $uv_icon |
      (if $rain > 0 then " 💧\($rain)mm" else "" end) as $rain_text |
      "\($weather_icon) \($temp)°C \($uv_icon)\($uv)\($rain_text)"
      ' > /tmp/wezterm_api_text.txt
    ]],
	})
end

local function read_api_text()
	local f = io.open("/tmp/wezterm_api_text.txt", "r")
	if f then
		local content = f:read("*a")
		f:close()
		return content:gsub("%s+$", "")
	end
	return "Loading..."
end

-- Status bar (macOS only)
if is_macos then
	-- Initial fetch
	fetch_api_async()

	-- Periodic refresh every 15 minutes
	local function schedule_fetch()
		wezterm.time.call_after(900, function()
			fetch_api_async()
			schedule_fetch()
		end)
	end
	schedule_fetch()

	wezterm.on("update-right-status", function(window, pane)
		local date = wezterm.strftime("%a %b %-d %H:%M")
		local bat = ""

		for _, b in ipairs(wezterm.battery_info()) do
			bat = string.format("%.0f%%", b.state_of_charge * 100)
		end

		local current_api_text = read_api_text()

		window:set_right_status(wezterm.format({
			{ Text = "  " },
			{ Foreground = { Color = "#ffca85" } },
			{ Text = current_api_text },
			{ Text = " | " },
			{ Foreground = { Color = "#61ffca" } },
			{ Text = bat },
			{ Text = " | " },
			{ Foreground = { Color = "#a277ff" } },
			{ Text = date },
			{ Text = "  " },
		}))
	end)
end

-- Finally, return the configuration to wezterm:
config.keys = {
	{ key = "Enter", mods = "SHIFT", action = wezterm.action({ SendString = "\x1b\r" }) },
	{
		key = "d",
		mods = mod,
		action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }),
	},
	{
		key = "D",
		mods = mod .. "|SHIFT",
		action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }),
	},
	-- Pane navigation
	{
		key = "[",
		mods = mod,
		action = wezterm.action.ActivatePaneDirection("Prev"),
	},
	{
		key = "]",
		mods = mod,
		action = wezterm.action.ActivatePaneDirection("Next"),
	},
	-- Navigation
	{
		key = "LeftArrow",
		mods = mod,
		action = wezterm.action.SendKey({ key = "Home" }),
	},
	{
		key = "RightArrow",
		mods = mod,
		action = wezterm.action.SendKey({ key = "End" }),
	},
	{
		key = "UpArrow",
		mods = mod,
		action = wezterm.action.ScrollToTop,
	},
	{
		key = "DownArrow",
		mods = mod,
		action = wezterm.action.ScrollToBottom,
	},
	{
		key = "Backspace",
		mods = mod,
		action = wezterm.action.SendKey({ key = "u", mods = "CTRL" }),
	},
	-- Pane resizing with META+h/j/k/l
	{
		key = "h",
		mods = "ALT",
		action = wezterm.action.AdjustPaneSize({ "Left", 15 }),
	},
	{
		key = "j",
		mods = "ALT",
		action = wezterm.action.AdjustPaneSize({ "Down", 15 }),
	},
	{
		key = "k",
		mods = "ALT",
		action = wezterm.action.AdjustPaneSize({ "Up", 15 }),
	},
	{
		key = "l",
		mods = "ALT",
		action = wezterm.action.AdjustPaneSize({ "Right", 15 }),
	},
}

-- Linux-only tab management bindings
if not is_macos then
	local linux_keys = {
		{ key = "t", mods = mod, action = wezterm.action.SpawnTab("CurrentPaneDomain") },
		{ key = "w", mods = mod, action = wezterm.action.CloseCurrentTab({ confirm = true }) },
		{ key = ";", mods = mod, action = wezterm.action.ActivateTabRelative(-1) },
		{ key = "'", mods = mod, action = wezterm.action.ActivateTabRelative(1) },
		-- Copy/paste
		{ key = "c", mods = "CTRL|SHIFT", action = wezterm.action.CopyTo("Clipboard") },
		{ key = "v", mods = "CTRL|SHIFT", action = wezterm.action.PasteFrom("Clipboard") },
		{ key = "v", mods = "CTRL", action = wezterm.action.PasteFrom("Clipboard") },
		-- Paste image as file path (for Claude Code)
		{
			key = "v",
			mods = "CTRL|ALT",
			action = wezterm.action_callback(function(window, pane)
				local success, stdout, stderr = wezterm.run_child_process({
					os.getenv("HOME") .. "/.local/bin/clip2path",
				})
				if success and stdout then
					local text = stdout:gsub("[\r\n]+$", "")
					pane:send_text(text)
				end
			end),
		},
	}
	for _, key in ipairs(linux_keys) do
		table.insert(config.keys, key)
	end
end

return config
