{ machine, ... }:
{
  nix-homebrew = {
    enable = true;
    autoMigrate = true;
    user = machine.username;
    mutableTaps = false;
  };

  homebrew = {
    enable = true;
    prefix = "/opt/homebrew";
    taps = [ ];
    brews = [
      "terminal-notifier"
    ];
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
