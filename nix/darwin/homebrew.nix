{ ... }:
{
  homebrew = {
    enable = true;
    prefix = "/opt/homebrew";
    taps = [
      "homebrew/services"
      "nikitabobko/tap"
      "vjeantet/tap"
    ];
    brews = [
      "socket_vmnet"
    ];
    casks = [
      "aerospace"
      "browserosaurus"
      "codex"
      "gcc-arm-embedded"
      "session-manager-plugin"
      "wezterm@nightly"
      "windows-app"
    ];
    onActivation = {
      cleanup = "none";
      upgrade = false;
      autoUpdate = false;
    };
  };
}
