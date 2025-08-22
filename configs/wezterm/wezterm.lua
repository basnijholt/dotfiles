-- WezTerm Configuration
-- ===================
-- This configuration aims to replicate iTerm2 behavior and keybindings for a seamless
-- transition between terminals. It's designed to work cross-platform (macOS and Linux)
-- while maintaining the muscle memory and workflows from iTerm2.
--
-- Key Features:
-- - iTerm2-style keyboard shortcuts for tabs and panes
-- - Command+Click to open files in VS Code (with line number support)
-- - Gruvbox dark theme
-- - FiraMono Nerd Font
-- - Cross-platform compatibility

local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- Configuration Variables
-- =======================
-- Customize these variables to match your preferences and system setup

-- Editor and Applications
local default_editor = 'code'              -- Command to open files (e.g., 'code', 'vim', 'nano')
local editor_flags = '-r'                  -- Default flags for the editor

-- Platform-specific settings
local macos_extra_paths = '/opt/homebrew/bin:/usr/local/bin'
local linux_extra_paths = '/run/current-system/sw/bin:' .. os.getenv('HOME') .. '/.nix-profile/bin:/usr/local/bin:/usr/bin'
local modifier_key = wezterm.target_triple:find('darwin') and 'CMD' or 'CTRL'

-- Font and Appearance
local font_name = 'FiraMono Nerd Font Mono'
local font_size = 16.0
local color_scheme = 'Gruvbox dark, hard (base16)'

-- Pane Selection Visual Settings
local inactive_pane_hsb = { brightness = 0.7, saturation = 0.7 }  -- Dim inactive panes (0.0 = black, 1.0 = normal)
local pane_border_active_color = '#fab387'      -- Gruvbox orange for active pane border
local pane_border_inactive_color = '#45403d'    -- Gruvbox dark gray for inactive borders


-- Appearance
-- ==========
-- Font configuration to match iTerm2 setup
config.font = wezterm.font(font_name, { weight = 'Regular' })
config.font_size = font_size

-- Enable unlimited scrollback like iTerm2
config.scrollback_lines = 999999

-- Colors and theme
config.color_scheme = color_scheme

-- Tab bar settings
config.use_fancy_tab_bar = true
config.enable_tab_bar = true
config.tab_bar_at_bottom = false
config.window_decorations = "RESIZE"

-- Enable native macOS fullscreen
config.native_macos_fullscreen_mode = true

-- Pane Selection Styling
-- ======================
-- Make it much clearer which pane is active (like iTerm2)
config.inactive_pane_hsb = inactive_pane_hsb

-- Pane border colors for better visual separation
config.colors = {
  split = pane_border_active_color,
}

-- Key Bindings
-- ============
-- Replicate iTerm2's keyboard shortcuts for seamless transition
config.keys = {
  -- Tab Management
  -- --------------
  
  -- New tab: Modifier + T (same as iTerm2)
  {
    key = 't',
    mods = modifier_key,
    action = wezterm.action.SpawnTab 'CurrentPaneDomain',
  },
  
  -- Cycle to next tab: Modifier + Right Arrow (same as iTerm2)
  {
    key = 'RightArrow',
    mods = modifier_key,
    action = wezterm.action.ActivateTabRelative(1),
  },
  
  -- Cycle to previous tab: Modifier + Left Arrow (same as iTerm2)
  {
    key = 'LeftArrow',
    mods = modifier_key,
    action = wezterm.action.ActivateTabRelative(-1),
  },
  
  -- Pane Management
  -- ---------------
  
  -- Split pane vertically (new pane on right): Modifier + D (same as iTerm2)
  {
    key = 'd',
    mods = modifier_key,
    action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' },
  },
  
  -- Navigate to pane on the right: Modifier + ] (same as iTerm2)
  {
    key = ']',
    mods = modifier_key,
    action = wezterm.action.ActivatePaneDirection 'Right',
  },
  
  -- Navigate to pane on the left: Modifier + [ (same as iTerm2)
  {
    key = '[',
    mods = modifier_key,
    action = wezterm.action.ActivatePaneDirection 'Left',
  },
  
  -- Close current pane/tab: Modifier + W (same as iTerm2)
  -- Closes the current pane. If it's the last pane in a tab, closes the tab.
  {
    key = 'w',
    mods = modifier_key,
    action = wezterm.action.CloseCurrentPane { confirm = false },
  },
  
  -- Text Navigation
  -- ---------------
  
  -- Move by word: Alt + Left/Right Arrow (same as iTerm2)
  {
    key = 'LeftArrow',
    mods = 'ALT',
    action = wezterm.action.SendString '\x1bb',  -- Move backward one word
  },
  {
    key = 'RightArrow',
    mods = 'ALT',
    action = wezterm.action.SendString '\x1bf',  -- Move forward one word
  },
  
  -- Selection and Clipboard
  -- -----------------------
  
  -- Select all: Modifier + A (same as iTerm2)
  -- Gets all text from scrollback and copies to clipboard
  {
    key = 'a',
    mods = modifier_key,
    action = wezterm.action_callback(function(window, pane)
      local dims = pane:get_dimensions()
      local txt = pane:get_text_from_region(0, dims.scrollback_top, 0, dims.scrollback_top + dims.scrollback_rows)
      window:copy_to_clipboard(txt:match('^%s*(.-)%s*$'))  -- Trim leading and trailing whitespace
    end),
  },
  
  -- Copy selection: Modifier + C (standard behavior)
  {
    key = 'c',
    mods = modifier_key,
    action = wezterm.action.CopyTo 'Clipboard',
  },
  
  -- Paste: Modifier + V (standard behavior)
  {
    key = 'v',
    mods = modifier_key,
    action = wezterm.action.PasteFrom 'Clipboard',
  },
}

-- Mouse Behavior
-- ==============
-- Configure mouse behavior to match iTerm2
-- Note: We're only overriding Modifier+Click behavior; regular clicks use defaults
local mouse_modifier = wezterm.target_triple:find('darwin') and 'SUPER' or 'CTRL'
config.mouse_bindings = {
  -- Modifier+Click opens links (same as iTerm2)
  -- This is essential for opening files in the editor
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = mouse_modifier,
    action = wezterm.action.OpenLinkAtMouseCursor,
  },
}

-- Hyperlink Detection
-- ===================
-- Configure what text patterns should be clickable links
-- Start with WezTerm's default rules (HTTP/HTTPS URLs, etc.)
config.hyperlink_rules = wezterm.default_hyperlink_rules()

-- Additional custom rules for development workflows:

-- Make URLs with IP addresses clickable
-- Examples: http://127.0.0.1:8000, http://192.168.1.1
table.insert(config.hyperlink_rules, {
  regex = [[\b\w+://(?:[\d]{1,3}\.){3}[\d]{1,3}\S*\b]],
  format = '$0',
})

-- File paths with line and column numbers (for error messages and logs)
-- Examples: file.py:123:45, main.rs:42, src/app.js:100:5
table.insert(config.hyperlink_rules, {
  regex = [[\b([A-Za-z0-9._\-/~]+[A-Za-z0-9._\-]+):(\d+)(?::(\d+))?\b]],
  format = 'file://$0',
  highlight = 0,
})

-- Plain file names with extensions (for ls output)
-- Examples: config.lua, main.py, README.md
table.insert(config.hyperlink_rules, {
  regex = [[\b[A-Za-z0-9._\-]+\.[A-Za-z0-9]+\b]],
  format = 'file://$0',
  highlight = 0,
})

-- File paths (absolute and relative, including home directory)
-- Examples: /usr/bin/bash, ./scripts/test.sh, ~/dotfiles/config
table.insert(config.hyperlink_rules, {
  regex = [[~?(?:/[A-Za-z0-9._\-]+)+/?]],
  format = 'file://$0',
  highlight = 0,
})

-- Custom Link Handling
-- ====================
-- Override how file:// links are opened to use VS Code instead of the default handler
-- This enables the iTerm2-like behavior of Command+Click to open files in your editor
wezterm.on('open-uri', function(window, pane, uri)
  -- Only handle file:// URLs, let others (http://, https://, etc.) open normally
  if not uri:match('^file://') then
    return  -- Let WezTerm handle non-file URLs
  end
  
  -- Extract the file path from the file:// URI
  local file_path = uri:gsub('^file://', '')
  
  -- Parse file path with optional line:column notation
  local path, line, col = file_path:match('^([^:]+):?(%d*):?(%d*)$')
  path = path or file_path
  
  -- Resolve the full path
  if path:match('^~') then
    -- Expand ~ to home directory
    path = os.getenv('HOME') .. path:sub(2)
  elseif not path:match('^/') then
    -- Resolve relative paths using current working directory
    local cwd = pane:get_current_working_dir()
    if cwd and cwd.path then
      path = cwd.path .. '/' .. path
    end
  end
  
  -- Build editor command
  local cmd = default_editor .. ' ' .. editor_flags
  if line and line ~= '' then
    -- Add line:column if present
    cmd = cmd .. string.format(' -g "%s:%s%s"', path, line, col ~= '' and ':' .. col or '')
  else
    cmd = cmd .. string.format(' "%s"', path)
  end
  
  -- Execute with platform-specific PATH
  local extra_paths = wezterm.target_triple:find('darwin') and macos_extra_paths or linux_extra_paths
  local fast_cmd = string.format('export PATH="%s:$PATH"; %s', extra_paths, cmd)
  os.execute('/bin/sh -c \'' .. fast_cmd .. '\'')
  
  return false  -- Prevent default action
end)

return config