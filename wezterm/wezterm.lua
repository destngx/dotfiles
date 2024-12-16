local wezterm = require 'wezterm'
local utils = require("utils")
local act = wezterm.action

local config = {}
-- In newer versions of wezterm, use the config_builder which will
-- help provide clearer error messages
if wezterm.config_builder then
  config = wezterm.config_builder()
end

config.enable_kitty_graphics = true
config.warn_about_missing_glyphs = false
config.front_end = "WebGpu"
config.max_fps = 120
config.window_decorations = utils.is_darwin() and "RESIZE" or "NONE"
config.use_fancy_tab_bar = false
config.window_padding = { left = 8, right = 8, top = 8, bottom = "0.0cell" }
config.adjust_window_size_when_changing_font_size = false
config.force_reverse_video_cursor = true
config.hide_tab_bar_if_only_one_tab = true
config.font = wezterm.font 'JetBrains Mono'
config.font_size = utils.is_darwin() and 20.0 or 16.0
config.font_rules = {
  {
    intensity = 'Bold',
    italic = true,
    font = wezterm.font {
      family = 'OperatorMonoNerdFontComplete Nerd Font',
      weight = 'Bold',
      style = 'Italic',
      -- font_size = 18.0,
    },
  },
  {
    italic = true,
    intensity = 'Half',
    font = wezterm.font {
      family = 'OperatorMonoNerdFontComplete Nerd Font',
      weight = 'DemiBold',
      style = 'Italic',
    },
  },
  {
    italic = true,
    intensity = 'Normal',
    font = wezterm.font {
      family = 'OperatorMonoNerdFontComplete Nerd Font',
      style = 'Italic',
    },
  },
}
config.harfbuzz_features = { "zero", "cv05", "cv02", "ss05", "ss04" }
config.color_scheme = 'Kanagawa (Gogh)'
config.leader = { key = 'a', mods = 'CTRL', timeout_milliseconds = 1000 }
config.window_background_opacity = 0.96
config.enable_kitty_keyboard = true

config.keys = {
  -- map delete to default
  -- move between split panes
  utils.split_nav(wezterm, "move", "h"),
  utils.split_nav(wezterm, "move", "j"),
  utils.split_nav(wezterm, "move", "k"),
  utils.split_nav(wezterm, "move", "l"),
  -- resize panes
  utils.split_nav(wezterm, "resize", "h"),
  utils.split_nav(wezterm, "resize", "j"),
  utils.split_nav(wezterm, "resize", "k"),
  utils.split_nav(wezterm, "resize", "l"),
  -- Launcher
  {
    mods = "CMD",
    key = "Backspace",
    action = act.ShowLauncherArgs({
      flags = "FUZZY|WORKSPACES|LAUNCH_MENU_ITEMS",
    }),
  },
  {
    key = 'Tab',
    mods = 'LEADER',
    action = act.ActivatePaneDirection 'Prev',
  },
  -- Switch between tabs
  {
    key = 'h',
    mods = 'LEADER',
    action = act.ActivateTabRelative(-1),
  },
  {
    key = 'l',
    mods = 'LEADER',
    action = act.ActivateTabRelative(1),
  },
  -- Go to beginning of line
  {
    key = 'a',
    mods = 'LEADER|CTRL',
    action = wezterm.action.SendKey({
      key = 'a',
      mods = 'CTRL',
    }),
  },
  {
    -- Create a new tab in the same domain as the current pane
    key = 'c',
    mods = 'LEADER',
    action = act.SpawnTab 'CurrentPaneDomain',
  },
  -- Go to end of line
  {
    key = 'e',
    mods = 'CTRL',
    action = wezterm.action.SendKey({ key = 'e', mods = 'CTRL' }),
  },
  {
    mods = "LEADER",
    key = "x",
    action = act.CloseCurrentPane({ confirm = true })
  },
  -- Rename tab
  {
    mods = "LEADER",
    key = ",",
    action = act.PromptInputLine({
      description = "Enter new name for tab",
---@diagnostic disable-next-line: unused-local
      action = wezterm.action_callback(function(window, _pane, line)
        -- line will be `nil` if they hit escape without entering anything
        -- An empty string if they just hit enter
        -- Or the actual line of text they wrote
        if line then
          window:active_tab():set_title(line)
        end
      end),
    }),
  },
  -- Make Option-Left equivalent to Alt-b which many line editors interpret as backward-word
  {
    key = "LeftArrow",
    mods = "OPT",
    action = wezterm.action { SendString = "\x1bb" }
  },
  -- Make Option-Right equivalent to Alt-f; forward-word
  {
    key = "RightArrow",
    mods = "OPT",
    action = wezterm.action { SendString = "\x1bf" }
  },
  -- splitting
  {
    mods   = "LEADER",
    key    = "-",
    action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' }
  },
  {
    mods   = "LEADER|SHIFT",
    key    = "_",
    action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' }
  },
  -- maximize one pane
  {
    mods = 'LEADER',
    key = 'z',
    action = wezterm.action.TogglePaneZoomState
  },
  -- rotate panes
  {
    mods = "LEADER",
    key = "Space",
    action = wezterm.action.RotatePanes "Clockwise"
  },
  -- show the pane selection mode, but have it swap the active and selected panes
  {
    mods = 'LEADER',
    key = 's',
    action = wezterm.action.PaneSelect {
      alphabet = "asdfghjkl;",
      mode = 'SwapWithActive',
    },
  },
  -- activate copy mode or vim mode
  {
    key = 'Enter',
    mods = 'LEADER',
    action = wezterm.action.ActivateCopyMode
  },
  -- {
  --   mods = 'CTRL',
  --   key = 'k',
  --   action = { ActivatePaneDirection = 'Up' }
  -- },
  -- {
  --   mods = 'CTRL',
  --   key = 'h',
  --   action = { ActivatePaneDirection = 'Down' }
  -- },
  -- {
  --   mods = 'CTRL',
  --   key = 'h',
  --   action = { ActivatePaneDirection = 'Left' }
  -- },
  -- {
  --   mods = 'CTRL',
  --   key = 'l',
  --   action = { ActivatePaneDirection = 'Right' }
  -- },
}
config.mouse_bindings = {
  {
    event = { Up = { streak = 1, button = "Left" } },
    mods = "NONE",
    action = act({ CompleteSelection = "PrimarySelection" }),
  },
  {
    event = { Up = { streak = 1, button = "Right" } },
    mods = "NONE",
    action = act({ CompleteSelection = "Clipboard" }),
  },
  {
    event = { Up = { streak = 1, button = "Left" } },
    mods = "CTRL",
    action = "OpenLinkAtMouseCursor",
  },
}

config.colors = {
  tab_bar = {
    background = "#1a1b26",
    active_tab = {
      bg_color = "#755E87",
      fg_color = "#c0caf5",
      intensity = "Normal",
      underline = "None",
      italic = false,
      strikethrough = false,
    },
    inactive_tab = {
      bg_color = "#1a1b26",
      fg_color = "#6b7089",
      intensity = "Normal",
      underline = "None",
      italic = false,
      strikethrough = false,
    },
    inactive_tab_hover = {
      bg_color = "#1f2335",
      fg_color = "#6b7089",
      intensity = "Normal",
      underline = "None",
      italic = false,
      strikethrough = false,
    },
    new_tab = {
      bg_color = "#1a1b26",
      fg_color = "#6b7089",
      intensity = "Normal",
      underline = "None",
      italic = false,
      strikethrough = false,
    },
    new_tab_hover = {
      bg_color = "#1f2335",
      fg_color = "#6b7089",
      intensity = "Normal",
      underline = "None",
      italic = false,
      strikethrough = false,
    },
  },
}

wezterm.on('user-var-changed', function(window, pane, name, value)
  local overrides = window:get_config_overrides() or {}
  if name == "ZEN_MODE" then
    local incremental = value:find("+")
    local number_value = tonumber(value)
    if incremental ~= nil then
      while (number_value > 0) do
        window:perform_action(wezterm.action.IncreaseFontSize, pane)
        number_value = number_value - 1
      end
      overrides.enable_tab_bar = false
    elseif number_value < 0 then
      window:perform_action(wezterm.action.ResetFontSize, pane)
      overrides.font_size = nil
      overrides.enable_tab_bar = true
    else
      overrides.font_size = number_value
      overrides.enable_tab_bar = false
    end
  end
  window:set_config_overrides(overrides)
end)
local function get_current_working_dir(tab)
  local current_dir = tab.active_pane.current_working_dir
  local HOME_DIR = string.format("file://%s", os.getenv("HOME"))
  return current_dir == HOME_DIR and "." or string.gsub(current_dir, "(.*[/\\])(.*)", "%2")
end
---@diagnostic disable-next-line: unused-local, redefined-local
wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
  local title = string.format(" %s %s ~ %s ", "❯", get_current_working_dir(tab))
  return { { Text = title }, }
end)
config.hyperlink_rules = {
  -- Matches: a URL in parens: (URL)
  {
    regex = "\\((\\w+://\\S+)\\)",
    format = "$1",
    highlight = 1,
  },
  -- Matches: a URL in brackets: [URL]
  {
    regex = "\\[(\\w+://\\S+)\\]",
    format = "$1",
    highlight = 1,
  },
  -- Matches: a URL in curly braces: {URL}
  {
    regex = "\\{(\\w+://\\S+)\\}",
    format = "$1",
    highlight = 1,
  },
  -- Matches: a URL in angle brackets: <URL>
  {
    regex = "<(\\w+://\\S+)>",
    format = "$1",
    highlight = 1,
  },
  -- Then handle URLs not wrapped in brackets
  {
    regex = "\\b\\w+://\\S+[)/a-zA-Z0-9-]+",
    format = "$0",
  },
  -- implicit mailto link
  {
    regex = "\\b\\w+@[\\w-]+(\\.[\\w-]+)+\\b",
    format = "mailto:$0",
  },
  { regex = [[\b\w+@[\w-]+(\.[\w-]+)+\b]], format = "mailto:$0" },
  -- file:// URI
  -- Compiled-in default. Used if you don't specify any hyperlink_rules.
  { regex = [[\bfile://\S*\b]],            format = "$0" },
}

-- make username/project paths clickable. this implies paths like the following are for github.
-- ( "nvim-treesitter/nvim-treesitter" | wbthomason/packer.nvim | wez/wezterm | "wez/wezterm.git" )
-- as long as a full url hyperlink regex exists above this it should not match a full url to
-- github or gitlab / bitbucket (i.e. https://gitlab.com/user/project.git is still a whole clickable url)
table.insert(config.hyperlink_rules, {
  regex = [[[^:]["]?([\w\d]{1}[-\w\d]+)(/){1}([-\w\d\.]+)["]?]],
  format = "https://www.github.com/$1/$3",
})

-- localhost, with protocol, with optional port and path
table.insert(config.hyperlink_rules, {
  regex = [[http(s)?://localhost(?>:\d+)?]],
  format = "http$1://localhost:$2",
})

-- localhost with no protocol, with optional port and path
table.insert(config.hyperlink_rules, {
  regex = [[[^/]localhost:(\d+)(\/\w+)*]],
  format = "http://localhost:$1",
})

config.key_tables = {
  copy_mode = {
    { key = '/',          mods = 'NONE',  action = act.CopyMode 'EditPattern' },
    { key = 'Tab',        mods = 'NONE',  action = act.CopyMode 'MoveForwardWord' },
    { key = 'Tab',        mods = 'SHIFT', action = act.CopyMode 'MoveBackwardWord' },
    { key = 'Enter',      mods = 'NONE',  action = act.CopyMode 'MoveToStartOfNextLine' },
    { key = 'Escape',     mods = 'NONE',  action = act.CopyMode 'Close' },
    { key = 'Space',      mods = 'NONE',  action = act.CopyMode { SetSelectionMode = 'Cell' } },
    { key = '$',          mods = 'NONE',  action = act.CopyMode 'MoveToEndOfLineContent' },
    { key = '$',          mods = 'SHIFT', action = act.CopyMode 'MoveToEndOfLineContent' },
    { key = ',',          mods = 'NONE',  action = act.CopyMode 'JumpReverse' },
    { key = '0',          mods = 'NONE',  action = act.CopyMode 'MoveToStartOfLine' },
    { key = ';',          mods = 'NONE',  action = act.CopyMode 'JumpAgain' },
    { key = 'F',          mods = 'NONE',  action = act.CopyMode { JumpBackward = { prev_char = false } } },
    { key = 'F',          mods = 'SHIFT', action = act.CopyMode { JumpBackward = { prev_char = false } } },
    { key = 'G',          mods = 'NONE',  action = act.CopyMode 'MoveToScrollbackBottom' },
    { key = 'G',          mods = 'SHIFT', action = act.CopyMode 'MoveToScrollbackBottom' },
    { key = 'H',          mods = 'NONE',  action = act.CopyMode 'MoveToViewportTop' },
    { key = 'H',          mods = 'SHIFT', action = act.CopyMode 'MoveToViewportTop' },
    { key = 'L',          mods = 'NONE',  action = act.CopyMode 'MoveToViewportBottom' },
    { key = 'L',          mods = 'SHIFT', action = act.CopyMode 'MoveToViewportBottom' },
    { key = 'M',          mods = 'NONE',  action = act.CopyMode 'MoveToViewportMiddle' },
    { key = 'M',          mods = 'SHIFT', action = act.CopyMode 'MoveToViewportMiddle' },
    { key = 'O',          mods = 'NONE',  action = act.CopyMode 'MoveToSelectionOtherEndHoriz' },
    { key = 'O',          mods = 'SHIFT', action = act.CopyMode 'MoveToSelectionOtherEndHoriz' },
    { key = 'T',          mods = 'NONE',  action = act.CopyMode { JumpBackward = { prev_char = true } } },
    { key = 'T',          mods = 'SHIFT', action = act.CopyMode { JumpBackward = { prev_char = true } } },
    { key = 'V',          mods = 'NONE',  action = act.CopyMode { SetSelectionMode = 'Line' } },
    { key = 'V',          mods = 'SHIFT', action = act.CopyMode { SetSelectionMode = 'Line' } },
    { key = '^',          mods = 'NONE',  action = act.CopyMode 'MoveToStartOfLineContent' },
    { key = '^',          mods = 'SHIFT', action = act.CopyMode 'MoveToStartOfLineContent' },
    { key = 'b',          mods = 'NONE',  action = act.CopyMode 'MoveBackwardWord' },
    { key = 'b',          mods = 'ALT',   action = act.CopyMode 'MoveBackwardWord' },
    { key = 'b',          mods = 'CTRL',  action = act.CopyMode 'PageUp' },
    { key = 'c',          mods = 'CTRL',  action = act.CopyMode 'Close' },
    { key = 'd',          mods = 'CTRL',  action = act.CopyMode { MoveByPage = (0.5) } },
    { key = 'e',          mods = 'NONE',  action = act.CopyMode 'MoveForwardWordEnd' },
    { key = 'f',          mods = 'NONE',  action = act.CopyMode { JumpForward = { prev_char = false } } },
    { key = 'f',          mods = 'ALT',   action = act.CopyMode 'MoveForwardWord' },
    { key = 'f',          mods = 'CTRL',  action = act.CopyMode 'PageDown' },
    { key = 'g',          mods = 'NONE',  action = act.CopyMode 'MoveToScrollbackTop' },
    { key = 'g',          mods = 'CTRL',  action = act.CopyMode 'Close' },
    { key = 'h',          mods = 'NONE',  action = act.CopyMode 'MoveLeft' },
    { key = 'j',          mods = 'NONE',  action = act.CopyMode 'MoveDown' },
    { key = 'k',          mods = 'NONE',  action = act.CopyMode 'MoveUp' },
    { key = 'l',          mods = 'NONE',  action = act.CopyMode 'MoveRight' },
    { key = 'm',          mods = 'ALT',   action = act.CopyMode 'MoveToStartOfLineContent' },
    { key = 'o',          mods = 'NONE',  action = act.CopyMode 'MoveToSelectionOtherEnd' },
    { key = 'q',          mods = 'NONE',  action = act.CopyMode 'Close' },
    { key = 't',          mods = 'NONE',  action = act.CopyMode { JumpForward = { prev_char = true } } },
    { key = 'u',          mods = 'CTRL',  action = act.CopyMode { MoveByPage = (-0.5) } },
    { key = 'v',          mods = 'NONE',  action = act.CopyMode { SetSelectionMode = 'Cell' } },
    { key = 'v',          mods = 'CTRL',  action = act.CopyMode { SetSelectionMode = 'Block' } },
    { key = 'w',          mods = 'NONE',  action = act.CopyMode 'MoveForwardWord' },
    { key = 'y',          mods = 'NONE',  action = act.Multiple { { CopyTo = 'ClipboardAndPrimarySelection' }, { CopyMode = 'Close' } } },
    { key = 'PageUp',     mods = 'NONE',  action = act.CopyMode 'PageUp' },
    { key = 'PageDown',   mods = 'NONE',  action = act.CopyMode 'PageDown' },
    { key = 'End',        mods = 'NONE',  action = act.CopyMode 'MoveToEndOfLineContent' },
    { key = 'Home',       mods = 'NONE',  action = act.CopyMode 'MoveToStartOfLine' },
    { key = 'LeftArrow',  mods = 'NONE',  action = act.CopyMode 'MoveLeft' },
    { key = 'LeftArrow',  mods = 'ALT',   action = act.CopyMode 'MoveBackwardWord' },
    { key = 'RightArrow', mods = 'NONE',  action = act.CopyMode 'MoveRight' },
    { key = 'RightArrow', mods = 'ALT',   action = act.CopyMode 'MoveForwardWord' },
    { key = 'UpArrow',    mods = 'NONE',  action = act.CopyMode 'MoveUp' },
    { key = 'DownArrow',  mods = 'NONE',  action = act.CopyMode 'MoveDown' },
  },
}
--
return config
