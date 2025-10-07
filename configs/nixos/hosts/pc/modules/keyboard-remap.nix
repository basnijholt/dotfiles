#
# keyboard-remap.nix (formerly kinto.nix) - A Declarative Kinto Replacement for NixOS
#
# ## What is this?
# This file is a NixOS module that replicates the core functionality of Kinto
# (https://github.com/rbreaves/kinto) using the `keyd` daemon. It provides
# a macOS-like keyboard experience on NixOS.
#
# ## How was it created?
# This module was created by translating the logic from the original Kinto
# source code (`linux/kinto.py`, `xkeysnail_service.sh`, etc.) into a `keyd`
# configuration and a NixOS module. The source code references have been
# verified against the original files.
#
# ## Why was it created?
# The original Kinto project uses imperative installation scripts. This module
# provides a declarative alternative for NixOS users.
#
# References:
# - https://github.com/NixOS/nixpkgs/issues/137698
# - https://github.com/rbreaves/kinto/issues/566
# - https://github.com/rbreaves/kinto/tree/4a3bfe79e2578dd85cb6ff2ebc5505f758c64ab6
#                                          (exact commit used for conversion)

# ========== USAGE INSTRUCTIONS ==========
#
# This configuration provides Mac-style keyboard shortcuts on Linux similar to Kinto:
#
# Core Features:
# • Cmd+C/V/X for copy/paste/cut
# • Cmd+Tab for app switching
# • Cmd+Left/Right for home/end navigation
# • Cmd+Up/Down for document start/end
# • Terminal-specific overrides (Cmd+C becomes Ctrl+Shift+C in terminals)
# • Browser tab navigation with Cmd+1-9
# • File manager shortcuts
# • VS Code integration with Alt+F19 workaround
# • Apple keyboard hardware support
#
# Configuration Options (modify at the top of this file):
# • enableAppleKeyboard = true/false   - Apple keyboard driver support
# • enableVSCodeFixes = true/false     - VS Code keybinding fixes
# • appleKeyboardSwapKeys = true/false - Hardware-level Alt/Cmd swapping
#
# To use:
# 1. Add this module to your NixOS configuration
# 2. Customize the options at the top if needed
# 3. Run `sudo nixos-rebuild switch`
# 4. Reboot to ensure kernel modules load properly
#
# To customize further:
# • Modify the keyd extraConfig section above
# • Adjust the configuration options at the top
# • Add application-specific window rules to the keyd config

{
  config,
  pkgs,
  lib,
  ...
}:

let
  # Configuration options - modify these to customize behavior
  enableAppleKeyboard = false; # Set to false if not using Apple keyboards
  enableVSCodeFixes = true; # Set to false to manage VS Code settings manually
  appleKeyboardSwapKeys = false; # Set to false to keep Alt/Cmd in original positions
in

# TODO:
# - Command+space to open Spotlight equivalent (app launcher)
# - Rectangle App like functionality for window management in GNOME
# - Allow repeated Command+backspace
# - Alt+Shift+up/down arrow to copy selected lines in VS Code

{
  # Enable keyd service for key remapping
  # Source: `linux/xkeysnail.service` - Kinto uses xkeysnail as a systemd service.
  services.keyd = {
    enable = true;
    keyboards = {
      default = {
        ids = [ "*" ];
        extraConfig = ''
          # This configuration is a translation of the rules found in
          # Kinto's xkeysnail configuration at linux/kinto.py

          [main]
          # ----------------------------------------------------------------------
          # Core functionality: Map Command keys to a 'meta_mac' layer.
          # This layer sends 'control' by default for all keys not explicitly
          # remapped within the layer. This mimics macOS's Cmd key.
          # Source: linux/kinto.py, lines 151-155 (Mac Only modmap)
          # ----------------------------------------------------------------------
          leftmeta = layer(meta_mac)
          # I only remap the left meta because the right meta is included in my hyperkey.

          rightcontrol = rightcontrol
          rightalt = rightalt
          rightshift = rightshift
          rightmeta = rightmeta

          # ----------------------------------------------------------------------
          # Moving words with Alt (Option) key.
          # Source: Mine
          # ----------------------------------------------------------------------
          leftalt = layer(alt_mac)
          # I only remap the left alt because the right alt is included in my hyperkey.

          # -------------------------------------------------------------------------
          # The alt_mac layer. Moving and deleting words with Alt (Option) key.
          # Source: Mine
          # -------------------------------------------------------------------------
          [alt_mac:A]
          # Temporarily disabling this because it interferes with the hyper key.
          # Alt moving words (C-left, C-right)
          # left = C-left
          # right = C-right

          # Alt removing words (source: https://github.com/ohmyzsh/ohmyzsh/issues/7609)
          # Delete word left (Alt-Backspace)
          backspace = C-backspace
          # Delete word right (Alt-Delete)
          delete = C-delete

          # ----------------------------------------------------------------------
          # The meta_mac layer. The ':C' means "send Control plus the key".
          # For example, pressing Cmd+A will send Ctrl+A.
          # Mappings below this line are exceptions to that rule.
          # ----------------------------------------------------------------------
          [meta_mac:C]

          # ----------------------------------------------------------------------
          # Word-wise navigation and selection (macOS style).
          # Source: linux/kinto.py, "Wordwise" section, lines 598-617
          # ----------------------------------------------------------------------
          left = home
          right = end
          up = C-home
          down = C-end
          # Delete line left (source: mine)
          backspace = macro(S-home delete)
          # Delete line right (source: mine)
          delete = macro(S-end delete)

          # ----------------------------------------------------------------------
          # Standard shortcuts.
          # Source: linux/kinto.py, "General GUI" section, lines 546, 547, 548, 552, 553
          # ----------------------------------------------------------------------
          # Hide window (Command+H)
          h = M-h
          # Quit application
          q = A-f4
          # Application launcher (like Spotlight)
          # TODO: Does not yet work correctly
          space = M-space

          # ----------------------------------------------------------------------
          # Copy, Paste, Cut shortcuts.
          # Source: https://www.reddit.com/r/AsahiLinux/comments/1fj9xvt
          # ----------------------------------------------------------------------
          # Copy
          c = C-insert
          # Paste
          v = S-insert
          # Cut
          x = S-delete

          # ----------------------------------------------------------------------
          # macOS-style App and Window Switching
          # This section replicates macOS's app/window switcher behavior. It uses a
          # temporary 'app_switch_state' layer that becomes active after you press
          # Cmd+Tab or Cmd+`, allowing navigation with arrow keys while Cmd is held.
          # Source: https://www.reddit.com/r/AsahiLinux/comments/1fj9xvt
          # ----------------------------------------------------------------------

          # --- Step 1: Trigger the switcher ---
          # The `swapm` function sends an initial keypress to open a switcher,
          # then immediately activates the 'app_switch_state' layer for navigation.

          # Cmd+Tab: Activate app switcher (Alt+Tab) and prepare for navigation.
          tab = swapm(app_switch_state, M-tab)
          # Cmd+`: Activate window switcher for the current app (Alt+`).
          ` = swapm(app_switch_state, M-grave)

          # --- Step 2: Navigate while holding Cmd ---
          # This layer is only active while holding Cmd after triggering the switcher.
          [app_switch_state:M]

          # Navigate forward (next app/window)
          tab = M-tab
          right = M-tab

          # Navigate backward (previous app/window)
          ` = M-S-grave
          left = M-S-tab

          # ----------------------------------------------------------------------
          # Tab navigation in applications like browsers, file managers, etc.
          # Source: linux/kinto.py, "General GUI" section, lines 544-545
          # ----------------------------------------------------------------------
          leftbrace = C-pageup
          rightbrace = C-pagedown
        '';
      };
    };
  };

  # keyd package is automatically installed by the service
  # No additional packages required for basic functionality

  # ========== DESKTOP ENVIRONMENT SPECIFIC SHORTCUTS ==========
  # Source: xkeysnail_service.sh, lines 254-259 (GNOME configuration)
  services.desktopManager.gnome =
    lib.mkIf (config.services.desktopManager.gnome.enable or false)
      {
        extraGSettingsOverrides = ''
          # Disable overlay key so Super+Space can be used for app launcher
          # Source: xkeysnail_service.sh, line 258
          [org.gnome.mutter]
          overlay-key='<Alt>F1'

          # Set up Mac-style shortcuts
          # Source: xkeysnail_service.sh, lines 295, 326, 335
          [org.gnome.desktop.wm.keybindings]
          minimize=['<Super>h', '<Alt>F9']
          show-desktop=['<Super>d']
          close=['<Alt>F4']

          [org.gnome.shell.keybindings]
          toggle-application-view=['<Super>space']

          # Rectangle like window management
          # Source: Mine
          # TODO: Conflicts with keyd...
          # [org.gnome.mutter.keybindings]
          # toggle-tiled-left=['<Shift><Control><Alt>Left']
          # toggle-tiled-right=['<Shift><Control><Alt>Right']

          [org.gnome.desktop.wm.keybindings]
          toggle-maximized=['<Shift><Control><Alt>f']
        '';
      };

  # ========== APPLE KEYBOARD HARDWARE SUPPORT ==========
  # Source: xkeysnail_service.sh, lines 100-112 (Apple keyboard driver options)
  boot.kernelModules = lib.mkIf enableAppleKeyboard [ "hid_apple" ];
  boot.extraModprobeConfig = lib.mkIf enableAppleKeyboard ''
    # Swap Alt and Cmd keys on Apple keyboards at hardware level
    # Source: removeAppleKB function in xkeysnail_service.sh, line 104
    options hid_apple swap_opt_cmd=${if appleKeyboardSwapKeys then "1" else "0"}

    # Additional Apple keyboard options
    options hid_apple fnmode=2      # Function keys work as F1-F12 by default
    options hid_apple iso_layout=0  # Use ANSI layout
  '';

  # ========== VS CODE INTEGRATION ==========
  # Source: linux/vscode_keybindings.json - VS Code specific fixes
  # The Alt+F19 workaround and word navigation fixes are essential for VS Code
  environment.etc."vscode-keybindings.json" = lib.mkIf enableVSCodeFixes {
    text = builtins.toJSON [
      {
        key = "alt+left";
        command = "-workbench.action.terminal.focusPreviousPane";
        when = "terminalFocus";
      }
      {
        key = "alt+right";
        command = "-workbench.action.terminal.focusNextPane";
        when = "terminalFocus";
      }
      {
        key = "alt+right";
        command = "cursorWordRight";
      }
      {
        key = "alt+left";
        command = "cursorWordLeft";
      }
      {
        key = "shift+alt+left";
        command = "cursorWordStartLeftSelect";
        when = "textInputFocus";
      }
      {
        key = "shift+alt+right";
        command = "cursorWordEndRightSelect";
        when = "textInputFocus";
      }
    ];
  };

}
