{ machine, pkgs, ... }:
{
  nix.enable = false;

  system.stateVersion = 6;
  system.primaryUser = machine.username;

  nixpkgs.hostPlatform = machine.system;
  nixpkgs.config.allowUnfree = true;
  programs.zsh.enableGlobalCompInit = false;
  environment.shells = [ pkgs.zsh ];

  users.users.${machine.username} = {
    name = machine.username;
    home = machine.homeDirectory;
    shell = pkgs.zsh;
  };
}
