{ config, lib, machine, ... }:
let
  brew = "${config.homebrew.prefix}/bin/brew";
  asUser = "sudo --user=${lib.escapeShellArg machine.username} --set-home";
in
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
      # upgrade disable by default, enable when need update apps
      upgrade = false;
      # Never self-update brew (it is pinned by nix-homebrew's brew-src input anyway).
      autoUpdate = false;
      # Install from fresh formula/cask API data.
      extraEnv.HOMEBREW_FORCE_API_AUTO_UPDATE = "1";
      # Show brew install/cleanup output during darwin-rebuild activation.
      extraFlags = [ "--verbose" ];
    };
  };

  # Report (without upgrading) which installed formulae/casks have a newer version, including
  # `version :latest` casks. `auto_updates` casks (e.g. claude) are skipped: they update themselves,
  # so brew's recorded version goes stale and `--greedy` would report false positives.
  system.activationScripts.postActivation.text = ''
    if [ -x ${brew} ]; then
      echo >&2 "Homebrew: checking installed apps for new versions..."
      outdated=$(${asUser} env HOMEBREW_FORCE_API_AUTO_UPDATE=1 ${brew} outdated --greedy-latest --verbose || true)
      echo >&2 "''${outdated:-All Homebrew packages are up to date.}"
    fi
  '';
}
