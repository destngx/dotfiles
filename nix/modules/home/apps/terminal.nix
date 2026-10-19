{ inputs, lib, ... }:
let
  # Profile names are theme file names (without .terminal) from lysyi3m/macos-terminal-themes.
  profiles = [ "gruvbox" "Afterglow" ];
  defaultProfile = "Afterglow";

  plistBuddy = "/usr/libexec/PlistBuddy";
  themes = "${inputs.macos-terminal-themes}/themes";
  # Font and behaviour settings layered over every managed profile; the themes only carry colours.
  overrides = ../../../../terminal/profile-overrides.plist;
in
{
  assertions = [{
    assertion = builtins.elem defaultProfile profiles;
    message = "Terminal default profile '${defaultProfile}' must be one of the managed profiles.";
  }];

  # Edit an exported copy and import it back so cfprefsd sees the change; writing
  # ~/Library/Preferences/com.apple.Terminal.plist directly races its cache.
  home.activation.installTerminalProfiles = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    terminalPrefs="$(mktemp -d)/com.apple.Terminal.plist"
    /usr/bin/defaults export com.apple.Terminal "$terminalPrefs"
    ${plistBuddy} -c "Print ':Window Settings'" "$terminalPrefs" >/dev/null 2>&1 \
      || ${plistBuddy} -c "Add ':Window Settings' dict" "$terminalPrefs"
    for profile in ${lib.escapeShellArgs profiles}; do
      key=":Window Settings:$profile"
      ${plistBuddy} -c "Delete '$key'" "$terminalPrefs" >/dev/null 2>&1 || true
      # Merge never overwrites existing keys, so overrides go in first to win over the theme.
      ${plistBuddy} \
        -c "Add '$key' dict" \
        -c "Merge '${overrides}' '$key'" \
        -c "Merge '${themes}/$profile.terminal' '$key'" \
        -c "Set '$key:name' '$profile'" \
        "$terminalPrefs" >/dev/null
    done
    run /usr/bin/defaults import com.apple.Terminal "$terminalPrefs"
    run /usr/bin/defaults write com.apple.Terminal "Default Window Settings" -string ${lib.escapeShellArg defaultProfile}
    run /usr/bin/defaults write com.apple.Terminal "Startup Window Settings" -string ${lib.escapeShellArg defaultProfile}
    rm -rf "$(dirname "$terminalPrefs")"
    if /usr/bin/pgrep -xq Terminal; then
      warnEcho "Terminal.app is running; quit and reopen it to load the updated profiles."
    fi
  '';
}
