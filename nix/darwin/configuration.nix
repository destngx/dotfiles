{ inputs, machine, pkgs, ... }:
{
  imports = [ ./homebrew.nix ];

  nix.enable = false;

  system.stateVersion = 6;
  system.primaryUser = machine.username;

  nixpkgs.hostPlatform = machine.system;
  nixpkgs.config.allowUnfree = true;
  programs.zsh.enableGlobalCompInit = false;
  environment.shells = [ pkgs.zsh ];
  services.tailscale.enable = true;

  users.users.${machine.username} = {
    name = machine.username;
    home = machine.homeDirectory;
    shell = pkgs.zsh;
  };

  nix-homebrew = {
    enable = true;
    autoMigrate = true;
    user = machine.username;
    mutableTaps = false;
  };
}


