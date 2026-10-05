{ machine, ... }:
{
  homebrew = {
    enable = true;
    prefix = "/opt/homebrew";
    taps = [ ];
    brews = [ ];
    casks = [
      "browserosaurus"
      "codex"
      "gcc-arm-embedded"
      "session-manager-plugin"
      "windows-app"
    ];
    onActivation = {
      cleanup = "uninstall";
      upgrade = true;
      autoUpdate = false;
    };
  };
}
