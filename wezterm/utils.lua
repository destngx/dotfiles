local wezterm = require('wezterm')
local M = {}

function M.is_linux()
  return wezterm.target_triple:find("linux") ~= nil
end

function M.is_darwin()
  return wezterm.target_triple:find("darwin") ~= nil
end

-- Check if pane is running inside tmux (local or via ssh)
local function is_tmux(pane)
  local process_name = string.gsub(pane:get_foreground_process_name(), '(.*[/\\])(.*)', '%2')
  -- Check for tmux directly or ssh (which likely connects to tmux)
  if process_name == 'tmux' then
    return true
  end
  -- Also check user vars set by smart-splits.nvim if available
  local user_vars = pane:get_user_vars() or {}
  if user_vars.IS_TMUX == 'true' then
    return true
  end
  return false
end

local function is_vim(pane)
  -- First check user vars (set by smart-splits.nvim when not lazy-loaded)
  local user_vars = pane:get_user_vars() or {}
  if user_vars.IS_NVIM == 'true' then
    return true
  end
  -- Fallback to process name detection (only works locally)
  local process_name = string.gsub(pane:get_foreground_process_name(), '(.*[/\\])(.*)', '%2')
  return process_name == 'nvim' or process_name == 'vim'
end

local direction_keys = {
  Left = "h",
  Down = "j",
  Up = "k",
  Right = "l",
  -- reverse lookup
  h = "Left",
  j = "Down",
  k = "Up",
  l = "Right",
}

function M.split_nav(wezterm_ref, resize_or_move, key)
  return {
    key = key,
    mods = resize_or_move == "resize" and "META" or "CTRL",
    action = wezterm_ref.action_callback(function(win, pane)
      -- If inside tmux, pass ALL keys through - let tmux handle navigation
      -- This is critical for SSH sessions where tmux manages panes
      if is_tmux(pane) then
        win:perform_action({
          SendKey = { key = key, mods = resize_or_move == "resize" and "META" or "CTRL" },
        }, pane)
        return
      end

      -- Not in tmux: use WezTerm's native pane management with vim awareness
      if is_vim(pane) then
        -- pass the keys through to vim/nvim
        win:perform_action({
          SendKey = { key = key, mods = resize_or_move == "resize" and "META" or "CTRL" },
        }, pane)
      else
        if resize_or_move == "resize" then
          win:perform_action({ AdjustPaneSize = { direction_keys[key], 3 } }, pane)
        else
          win:perform_action({ ActivatePaneDirection = direction_keys[key] }, pane)
        end
      end
    end),
  }
end

-- Export is_tmux for use in wezterm.lua
M.is_tmux = is_tmux

return M
