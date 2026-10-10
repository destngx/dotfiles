{ machine, pkgs, ... }:
{
  nix.enable = false;

  system.stateVersion = 6;
  system.primaryUser = machine.username;

  nixpkgs.hostPlatform = machine.system;
  nixpkgs.config.allowUnfree = true;
  # The user's zsh (home-manager) owns completion, prompt and Homebrew env; skip the system-wide
  # versions so /etc/zshrc does no redundant work on every interactive shell.
  programs.zsh.enableGlobalCompInit = false;
  programs.zsh.enableBashCompletion = false;
  programs.zsh.promptInit = "";
  environment.shells = [ pkgs.zsh ];

  users.users.${machine.username} = {
    name = machine.username;
    home = machine.homeDirectory;
    shell = pkgs.zsh;
  };

  # nix-darwin applies users.users.<name>.shell only to users in users.knownUsers (which would hand
  # the whole account to nix-darwin), so set the login shell directly. Otherwise terminals run
  # macOS /bin/zsh while `zsh` on PATH is nix zsh, and the two versions keep invalidating each
  # other's compdump. /run/current-system/sw/bin/zsh is stable across zsh updates and in /etc/shells.
  system.activationScripts.postActivation.text = ''
    loginShell=/run/current-system/sw/bin/zsh
    if [ "$(dscl . -read /Users/${machine.username} UserShell | awk '{print $2}')" != "$loginShell" ]; then
      echo >&2 "Setting login shell of ${machine.username} to $loginShell..."
      dscl . -create /Users/${machine.username} UserShell "$loginShell"
    fi
  '';
}
