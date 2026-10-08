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
    brews = machine.homebrew.brews;
    taps = machine.homebrew.taps;
    casks = machine.homebrew.casks;
    onActivation = {
      cleanup = "uninstall";
      upgrade = true;
      autoUpdate = true;
    };
  };
}
